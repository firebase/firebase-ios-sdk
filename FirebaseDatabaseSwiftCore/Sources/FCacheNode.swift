//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 19/02/2022.
//

import Foundation


@objc public class FCacheNode: NSObject {
  @objc public var isFullyInitialized: Bool
  @objc public var isFiltered: Bool
  public var indexedNode: FIndexedNode
    @objc(indexedNode) public var indexedNodeObjC: FIndexedNodeObjC {
        .init(wrapped: indexedNode)
    }
  @objc public var node: FNode {
    indexedNode.node
  }
  public init(indexedNode: FIndexedNode, isFullyInitialized: Bool, isFiltered: Bool) {
    self.indexedNode = indexedNode
    self.isFiltered = isFiltered
    self.isFullyInitialized = isFullyInitialized
  }

  @objc public func isComplete(forPath path: FPath) -> Bool {
    if let childKey = path.getFront() {
      return isComplete(forChild: childKey)
    } else { // path is empty
      return isFullyInitialized && !isFiltered
    }
  }

  @objc public func isComplete(forChild childKey: String) -> Bool {
    (isFullyInitialized && !isFiltered) || node.hasChild(childKey)
  }
}
