/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

typealias FCompoundHashSplitStrategy = (FCompoundHashBuilder) -> Bool

@objc(FCompoundHash)
public
class FCompoundHashWrapper: NSObject {
    let wrapped: FCompoundHash
    @objc public var posts: [FPath] {
        wrapped.posts
    }
    @objc public var hashes: [String] {
        wrapped.hashes
    }

    required init(wrapped: FCompoundHash) {
        self.wrapped = wrapped
    }
    @objc public static func fromNode(_ node: FNode) -> FCompoundHashWrapper {
        self.init(wrapped: FCompoundHash.fromNode(node: node))
    }
    @objc public static func fromNode(_ node: FNode, splitStrategy: @escaping (FCompoundHashBuilderWrapper) -> Bool) -> FCompoundHashWrapper {
        self.init(wrapped: FCompoundHash.fromNode(node: node, splitStrategy: { sko in splitStrategy(FCompoundHashBuilderWrapper(wrapped: sko))}))
    }

}

@objc(FCompoundHashBuilder)
public class FCompoundHashBuilderWrapper: NSObject {
    let wrapped: FCompoundHashBuilder
    @objc public var currentPath: FPath {
        wrapped.currentPath
    }
    init(wrapped: FCompoundHashBuilder) {
        self.wrapped = wrapped
    }
}

class FCompoundHashBuilder {
  var splitStrategy: FCompoundHashSplitStrategy
  var currentPaths: [FPath] = []
  var currentHashes: [String] = []

  // NOTE: We use the existence of this to know if we've started building a
  // range (i.e. encountered a leaf node).
  var optHashValueBuilder: String? = nil

  // The current path as a stack. This is used in combination with
  // currentPathDepth to simultaneously store the last leaf node path. The
  // depth is changed when descending and ascending, at the same time the
  // current key is set for the current depth. Because the keys are left
  // unchanged for ascending the path will also contain the path of the last
  // visited leaf node (using lastLeafDepth elements)
  var _currentPath: [String] = []
  var lastLeafDepth: Int
  var currentPathDepth: Int

  var needsComma: Bool

  var currentPath: FPath {
    currentPath(withDepth: currentPathDepth)
  }

  init(splitStrategy: @escaping FCompoundHashSplitStrategy) {
    self.splitStrategy = splitStrategy
    self.lastLeafDepth = -1
    self.currentPathDepth = 0
    self.needsComma = true
  }

  var isBuildingRange: Bool {
      optHashValueBuilder != nil
  }

  var currentHashLength: Int {
    optHashValueBuilder?.count ?? 0
  }


  func currentPath(withDepth depth: Int) -> FPath {
    let pieces = _currentPath[0..<depth]
    return FPath(pieces: Array(pieces), andPieceNum: 0)
  }

  func appendKey(_ key: String, toString: inout String) {
    FSnapshotUtilitiesSwift.appendHashV2Representation(for: key, to: &toString)
  }

  func ensureRange() {
      if !isBuildingRange {
          optHashValueBuilder = "("

          for i in 0..<currentPathDepth {
              let key = _currentPath[i]
              appendKey(key, toString: &optHashValueBuilder!)
              optHashValueBuilder! += ":("
          }
          needsComma = false
      }
  }

  func processLeaf(leafNode: FLeafNode) {
      ensureRange()

      lastLeafDepth = currentPathDepth
      FSnapshotUtilitiesSwift.appendHashRepresentation(for: leafNode, to: &optHashValueBuilder!, hashVersion: .v2)
      needsComma = true
      if splitStrategy(self) {
          endRange()
      }
  }

    func startChild(key: String) {
      ensureRange()

      if needsComma {
          optHashValueBuilder! += ","
      }
        appendKey(key, toString: &optHashValueBuilder!)
        optHashValueBuilder! += ":("
      if currentPathDepth == _currentPath.count {
          _currentPath.append(key)
      } else {
          _currentPath[currentPathDepth] = key
      }
      currentPathDepth += 1
      needsComma = false
  }

  func endChild() {
      currentPathDepth -= 1
      if isBuildingRange {
          optHashValueBuilder! += ")"
      }
      needsComma = true
  }

  func finishHashing() {
      assert(currentPathDepth == 0,
             "Can't finish hashing in the middle of processing a child")
      if isBuildingRange {
          endRange()
      }

      // Always close with the empty hash for the remaining range to allow simple
      // appending
      currentHashes.append("")
  }

  func endRange() {
      assert(isBuildingRange,
             "Can't end range without starting a range!");
      // Add closing parenthesis for current depth
      for _ in 0 ..< currentPathDepth {
          optHashValueBuilder! += ")"
      }
      optHashValueBuilder! += ")"

      let lastLeafPath = currentPath(withDepth: lastLeafDepth)

      let hash = FStringUtilitiesSwift.base64EncodedSha1(optHashValueBuilder!)
      currentHashes.append(hash)
      currentPaths.append(lastLeafPath)

      optHashValueBuilder = nil
  }


}

struct FCompoundHash {
  var posts: [FPath]
  var hashes: [String]

    init(posts: [FPath], hashes: [String]) {
        if posts.count != hashes.count - 1 {
            fatalError("Number of posts need to be n-1 for n hashes in FCompoundHash")
        }
        self.posts = posts
        self.hashes = hashes
    }

    static func fromNode(node: FNode) -> FCompoundHash {
        FCompoundHash.fromNode(node: node,
                               splitStrategy: FCompoundHash.simpleSizeSplitStrategy(for: node))
    }

    static func fromNode(node: FNode,
                  splitStrategy: @escaping FCompoundHashSplitStrategy) -> FCompoundHash {
        if node.isEmpty {
            return FCompoundHash(posts: [], hashes: [""])
        } else {
            let builder = FCompoundHashBuilder(splitStrategy: splitStrategy)
            FCompoundHash.processNode(node, builder: builder)
            builder.finishHashing()
            return FCompoundHash(posts: builder.currentPaths, hashes: builder.currentHashes)
        }
    }

    static func processNode(_ node: FNode, builder: FCompoundHashBuilder) {
        if let leafNode = node as? FLeafNode {
            builder.processLeaf(leafNode: leafNode)
        } else {
            guard let childrenNode = node as? FChildrenNode else {
                assert(false, "Can't calculate hash on empty node!")
                return
            }
            childrenNode.enumerateChildrenAndPriority { key, node, stop in
                builder.startChild(key: key)
                self.processNode(node, builder: builder)
                builder.endChild()
            }
        }
    }

    static func simpleSizeSplitStrategy(for node: FNode) -> FCompoundHashSplitStrategy {
        let estimatedSize = FSnapshotUtilities.estimateSerializedNodeSize(node)

        // Splits for
        // 1k -> 512 (2 parts)
        // 5k -> 715 (7 parts)
        // 100k -> 3.2k (32 parts)
        // 500k -> 7k (71 parts)
        // 5M -> 23k (228 parts)
        let splitThreshold = max(512, Int(sqrt(Double(estimatedSize * 100))))

        return { builder in
          // Never split on priorities
            return builder.currentHashLength > splitThreshold &&
            builder.currentPath.getBack() !=  ".priority"
        }
    }
}
