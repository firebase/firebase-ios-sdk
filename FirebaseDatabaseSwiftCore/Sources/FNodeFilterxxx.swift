//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 28/09/2021.
//

import Foundation

/**
 * FNodeFilter is used to update nodes and complete children of nodes while
 * applying queries on the fly and keeping track of any child changes. This
 * class does not track value changes as value changes depend on more than just
 * the node itself. Different kind of queries require different kind of
 * implementations of this interface.
 */

// Depends on FChildChangeAccumulator which has other dependencies
// and FCompleteChildSource - wait with this
//@objc public protocol FNodeFilter: NSObjectProtocol {
//
//    /**
//     * Update a single complete child in the snap. If the child equals the old child
//     * in the snap, this is a no-op. The method expects an indexed snap.
//     */
//    func updateChild(
//        in oldSnap: FIndexedNode?,
//        forChildKey childKey: String?,
//        newChild newChildSnap: FNode?,
//        affectedPath: FPath?,
//        from source: FCompleteChildSource?,
//        accumulator optChangeAccumulator: FChildChangeAccumulator?
//    ) -> FIndexedNode?
//    /**
//     * Update a node in full and output any resulting change from this complete
//     * update.
//     */
//    func updateFullNode(
//        _ oldSnap: FIndexedNode?,
//        withNewNode newSnap: FIndexedNode?,
//        accumulator optChangeAccumulator: FChildChangeAccumulator?
//    ) -> FIndexedNode?
//
//    /**
//     * Update the priority of the root node
//     */
//    func updatePriority(
//        _ priority: FNode?,
//        for oldSnap: FIndexedNode?
//    ) -> FIndexedNode?
//
//    /**
//     * Returns true if children might be filtered due to query critiera
//     */
//    var filtersNodes: Bool { get }
//
//    /**
//     * Returns the index filter that this filter uses to get a NodeFilter that
//     * doesn't filter any children.
//     */
//    var indexedFilter: FNodeFilter { get }
//
//    /**
//     * Returns the index that this filter uses
//     */
//    var index: FIndex { get }
//
//}

