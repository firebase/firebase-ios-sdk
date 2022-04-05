//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 19/02/2022.
//

import Foundation

@objc public class FWriteTree: NSObject {
  /**
   * A tree tracking the results of applying all visible writes. This does not
   * include transactions with applyLocally=false or writes that are completely
   * shadowed by other writes. Contains id<FNode> as values.
   */
  var visibleWrites: FCompoundWrite

  /**
   * A list of pending writes, regardless of visibility and shadowed-ness. Used to
   * calcuate arbitrary sets of the changed data, such as hidden writes (from
   * transactions) or changes with certain writes excluded (also used by
   * transactions). Contains FWriteRecords.
   */
  var allWrites: [FWriteRecord]

  var lastWriteId: Int

  @objc public override init() {
    visibleWrites = .emptyWrite
    allWrites = []
    lastWriteId = -1
  }

  /**
   * Create a new WriteTreeRef for the given path. For use with a new sync point
   * at the given path.
   */
    @objc public func childWritesForPath(_ path: FPath) -> FWriteTreeRef {
    FWriteTreeRef(path: path, writeTree: self)
  }

  /**
   * Record a new overwrite from user code.
   * @param visible Is set to false by some transactions. It should be excluded
   * from event caches.
   */
    @objc public func addOverwriteAtPath(_ path: FPath, newData: FNode, writeId: Int, isVisible: Bool) {
    assert(writeId > self.lastWriteId,
             "Stacking an older write on top of a newer one")
    let record = FWriteRecord(path: path, overwrite: newData, writeId: writeId, visible: isVisible)
    allWrites.append(record)

    if isVisible {
      self.visibleWrites = visibleWrites.addWrite(newData, atPath: path)
    }

    lastWriteId = writeId
  }

  /**
   * Record a new merge from user code.
   * @param changedChildren maps NSString -> id<FNode>
   */
    @objc public func addMergeAtPath(_ path: FPath, changedChildren: FCompoundWrite, writeId: Int) {
    assert(writeId > self.lastWriteId,
             "Stacking an older merge on top of newer one")
    let record = FWriteRecord(path: path, merge: changedChildren, writeId: writeId)
    allWrites.append(record)

    self.visibleWrites = visibleWrites.addCompoundWrite(changedChildren, atPath: path)

    self.lastWriteId = writeId
  }

  /**
   * Remove a write (either an overwrite or merge) that has been successfully
   * acknowledged by the server. Recalculates the tree if necessary. We return the
   * path of the write and whether it may have been visible, meaning views need to
   * reevaluate.
   *
   * @return YES if the write may have been visible (meaning we'll need to
   * reevaluate / raise events as a result).
   */
    @objc public func removeWriteId(_ writeId: Int) -> Bool {
    guard let index = allWrites.firstIndex(where: { $0.writeId == writeId }) else {
      assert(false,
               "[FWriteTree removeWriteId:] called with nonexistent writeId.")
    }
    let writeToRemove = allWrites[index]
    allWrites.remove(at: index)

    var removedWriteWasVisible = writeToRemove.visible
    var removedWriteOverlapsWithOtherWrites = false
    var i = allWrites.count - 1

     while (removedWriteWasVisible && i >= 0) {
       let currentWrite = allWrites[i]
       if currentWrite.visible {
         if i >= index && self.record(currentWrite,
                                      containsPath:writeToRemove.path) {
                 // The removed write was completely shadowed by a subsequent
                 // write.
                 removedWriteWasVisible = false
         } else if writeToRemove.path.contains(currentWrite.path) {
                 // Either we're covering some writes or they're covering part of
                 // us (depending on which came first).
                 removedWriteOverlapsWithOtherWrites = true
             }
         }
         i -= 1
     }

     if !removedWriteWasVisible {
         return false
     } else if removedWriteOverlapsWithOtherWrites {
         // There's some shadowing going on. Just rebuild the visible writes from
         // scratch.
         resetTree()
         return true
     } else {
         // There's no shadowing.  We can safely just remove the write(s) from
         // visibleWrites.
       if let merge = writeToRemove.merge {
         merge.enumerateWrites { path, _, _ in
           self.visibleWrites = self.visibleWrites.removeWriteAtPath(writeToRemove.path.child(path))
         }
       } else {
         // Write is overwrite
         visibleWrites = visibleWrites.removeWriteAtPath(writeToRemove.path)
       }
         return true
     }
  }

    @objc public func removeAllWrites() -> [FWriteRecord] {
    let writes = allWrites
    visibleWrites = .emptyWrite
    allWrites = []
    return writes
  }

    @objc public func writeForId(_ writeId: Int) -> FWriteRecord? {
    allWrites.first { $0.writeId == writeId }
  }

  /**
   * @return A complete snapshot for the given path if there's visible write data
   * at that path, else nil. No server data is considered.
   */
  func completeWriteData(at path: FPath) -> FNode? {
    visibleWrites.completeNodeAtPath(path)
  }


  /**
   * Given optional, underlying server data, and an optional set of constraints
   * (exclude some sets, include hidden writes), attempt to calculate a complete
   * snapshot for the given path
   * @param includeHiddenWrites Defaults to false, whether or not to layer on
   * writes with visible set to false
   */
    @objc public func calculateCompleteEventCacheAtPath(_ treePath: FPath, completeServerCache: FNode?, excludeWriteIds: [Int]?, includeHiddenWrites: Bool) -> FNode? {
    if excludeWriteIds == nil && !includeHiddenWrites {
      if let shadowingNode = visibleWrites.completeNodeAtPath(treePath) {
        return shadowingNode
      } else {
        // No cache here. Can't claim complete knowledge.
        let subMerge =
        self.visibleWrites.childCompoundWriteAtPath(treePath)
        if subMerge.isEmpty {
          return completeServerCache
        } else if completeServerCache == nil &&
                    !subMerge.hasCompleteWriteAtPath(.empty) {
          // We wouldn't have a complete snapshot since there's no
          // underlying data and no complete shadow
          return nil
        } else {
          let layeredCache: FNode = completeServerCache ?? FEmptyNode.emptyNode
          return subMerge.applyToNode(layeredCache)
        }
      }
    } else {
      let merge = visibleWrites.childCompoundWriteAtPath(treePath)
      if !includeHiddenWrites && merge.isEmpty {
        return completeServerCache
      } else {
        // If the server cache is null and we don't have a complete cache,
        // we need to return nil
        if (!includeHiddenWrites && completeServerCache == nil &&
            !merge.hasCompleteWriteAtPath(.empty)) {
          return nil
        } else {
            let filter: (FWriteRecord) -> Bool = { record in
                (record.visible || includeHiddenWrites) &&
                (excludeWriteIds?.contains(record.writeId) ?? true) &&
                (record.path.contains(treePath) || treePath.contains(record.path))
            }
            let mergeAtPath = FWriteTree.layerTreeFromWrites(allWrites, filter: filter, treeRoot: treePath)
            let layeredCache = completeServerCache ?? FEmptyNode.emptyNode
            return mergeAtPath.applyToNode(layeredCache)
        }
      }
    }
  }

    /**
     * With optional, underlying server data, attempt to return a children node of
     * children that we have complete data for. Used when creating new views, to
     * pre-fill their complete event children snapshot.
     */
  func calculateCompleteEventChildrenAtPath(_ treePath: FPath, completeServerChildren: FNode?) -> FNode {
      var completeChildren: FNode = FEmptyNode.emptyNode
      if let topLevelSet = visibleWrites.completeNodeAtPath(treePath) {
          if let topChildrenNode = topLevelSet as? FChildrenNode {
              // We're shadowing everything. Return the children.
              topChildrenNode.enumerateChildren { key, node, stop in
                  completeChildren = completeChildren.updateImmediateChild(key, withNewChild: node)
              }
          }
          return completeChildren
      } else {
          // Layer any children we have on top of this
          // We know we don't have a top-level set, so just enumerate existing
          // children, and apply any updates
          let merge = visibleWrites.childCompoundWriteAtPath(treePath)
          completeServerChildren?.enumerateChildren { key, node, stop in
              let childMerge = merge.childCompoundWriteAtPath(FPath(with: key))
              let newChildNode = childMerge.applyToNode(node)
              completeChildren = completeChildren.updateImmediateChild(key, withNewChild: newChildNode)
          }
          // Add any complete children we have from the set.
          for node in merge.completeChildren {
              completeChildren =
              completeChildren.updateImmediateChild(node.name,
                                                    withNewChild:node.node)
          }
          return completeChildren
      }
  }

    /**
     * Given that the underlying server data has updated, determine what, if
     * anything, needs to be applied to the event cache.
     *
     * Possibilities
     *
     * 1. No write are shadowing. Events should be raised, the snap to be applied
     * comes from the server data.
     *
     * 2. Some write is completely shadowing. No events to be raised.
     *
     * 3. Is partially shadowed. Events ..
     *
     * Either existingEventSnap or existingServerSnap must exist.
     */
    // XXX TODO: existingEventSnap never used in original method...
    @objc public func calculateEventCacheAfterServerOverwriteAtPath(_ treePath: FPath, childPath: FPath, existingEventSnap: FNode?, existingServerSnap: FNode) -> FNode? {

      let path = treePath.child(childPath)
      if visibleWrites.hasCompleteWriteAtPath(path) {
          // At this point we can probably guarantee that we're in case 2, meaning
          // no events May need to check visibility while doing the
          // findRootMostValueAndPath call
          return nil
      } else {
          // This could be more efficient if the serverNode + updates doesn't
          // change the eventSnap However this is tricky to find out, since user
          // updates don't necessary change the server snap, e.g. priority updates
          // on empty nodes, or deep deletes. Another special case is if the
          // server adds nodes, but doesn't change any existing writes. It is
          // therefore not enough to only check if the updates change the
          // serverNode. Maybe check if the merge tree contains these special
          // cases and only do a full overwrite in that case?
          let childMerge =
          visibleWrites.childCompoundWriteAtPath(path)
          if childMerge.isEmpty {
              // We're not shadowing at all. Case 1
              return existingServerSnap.getChild(childPath)
          } else {
              return childMerge.applyToNode(existingServerSnap.getChild(childPath))
          }
      }
  }

    /**
     * Returns a complete child for a given server snap after applying all user
     * writes or nil if there is no complete child for this child key.
     */
    func calculateCompleteChildAtPath(_ treePath: FPath, childKey: String, cache existingServerCache: FCacheNode) -> FNode? {
        let path = treePath.child(fromString: childKey)
        if let shadowingNode = visibleWrites.completeNodeAtPath(path) {
            return shadowingNode;
        } else {
            if existingServerCache.isComplete(forChild: childKey) {
                let childMerge =
                self.visibleWrites.childCompoundWriteAtPath(path)
                return childMerge.applyToNode(existingServerCache.node.getImmediateChild(childKey))
            } else {
                return nil
            }
        }
  }

    /**
     * Returns a node if there is a complete overwrite for this path. More
     * specifically, if there is a write at a higher path, this will return the
     * child of that write relative to the write and this path. Returns null if
     * there is no write at this path.
     */
    func shadowingWriteAtPath(_ path: FPath) -> FNode? {
        visibleWrites.completeNodeAtPath(path)
    }

    /**
     * This method is used when processing child remove events on a query. If we
     * can, we pull in children that were outside the window, but may now be in the
     * window.
     */
  func calculateNextNodeAfterPost(_ post: FNamedNode, atPath path: FPath, completeServerData: FNode?, reverse: Bool, index: FIndex) -> FNamedNode? {
      let merge = visibleWrites.childCompoundWriteAtPath(path)
      let toIterate: FNode
      if let shadowingNode = merge.completeNodeAtPath(.empty) {
          toIterate = shadowingNode
      } else if let completeServerData = completeServerData {
          toIterate = merge.applyToNode(completeServerData)
      } else {
          return nil
      }

      var currentNextKey: String? = nil
      var currentNextNode: FNode? = nil
      toIterate.enumerateChildren { key, node, stop in
          if index.compareKey(key, andNode: node, toOtherKey: post.name, andNode: post.node, reverse: reverse).rawValue > ComparisonResult.orderedSame.rawValue &&
                (currentNextKey == nil || index.compareKey(key, andNode: node, toOtherKey: currentNextKey!, andNode: currentNextNode!, reverse: reverse).rawValue < ComparisonResult.orderedSame.rawValue) {
              currentNextKey = key
              currentNextNode = node
          }
      }

      if let currentNextKey = currentNextKey, let currentNextNode = currentNextNode {
          return FNamedNode.nodeWithName(currentNextKey, node: currentNextNode)
      } else {
          return nil
      }
  }

  // MARK: -
  // MARK: Private Methods

  private func record(_ record: FWriteRecord, containsPath path: FPath) -> Bool {
    if let merge = record.merge {
      var contains = false
      merge.enumerateWrites { childPath, node, stop in
        contains = record.path.child(childPath).contains(path)
        stop.pointee = .init(contains)
      }
      return contains
    } else {
      // Record is an overwrite
      return record.path.contains(path)
    }
  }

  /**
   * Re-layer the writes and merges into a tree so we can efficiently calculate
   * event snapshots
   */
  private func resetTree() {
    self.visibleWrites = FWriteTree.layerTreeFromWrites(self.allWrites,
                                                        filter: FWriteTree.defaultFilter,
                                                        treeRoot: .empty)
    self.lastWriteId = allWrites.last?.writeId ?? -1
  }

  /**
   * The default filter used when constructing the tree. Keep everything that's
   * visible.
   */
  private static var defaultFilter: (FWriteRecord) -> Bool = { _ in
    true
  }

  /**
   * Static method. Given an array of WriteRecords, a filter for which ones to
   * include, and a path, construct a merge at that path
   * @return An FImmutableTree of id<FNode>s.
   */
  private static func layerTreeFromWrites(
  _ writes: [FWriteRecord],
  filter: (FWriteRecord) -> Bool,
  treeRoot: FPath) -> FCompoundWrite {
    var compoundWrite = FCompoundWrite.emptyWrite
    for record in writes {
      // Theory, a later set will either:
      // a) abort a relevant transaction, so no need to worry about excluding it
      // from calculating that transaction b) not be relevant to a transaction
      // (separate branch), so again will not affect the data for that
      // transaction
      if (filter(record)) {
        let writePath = record.path
        if let overwrite = record.overwrite {
          if treeRoot.contains(writePath) {
            let relativePath = FPath.relativePath(from: treeRoot, to:writePath)
            compoundWrite = compoundWrite.addWrite(overwrite,
                                                   atPath:relativePath)
          } else if writePath.contains(treeRoot) {
            let child = overwrite.getChild(FPath.relativePath(from:writePath, to:treeRoot))
            compoundWrite = compoundWrite.addWrite(child,
                                                   atPath: .empty)
          } else {
            // There is no overlap between root path and write path,
            // ignore write
          }
        } else if let merge = record.merge {
          if treeRoot.contains(writePath) {
            let relativePath = FPath.relativePath(from: treeRoot, to: writePath)
            compoundWrite = compoundWrite.addCompoundWrite(merge,
                                                           atPath:relativePath)
          } else if writePath.contains(treeRoot) {
            let relativePath = FPath.relativePath(from: writePath, to: treeRoot)
            if relativePath.isEmpty {
              compoundWrite = compoundWrite.addCompoundWrite(merge,
                                                             atPath: .empty)
            } else {
              if let child = merge.completeNodeAtPath(relativePath) {
                // There exists a child in this node that matches the
                // root path
                let deepNode = child.getChild(relativePath.popFront())
                compoundWrite = compoundWrite.addWrite(deepNode,
                                                       atPath: .empty)
              }
            }
          } else {
            // There is no overlap between root path and write path,
            // ignore write
          }
        }
      }
    }
    return compoundWrite
  }

}
