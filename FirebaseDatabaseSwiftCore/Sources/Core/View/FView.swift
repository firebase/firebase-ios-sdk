//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 15/03/2022.
//

import Foundation

@objc public class FViewOperationResult: NSObject {
    @objc public let changes: [FChange]
    @objc public let events: [FEvent]
    init(changes: [FChange], events: [FEvent]) {
        self.changes = changes
        self.events = events
    }
}

/**
 * A view represents a specific location and query that has 1 or more event
 * registrations.
 *
 * It does several things:
 * - Maintains the list of event registration for this location/query.
 * - Maintains a cache of the data visible for this location/query.
 * - Applies new operations (via applyOperation), updates the cache, and based
 * on the event registrations returns the set of events to be raised.
 */
/*
 @property(nonatomic, strong) FViewProcessor *processor;
 @property(nonatomic, strong) FViewCache *viewCache;
 @property(nonatomic, strong) NSMutableArray *eventRegistrations;
 @property(nonatomic, strong) FEventGenerator *eventGenerator;

 */
@objc public class FView: NSObject {
    private let processor: FViewProcessor
    private var viewCache: FViewCache
    private var eventRegistrations: [FEventRegistration]
    private let eventGenerator: FEventGenerator
    @objc public let query: FQuerySpec
    @objc public var eventCache: FNode {
        viewCache.cachedEventSnap.node
    }
    @objc public var serverCache: FNode {
        viewCache.cachedServerSnap.node
    }
    @objc public var completeEventCache: FNode? {
        viewCache.completeEventSnap
    }
    @objc public init(query: FQuerySpec, initialViewCache: FViewCache) {
        self.query = query
        let indexFilter = FIndexedFilter(index: query.index)
        let filter = query.params.nodeFilter
        self.processor = FViewProcessor(filter: filter)
        let initialServerCache = initialViewCache.cachedServerSnap
        let initialEventCache = initialViewCache.cachedEventSnap

        // Don't filter server node with other filter than index, wait for
        // tagged listen
        let emptyIndexedNode = FIndexedNode(node: FEmptyNode.emptyNode, index: query.index)
        let serverSnap = indexFilter.updateFullNode(emptyIndexedNode, withNewNode: initialServerCache.indexedNode, accumulator: nil)
        let eventSnap = filter.updateFullNode(emptyIndexedNode, withNewNode: initialEventCache.indexedNode, accumulator: nil)
        let newServerCache = FCacheNode(indexedNode: serverSnap, isFullyInitialized: initialServerCache.isFullyInitialized, isFiltered: indexFilter.filtersNodes)
        let newEventCache = FCacheNode(indexedNode: eventSnap, isFullyInitialized: initialEventCache.isFullyInitialized, isFiltered: filter.filtersNodes)
        self.viewCache = FViewCache(eventCache: newEventCache, serverCache: newServerCache)
        self.eventRegistrations = []
        self.eventGenerator = FEventGenerator(query: query)
    }

    @objc public func completeServerCache(for path: FPath) -> FNode? {
        guard let cache = viewCache.completeServerSnap else { return nil }
        // If this isn't a "loadsAllData" view, then cache isn't actually a
        // complete cache and we need to see if it contains the child we're
        // interested in.
        if query.loadsAllData {
            return cache.getChild(path)
        }
        if let front = path.getFront(), !cache.getImmediateChild(front).isEmpty {
            return cache.getChild(path)
        }
        return nil
    }

    @objc public func completeEventCache(for path: FPath) -> FNode? {
        guard let cache = viewCache.completeEventSnap else { return nil }
        // If this isn't a "loadsAllData" view, then cache isn't actually a
        // complete cache and we need to see if it contains the child we're
        // interested in.
        if query.loadsAllData {
            return cache.getChild(path)
        }
        if let front = path.getFront(), !cache.getImmediateChild(front).isEmpty {
            return cache.getChild(path)
        }
        return nil

    }
    @objc public var isEmpty: Bool {
        eventRegistrations.isEmpty
    }

    @objc public func addEventRegistration(_ eventRegistration: FEventRegistration) {
        eventRegistrations.append(eventRegistration)
    }

    /**
     * @param eventRegistration If null, remove all callbacks.
     * @param cancelError If a cancelError is provided, appropriate cancel events
     * will be returned.
     * @return Cancel events, if cancelError was provided.
     */
    @objc public func removeEventRegistration(_ eventRegistration: FEventRegistration?, cancelError: Error?) -> [FEvent] {
        var cancelEvents: [FEvent] = []
        if let cancelError = cancelError {
            assert(eventRegistration == nil, "A cancel should cancel all event registrations.")
            let path = query.path
            for registration in eventRegistrations {
                if let event = registration.createCancelEventFromError(cancelError, path: path) {
                    cancelEvents.append(event)
                }
            }
        }
        if let eventRegistration = eventRegistration {
            eventRegistrations.removeAll { existing in
                existing.matches(eventRegistration)
            }
        } else {
            eventRegistrations = []
        }
        return cancelEvents
    }

    /**
     * Applies the given Operation, updates our cache, and returns the appropriate
     * events and changes
     */
    @objc public func applyOperation(_ operation: FOperation, writesCache: FWriteTreeRef, serverCache optCompleteServerCache: FNode?) -> FViewOperationResult {
        if operation.type == .merge && operation.source.queryParams != nil {
            assert(self.viewCache.completeServerSnap != nil,
                     "We should always have a full cache before handling merges")
            assert(self.viewCache.completeEventSnap != nil,
                     "Missing event cache, even though we have a server cache")
        }
        let oldViewCache = viewCache
        let result = processor.applyOperationOn(oldViewCache, operation: operation, writesCache: writesCache, completeCache: optCompleteServerCache)
        assert(result.viewCache.cachedServerSnap.isFullyInitialized ||
                     !oldViewCache.cachedServerSnap.isFullyInitialized,
               "Once a server snap is complete, it should never go back.")

        self.viewCache = result.viewCache
        let events = generateEvents(forChanges: result.changes, eventCache: result.viewCache.cachedEventSnap.indexedNode, registration: nil)
        return FViewOperationResult(changes: result.changes, events: events)
    }

    @objc public func initialEvents(_ registration: FEventRegistration) -> [FEvent] {
        let eventSnap = viewCache.cachedEventSnap
        var initialChanges: [FChange] = []
        eventSnap.indexedNode.node.enumerateChildren { key, node, stop in
            let indexed = FIndexedNode(node: node)
            let change = FChange(type: .childAdded, indexedNode: indexed, childKey: key)
            initialChanges.append(change)
        }
        if eventSnap.isFullyInitialized {
            let change = FChange(type: .value, indexedNode: eventSnap.indexedNode)
            initialChanges.append(change)
        }
        return generateEvents(forChanges: initialChanges, eventCache: eventSnap.indexedNode, registration: registration)
    }

    private func generateEvents(forChanges changes: [FChange], eventCache: FIndexedNode, registration: FEventRegistration?) -> [FEvent] {
        let registrations: [FEventRegistration]
        if let registration = registration {
            registrations = [registration]
        } else {
            registrations = self.eventRegistrations
        }
        return eventGenerator.generateEventsForChanges(changes, eventCache: eventCache, eventRegistrations: registrations)
    }
}
