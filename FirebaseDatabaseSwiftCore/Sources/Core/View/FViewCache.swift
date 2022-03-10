//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation

@objc public class FViewCache: NSObject {
    @objc public let cachedEventSnap: FCacheNode
    @objc public var completeEventSnap: FNode? {
        cachedEventSnap.isFullyInitialized ? cachedEventSnap.node : nil
    }

    @objc public let cachedServerSnap: FCacheNode
    @objc public var completeServerSnap: FNode? {
        cachedServerSnap.isFullyInitialized
                   ? cachedServerSnap.node
                   : nil
    }

    @objc public init(eventCache: FCacheNode, serverCache: FCacheNode) {
        self.cachedEventSnap = eventCache
        self.cachedServerSnap = serverCache
    }
    @objc public func updateEventSnap(_ eventSnap: FIndexedNode, isComplete: Bool, isFiltered: Bool) -> FViewCache {
        let updatedEventCache = FCacheNode(indexedNode: eventSnap,
                                           isFullyInitialized: isComplete,
                                           isFiltered: isFiltered)
        return FViewCache(eventCache: updatedEventCache,
                          serverCache: cachedServerSnap)

    }
    @objc public func updateServerSnap(_ serverSnap: FIndexedNode, isComplete: Bool, isFiltered: Bool) -> FViewCache {
        let updatedServerCache = FCacheNode(indexedNode: serverSnap,
                                            isFullyInitialized: isComplete,
                                            isFiltered: isFiltered)
        return FViewCache(eventCache: cachedEventSnap,
                          serverCache: updatedServerCache)

    }
}
