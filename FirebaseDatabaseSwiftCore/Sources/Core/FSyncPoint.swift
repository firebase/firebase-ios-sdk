//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 24/03/2022.
//

import Foundation

@objc public class FSyncPoint: NSObject {
    private var views: [FQueryParams: FView] = [:]
    private let persistenceManager: FPersistenceManager?

    @objc public init(persistenceManager: FPersistenceManager?) {
        self.persistenceManager = persistenceManager
    }

    @objc public var isEmpty: Bool {
        views.isEmpty
    }

    @objc public func applyOperation(_ operation: FOperation,
                                     toView view: FView,
                                     writesCache: FWriteTreeRef,
                                     serverCache: FNode?) -> [FEvent] {
        let result = view.applyOperation(operation, writesCache: writesCache, serverCache: serverCache)
        if !view.query.loadsAllData {
            var removed: Set<String> = []
            var added: Set<String> = []
            for change in result.changes {
                guard let childKey = change.childKey else { continue }
                if change.type == .childAdded {
                    added.insert(childKey)
                } else if change.type == .childRemoved {
                    removed.insert(childKey)
                }
            }
            if !removed.isEmpty || !added.isEmpty {
                persistenceManager?.updateTrackedQueryKeys(withAddedKeys: added, removedKeys: removed, forQuery: view.query)
            }
        }
        return result.events
    }

    @objc public func applyOperation(_ operation: FOperation,
                                     writesCache: FWriteTreeRef,
                                     serverCache: FNode?) -> [FEvent] {
        if let queryParams = operation.source.queryParams {
            guard let view = views[queryParams] else {
                assertionFailure("SyncTree gave us an op for an invalid query.")
                return []
            }
            return applyOperation(operation, toView: view, writesCache: writesCache, serverCache: serverCache)
        } else {
            var events: [FEvent] = []
            for view in views.values {
                let eventsForView = applyOperation(operation, toView: view, writesCache: writesCache, serverCache: serverCache)
                events.append(contentsOf: eventsForView)
            }
            return events
        }
    }

    @objc public func getView(_ query: FQuerySpec, writesCache: FWriteTreeRef, serverCache: FCacheNode) -> FView {
        if let view = views[query.params] {
            return view
        }
        let eventCache: FNode
        let calculated = writesCache.calculateCompleteEventCache(completeServerCache: serverCache.isFullyInitialized ? serverCache.node : nil)
        let eventCacheComplete: Bool
        if let calculated = calculated {
            eventCacheComplete = true
            eventCache = calculated
        } else {
            eventCache = writesCache.calculateCompleteEventChildren(completeServerChildren: serverCache.node /* XXX TODO, OBJC CODE ASSUMES THAT SERVERCACHENODE CAN BE NIL ... ?? FEmptyNode.emptyNode */)
            eventCacheComplete = false
        }
        let indexed = FIndexedNode(node: eventCache, index: query.index)
        let eventCacheNode = FCacheNode(indexedNode: indexed, isFullyInitialized: eventCacheComplete, isFiltered: false)
        let viewCache = FViewCache(eventCache: eventCacheNode, serverCache: serverCache)
        return FView(query: query, initialViewCache: viewCache)
    }

    @objc public func addEventRegistration(_ eventRegistration: FEventRegistration, forNonExistingViewForQuery query: FQuerySpec, writesCache: FWriteTreeRef, serverCache: FCacheNode) -> [FEvent] {
        assert(self.views[query.params] == nil, "Found view for query: \(query.params)")
        // TODO: make writesCache take flag for complete server node
        let view = getView(query, writesCache: writesCache, serverCache: serverCache)

        // If this is a non-default query we need to tell persistence our current
        // view of the data
        if !query.loadsAllData {
            var allKeys: Set<String> = []
            view.eventCache.enumerateChildren { key, node, stop in
                allKeys.insert(key)
            }
            persistenceManager?.setTrackedQueryKeys(allKeys, forQuery: query)
        }
        views[query.params] = view
        return addEventRegistration(eventRegistration, forExistingViewForQuery: query)
    }

    @objc public func addEventRegistration(_ eventRegistration: FEventRegistration, forExistingViewForQuery query: FQuerySpec) -> [FEvent] {
        guard let view = views[query.params] else {
            assertionFailure("No view for query: \(query)")
            return []
        }
        view.addEventRegistration(eventRegistration)
        return view.initialEvents(eventRegistration)
    }

    /**
     * Remove event callback(s). Return cancelEvents if a cancelError is specified.
     *
     * If query is the default query, we'll check all views for the specified
     * eventRegistration. If eventRegistration is nil, we'll remove all callbacks
     * for the specified view(s).
     *
     * @return FTupleRemovedQueriesEvents removed queries and any cancel events
     */
    @objc public func removeEventRegistration(_ eventRegistration: FEventRegistration, forQuery query: FQuerySpec, cancelError: Error?) -> FTupleRemovedQueriesEvents {
        var removedQueries: [FQuerySpec] = []
        var cancelEvents: [FEvent] = []
        let hadCompleteView = self.hasCompleteView
        if query.isDefault {
            // When you do [ref removeObserverWithHandle:], we search all views for
            // the registration to remove.
            for (viewQueryParams, view) in views {
                cancelEvents.append(contentsOf: view.removeEventRegistration(eventRegistration, cancelError: cancelError))
                if view.isEmpty {
                    views.removeValue(forKey: viewQueryParams)

                    // We'll deal with complete views later
                    if !view.query.loadsAllData {
                        removedQueries.append(view.query)
                    }
                }
            }
        } else {
            // remove the callback from the specific view
            if let view = views[query.params] {
                cancelEvents.append(contentsOf: view.removeEventRegistration(eventRegistration, cancelError: cancelError))
                if view.isEmpty {
                    views.removeValue(forKey: query.params)

                    // We'll deal with complete views later
                    if !view.query.loadsAllData {
                        removedQueries.append(view.query)
                    }
                }
            }
        }
        if hadCompleteView && !hasCompleteView {
            // We removed our last complete view
            removedQueries.append(FQuerySpec.defaultQueryAtPath(query.path))
        }
        return FTupleRemovedQueriesEvents(removedQueries: removedQueries, cancelEvents: cancelEvents)
    }

    @objc public var queryViews: [FView] {
        views.values.filter {
            !$0.query.loadsAllData
        }
    }

    @objc public func completeServerCacheAtPath(_ path: FPath) -> FNode? {
        views.values.lazy.compactMap { $0.completeServerCache(for: path) }.first
    }

    @objc public func completeEventCacheAtPath(_ path: FPath) -> FNode? {
        views.values.lazy.compactMap { $0.completeEventCache(for: path) }.first
    }

    @objc public func viewForQuery(_ query: FQuerySpec) -> FView? {
        views[query.params]
    }

    @objc public  func viewExistsForQuery(_ query: FQuerySpec) -> Bool {
        views[query.params] != nil
    }

    @objc public var hasCompleteView: Bool {
        completeView != nil
    }

    @objc  public var completeView: FView? {
        views.values.lazy.first { $0.query.loadsAllData }
    }

}
