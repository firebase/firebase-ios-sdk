//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 03/03/2022.
//

import Foundation

@objc public class FRangedFilter: NSObject, FNodeFilter {
    @objc public let startPost: FNamedNode
    @objc public let endPost: FNamedNode
    @objc public init(queryParams params: FQueryParams) {
        self.indexedFilter = FIndexedFilter(index: params.index)
        self.index = params.index
        self.startPost = FRangedFilter.startPost(fromQueryParams: params)
        self.endPost = FRangedFilter.endPost(fromQueryParams: params)
    }
    public func updateChildIn(_ oldSnap: FIndexedNode, forChildKey childKey: String, newChild newChildSnap: FNode, affectedPath: FPath, fromSource source: FCompleteChildSource, accumulator optChangeAccumulator: FChildChangeAccumulator?) -> FIndexedNode {
        var newChildSnap = newChildSnap
        if !matchesKey(childKey, andNode:newChildSnap) {
            newChildSnap = FEmptyNode.emptyNode
        }
        return indexedFilter.updateChildIn(oldSnap,
                                           forChildKey:childKey,
                                           newChild:newChildSnap,
                                           affectedPath:affectedPath,
                                           fromSource:source,
                                           accumulator:optChangeAccumulator)

    }

    public func updateFullNode(_ oldSnap: FIndexedNode, withNewNode newSnap: FIndexedNode, accumulator optChangeAccumulator: FChildChangeAccumulator?) -> FIndexedNode {
        var filtered: FIndexedNode
        if newSnap.node.isLeafNode() {
            // Make sure we have a children node with the correct index, not a leaf
            // node
            filtered = FIndexedNode.indexedNodeWithNode(FEmptyNode.emptyNode, index: index)
        } else {
            // Dont' support priorities on queries
            filtered = newSnap.updatePriority(FEmptyNode.emptyNode)
            newSnap.node.enumerateChildren { key, node, stop in
                if !self.matchesKey(key, andNode: node) {
                    filtered = filtered.updateChild(key, withNewChild: FEmptyNode.emptyNode)
                }
            }
        }
        return indexedFilter.updateFullNode(oldSnap, withNewNode: filtered, accumulator: optChangeAccumulator)
    }

    public func updatePriority(_ priority: FNode, forNode oldSnap: FIndexedNode) -> FIndexedNode {
        // Don't support priorities on queries
        return oldSnap
    }

    public var filtersNodes: Bool { true }

    public var indexedFilter: FNodeFilter

    public var index: FIndex

    static func startPost(fromQueryParams params: FQueryParams) -> FNamedNode {
        if params.hasStart {
            let startKey = params.indexStartKey
            return params.index.makePost(params.indexStartValue, name: startKey)
        } else {
            return params.index.minPost
        }
    }

    static func endPost(fromQueryParams params: FQueryParams) -> FNamedNode {
        if params.hasEnd {
            let endKey = params.indexEndKey
            return params.index.makePost(params.indexEndValue, name: endKey)
        } else {
            return params.index.maxPost
        }
    }

    @objc public func matchesKey(_ key: String, andNode node: FNode) -> Bool {
        index.compareKey(startPost.name,
                         andNode: startPost.node,
                         toOtherKey: key,
                         andNode: node).rawValue <= ComparisonResult.orderedSame.rawValue &&
        index.compareKey(key,
                         andNode: node,
                         toOtherKey: endPost.name,
                         andNode: endPost.node).rawValue <= ComparisonResult.orderedSame.rawValue
    }
}
