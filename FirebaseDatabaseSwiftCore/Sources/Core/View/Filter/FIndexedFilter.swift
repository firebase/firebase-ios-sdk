//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 03/03/2022.
//

import Foundation

@objc public class FIndexedFilter: NSObject, FNodeFilter {
    public func updateChildIn(_ indexedNode: FIndexedNode, forChildKey childKey: String, newChild newChildSnap: FNode, affectedPath: FPath, fromSource source: FCompleteChildSource, accumulator optChangeAccumulator: FChildChangeAccumulator?) -> FIndexedNode {
        assert(indexedNode.hasIndex(index), "The index in FIndexedNode must match the index of the filter")
        let node = indexedNode.node
        let oldChildSnap = node.getImmediateChild(childKey)
         // Check if anything actually changed.
        if oldChildSnap.getChild(affectedPath).isEqual(newChildSnap.getChild(affectedPath)) {
            // There's an edge case where a child can enter or leave the view
            // because affectedPath was set to null. In this case, affectedPath will
            // appear null in both the old and new snapshots.  So we need to avoid
            // treating these cases as "nothing changed."
            if oldChildSnap.isEmpty == newChildSnap.isEmpty {
                // Nothing changed.
#if DEBUG
                assert(oldChildSnap.isEqual(newChildSnap),
                         "Old and new snapshots should be equal.")
#endif

                return indexedNode
            }
        }
        if let optChangeAccumulator = optChangeAccumulator {
            if newChildSnap.isEmpty {
                if node.hasChild(childKey) {
                    let change = FChange(type: .childRemoved, indexedNode: FIndexedNode(node: oldChildSnap), childKey: childKey)
                    optChangeAccumulator.trackChildChange(change)
                } else {
                    assert(node.isLeafNode(), "A child remove without an old child only makes sense on a leaf node.")
                }
            } else if oldChildSnap.isEmpty {
                let change = FChange(type: .childAdded, indexedNode: FIndexedNode(node: newChildSnap), childKey: childKey)
                optChangeAccumulator.trackChildChange(change)
            } else {
                let change = FChange(type: .childChanged, indexedNode: FIndexedNode(node: newChildSnap), childKey: childKey, oldIndexedNode: FIndexedNode(node: oldChildSnap))
                optChangeAccumulator.trackChildChange(change)
            }
        }
        if node.isLeafNode() && newChildSnap.isEmpty {
            return indexedNode
        } else {
            return indexedNode.updateChild(childKey, withNewChild: newChildSnap)
        }
    }

    public func updateFullNode(_ oldSnap: FIndexedNode, withNewNode newSnap: FIndexedNode, accumulator optChangeAccumulator: FChildChangeAccumulator?) -> FIndexedNode {
        guard let optChangeAccumulator = optChangeAccumulator else {
            return newSnap
        }
        oldSnap.node.enumerateChildren { childKey, childNode, stop in
            if !newSnap.node.hasChild(childKey) {
                let change = FChange(type: .childRemoved,
                                     indexedNode: FIndexedNode(node: childNode),
                                     childKey: childKey)
                optChangeAccumulator.trackChildChange(change)
            }
        }
        newSnap.node.enumerateChildren { childKey, childNode, stop in
            if oldSnap.node.hasChild(childKey) {
                let oldChildSnap = oldSnap.node.getImmediateChild(childKey)
                // XXX TODO, COULD FNODE BE MADE EQUATABLE
                if !oldChildSnap.isEqual(childNode) {
                    let change = FChange(type: .childChanged, indexedNode: FIndexedNode(node: childNode), childKey: childKey, oldIndexedNode: FIndexedNode(node: oldChildSnap))
                    optChangeAccumulator.trackChildChange(change)
                }
            } else {
                let change = FChange(type: .childAdded, indexedNode: FIndexedNode(node: childNode), childKey: childKey)
                optChangeAccumulator.trackChildChange(change)
            }
        }
        return newSnap
    }

    public func updatePriority(_ priority: FNode, forNode oldSnap: FIndexedNode) -> FIndexedNode {
        if oldSnap.node.isEmpty {
            return oldSnap
        } else {
            return oldSnap.updatePriority(priority)
        }
    }

    public var filtersNodes: Bool { false }

    public var indexedFilter: FNodeFilter { self }

    public let index: FIndex
    @objc public init(index: FIndex) {
        self.index = index
    }
}
