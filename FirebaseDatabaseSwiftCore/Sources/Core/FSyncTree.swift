//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 24/03/2022.
//

import Foundation

@objc public protocol FSyncTreeHash: NSObjectProtocol {
    var simpleHash: String { get }
    var compoundHash: FCompoundHashWrapper { get }
    var includeCompoundHash: Bool { get }
}

// Size after which we start including the compound hash
let kFSizeThresholdForCompoundHash = 1024

@objc public class FListenContainer: NSObject, FSyncTreeHash {
    @objc public var view: FView
    @objc public var onComplete: (String) -> [FEvent]

    @objc public init(view: FView, onComplete: @escaping (String) -> [FEvent]) {
        self.view = view
        self.onComplete = onComplete
    }

    public var serverCache: FNode {
        view.serverCache
    }

    public var compoundHash: FCompoundHashWrapper {
        FCompoundHashWrapper(wrapped: FCompoundHash.fromNode(node: serverCache))
    }

    public var simpleHash: String {
        serverCache.dataHash()
    }

    public var includeCompoundHash: Bool {
        FSnapshotUtilities.estimateSerializedNodeSize(serverCache) > kFSizeThresholdForCompoundHash
    }
}

/**
 * SyncTree is the central class for managing event callback registration, data
 * caching, views (query processing), and event generation.  There are typically
 * two SyncTree instances for each Repo, one for the normal Firebase data, and
 * one for the .info data.
 *
 * It has a number of responsibilities, including:
 *  - Tracking all user event callbacks (registered via addEventRegistration:
 * and removeEventRegistration:).
 *  - Applying and caching data changes for user setValue:,
 * runTransactionBlock:, and updateChildValues: calls
 *    (applyUserOverwriteAtPath:, applyUserMergeAtPath:).
 *  - Applying and caching data changes for server data changes
 * (applyServerOverwriteAtPath:, applyServerMergeAtPath:).
 *  - Generating user-facing events for server and user changes (all of the
 * apply* methods return the set of events that need to be raised as a result).
 *  - Maintaining the appropriate set of server listens to ensure we are always
 * subscribed to the correct set of paths and queries to satisfy the current set
 * of user event callbacks (listens are started/stopped using the provided
 * listenProvider).
 *
 * NOTE: Although SyncTree tracks event callbacks and calculates events to
 * raise, the actual events are returned to the caller rather than raised
 * synchronously.
 */
@objc public class FSyncTree: NSObject {
    /**
     * Tree of SyncPoints. There's a SyncPoint at any location that has 1 or more
     * views.
     */
    var syncPointTree: FImmutableTree<FSyncPoint> = .empty

    /**
     * A tree of all pending user writes (user-initiated set, transactions, updates,
     * etc)
     */
    var pendingWriteTree: FWriteTree = FWriteTree()

    /**
     * Maps tagId -> FTuplePathQueryParams
     */

    var tagToQueryMap: [Int: FQuerySpec] = [:]
    var queryToTagMap: [FQuerySpec: Int] = [:]
    let listenProvider: FListenProvider
    let persistenceManager: FPersistenceManager?
    let queryTagCounter: FAtomicNumber = FAtomicNumber()
    var keepSyncedQueries: Set<FQuerySpec> = []

    @objc public init(listenProvider: FListenProvider) {
        self.listenProvider = listenProvider
        self.persistenceManager = nil

    }

    @objc public init(persistenceManager: FPersistenceManager?, listenProvider: FListenProvider) {
        self.listenProvider = listenProvider
        self.persistenceManager = persistenceManager
    }

    //MARK: -
    //MARK: Apply Operations

    /**
     * Apply data changes for a user-generated setValue: runTransactionBlock:
     * updateChildValues:, etc.
     * @return NSArray of FEvent to raise.
     */
    @objc public func applyUserOverwriteAtPath(_ path: FPath, newData: FNode, writeId: Int, isVisible: Bool) -> [FEvent] {
        // Record pending write
        pendingWriteTree.addOverwriteAtPath(path, newData: newData, writeId: writeId, isVisible: isVisible)
        if !isVisible {
            return []
        } else {
            let operation = FOverwrite(source: .userInstance, path: path, snap: newData)
            return applyOperationToSyncPoints(operation)
        }
    }

    /**
     * Apply the data from a user-generated updateChildValues: call
     * @return NSArray of FEvent to raise.
     */
    @objc public func applyUserMergeAtPath(_ path: FPath, changedChildren: FCompoundWrite, writeId: Int) -> [FEvent] {
        // Record pending merge
        pendingWriteTree.addMergeAtPath(path, changedChildren: changedChildren, writeId: writeId)
        let operation = FMerge(source: .userInstance, path: path, children: changedChildren)
        return applyOperationToSyncPoints(operation)
    }

    /**
     * Acknowledge a pending user write that was previously registered with
     * applyUserOverwriteAtPath: or applyUserMergeAtPath:
     * TODO[offline]: Taking a serverClock here is awkward, but server values are
     * awkward. :-(
     */
    @objc public func ackUserWriteWithWriteId(_ writeId: Int, revert: Bool, persist: Bool, clock: FClock) -> [FEvent] {
        let write = pendingWriteTree.writeForId(writeId)
        let needToReevaluate = pendingWriteTree.removeWriteId(writeId)
        if let write = write, write.visible {
            if persist {
                persistenceManager?.removeUserWrite(writeId)
            }
            if !revert {
                let serverValues = FServerValues.generateServerValues(clock)
                if let overwrite = write.overwrite {
                    let resolvedNode = FServerValues.resolveDeferredValueSnapshot(overwrite, withSyncTree: self, atPath: write.path, serverValues: serverValues)
                    persistenceManager?.applyUserWrite(resolvedNode, toServerCacheAtPath: write.path)
                } else if let merge = write.merge {
                    let resolvedMerge = FServerValues.resolveDeferredValueCompoundWrite(merge, withSyncTree: self, atPath: write.path, serverValues: serverValues)
                    persistenceManager?.applyUserMerge(resolvedMerge, toServerCacheAtPath: write.path)
                }
            }
        }
        if !needToReevaluate {
            return []
        } else if let write = write {
            var affectedTree: FImmutableTree<Bool> = .empty
            if write.isOverwrite {
                affectedTree = affectedTree.setValue(true, atPath: .empty)
            } else if let merge = write.merge {
                merge.enumerateWrites { path, node, stop in
                    affectedTree = affectedTree.setValue(true, atPath: path)
                }
            }
            let operation = FAckUserWrite(path: write.path, affectedTree: affectedTree, revert: revert)
            return applyOperationToSyncPoints(operation)
        }
        return []
    }

    @objc public func applyServerOverwriteAtPath(_ path: FPath, newData: FNode) -> [FEvent] {
        persistenceManager?.updateServerCache(node: newData, forQuery: .defaultQueryAtPath(path))
        let operation = FOverwrite(source: .serverInstance, path: path, snap: newData)
        return applyOperationToSyncPoints(operation)
    }

    @objc public func applyServerMergeAtPath(_ path: FPath, changedChildren: FCompoundWrite) -> [FEvent] {
        persistenceManager?.updateServerCache(merge: changedChildren, atPath: path)
        let operation = FMerge(source: .serverInstance, path: path, children: changedChildren)
        return applyOperationToSyncPoints(operation)
    }

    @objc public func applyServerRangeMergeAtPath(_ path: FPath, updates ranges: [FRangeMerge]) -> [FEvent] {
        guard let syncPoint = syncPointTree.value(atPath: path) else {
            // Removed view, so it's safe to just ignore this update
            return []
        }

        // This could be for any "complete" (unfiltered) view, and if there is
        // more than one complete view, they should each have the same cache so
        // it doesn't matter which one we use.
        if let view = syncPoint.completeView {
            var serverNode = view.serverCache
            for merge in ranges {
                serverNode = merge.applyToNode(serverNode)
            }
            return applyServerOverwriteAtPath(path, newData: serverNode)
        } else {
            // There doesn't exist a view for this update, so it was removed and
            // it's safe to just ignore this range merge
            return []
        }
    }

    private func applyListenCompleteAtPath(_ path: FPath) -> [FEvent] {
        persistenceManager?.setQueryComplete(.defaultQueryAtPath(path))

        let operation = FListenComplete(source: .serverInstance, path: path)
        return applyOperationToSyncPoints(operation)
    }

    private func applyTaggedListenCompleteAtPath(_ path: FPath, tagId: Int) -> [FEvent] {
        if let query = query(for: tagId) {
            persistenceManager?.setQueryComplete(query)
            let relativePath = FPath.relativePath(from: query.path, to: path)
            let op = FListenComplete(source: .forServerTaggedQuery(query.params), path: relativePath)
            return applyTaggedOperation(op, atPath: query.path)
        } else {
            // We've already removed the query. No big deal, ignore the update.
            return []
        }
    }

    private func applyTaggedOperation(_ operation: FOperation, atPath path: FPath) -> [FEvent] {
        guard let syncPoint = syncPointTree.value(atPath: path) else {
            assertionFailure("Missing sync point for query tag that we're tracking.")
            return []
        }
        let writesCache = pendingWriteTree.childWritesForPath(path)
        return syncPoint.applyOperation(operation, writesCache: writesCache, serverCache: nil)
    }

    @objc public func applyTaggedQueryOverwriteAtPath(_ path: FPath, newData: FNode, tagId: Int) -> [FEvent] {
        if let query = query(for: tagId) {
            let relativePath = FPath.relativePath(from: query.path, to: path)
            let queryToOverwrite = relativePath.isEmpty ? query : FQuerySpec.defaultQueryAtPath(path)
            persistenceManager?.updateServerCache(node: newData, forQuery: queryToOverwrite)
            let operation = FOverwrite(source: .forServerTaggedQuery(query.params), path: relativePath, snap: newData)
            return applyTaggedOperation(operation, atPath: query.path)
        } else {
            // Query must have been removed already
            return []
        }
    }
    @objc public func applyTaggedQueryMergeAtPath(_ path: FPath, changedChildren: FCompoundWrite, tagId: Int) -> [FEvent] {
        guard let query = query(for: tagId) else {
            // We've already removed the query. No big deal, ignore the update.
            return []
        }
        let relativePath = FPath.relativePath(from: query.path, to: path)
        persistenceManager?.updateServerCache(merge: changedChildren, atPath: path)
        let operation = FMerge(source: .forServerTaggedQuery(query.params), path: relativePath, children: changedChildren)
        return applyTaggedOperation(operation, atPath: query.path)
    }

    private func query(for tagId: Int) -> FQuerySpec? {
        tagToQueryMap[tagId]
    }

    private func tag(for query: FQuerySpec) -> Int? {
        queryToTagMap[query]
    }

    @objc public func applyTaggedServerRangeMergeAtPath(_ path: FPath, updates ranges: [FRangeMerge], tagId: Int) -> [FEvent] {
        guard let query = query(for: tagId) else {
            // We've already removed the query. No big deal, ignore the update.
            return []
        }
        assert(path == query.path, "Tagged update path and query path must match")
        guard let syncPoint = syncPointTree.value(atPath: path) else {
            assertionFailure("Missing sync point for query tag that we're tracking.")
            return []
        }
        guard let view = syncPoint.viewForQuery(query) else {
            assertionFailure("Missing view for query tag that we're tracking")
            return []
        }
        var serverNode = view.serverCache
        for merge in ranges {
            serverNode = merge.applyToNode(serverNode)
        }
        return applyTaggedQueryOverwriteAtPath(path, newData: serverNode, tagId: tagId)
    }

    @objc public func addEventRegistration(_ eventRegistration: FEventRegistration, forQuery query: FQuerySpec) -> [FEvent] {
        let path = query.path
        var foundAncestorDefaultView = false

        _ = syncPointTree.forEachOn(path: path) { pathToSyncPoint, syncPoint in
            foundAncestorDefaultView = foundAncestorDefaultView || syncPoint.hasCompleteView
            return !foundAncestorDefaultView
        }

        persistenceManager?.setQueryActive(query)

        let syncPoint: FSyncPoint
        if let sp = syncPointTree.value(atPath: path) {
            syncPoint = sp
        } else {
            syncPoint = FSyncPoint(persistenceManager: persistenceManager)
            syncPointTree = syncPointTree.setValue(syncPoint, atPath: path)
        }

        let viewAlreadyExists = syncPoint.viewExistsForQuery(query)
        var events: [FEvent]
        if viewAlreadyExists {
            events = syncPoint.addEventRegistration(eventRegistration, forExistingViewForQuery: query)
        } else {
            if !query.loadsAllData {
                // We need to track a tag for this query
                assert(tag(for: query) == nil, "View does not exist, but we have a tag")
                let tagId = queryTagCounter.getAndIncrement().intValue
                queryToTagMap[query] = tagId
                tagToQueryMap[tagId] = query
            }
            let writesCache = pendingWriteTree.childWritesForPath(path)
            let serverCache = serverCacheForQuery(query)
            events = syncPoint.addEventRegistration(eventRegistration, forNonExistingViewForQuery: query, writesCache: writesCache, serverCache: serverCache)
            if !foundAncestorDefaultView {
                if let view = syncPoint.viewForQuery(query) {
                    events.append(contentsOf: setupListenerOnQuery(query, view: view))
                }
            }
        }
        return events
    }

    private func serverCacheForQuery(_ query: FQuerySpec) -> FCacheNode {
        var serverCacheNode: FNode? = nil
        _ = syncPointTree.forEachOn(path: query.path) { pathToSyncPoint, syncPoint in
            let relativePath = FPath.relativePath(from: pathToSyncPoint, to: query.path)
            serverCacheNode = syncPoint.completeServerCacheAtPath(relativePath)
            return serverCacheNode == nil
        }
        let serverCache: FCacheNode
        if let serverCacheNode = serverCacheNode {
            let indexed = FIndexedNode(node: serverCacheNode, index: query.index)
            serverCache = FCacheNode(indexedNode: indexed, isFullyInitialized: true, isFiltered: false)
        } else {
            let persistenceServerCache = persistenceManager?.serverCacheForQuery(query)
            if let persistenceServerCache = persistenceServerCache, persistenceServerCache.isFullyInitialized {
                serverCache = persistenceServerCache
            } else {
                var serverCacheNode: FNode = FEmptyNode.emptyNode
                let subtree = syncPointTree.subtree(atPath: query.path)
                subtree.forEachChild { childKey, childSyncPoint in
                    if let completeCache = childSyncPoint?.completeServerCacheAtPath(.empty) {
                        serverCacheNode = serverCacheNode.updateImmediateChild(childKey, withNewChild: completeCache)
                    }
                }
                // Fill the node with any available children we have
                persistenceServerCache?.node.enumerateChildren(usingBlock: { key, node, stop in
                    if !serverCacheNode.hasChild(key) {
                        serverCacheNode = serverCacheNode.updateImmediateChild(key, withNewChild: node)
                    }
                })
                let indexed = FIndexedNode.indexedNodeWithNode(serverCacheNode, index: query.index)
                serverCache = FCacheNode(indexedNode: indexed, isFullyInitialized: false, isFiltered: false)
            }
        }
        return serverCache
    }

    /**
     * Remove event callback(s).
     *
     * If query is the default query, we'll check all queries for the specified
     * eventRegistration. If eventRegistration is null, we'll remove all callbacks
     * for the specified query/queries.
     *
     * @param eventRegistration if nil, all callbacks are removed
     * @param cancelError If provided, appropriate cancel events will be returned
     * @return NSArray of FEvent to raise.
     */
    @objc public func removeEventRegistration(_ eventRegistration: FEventRegistration?, forQuery query: FQuerySpec, cancelError: Error?) -> [FEvent] {
        // Find the syncPoint first. Then deal with whether or not it has matching
        // listeners
        let path = query.path
        let maybeSyncPoint = syncPointTree.value(atPath: path)
        var cancelEvents: [FEvent] = []
        // A removal on a default query affects all queries at that location. A
        // removal on an indexed query, even one without other query constraints,
        // does *not* affect all queries at that location. So this check must be for
        // 'default', and not loadsAllData:
        if let maybeSyncPoint = maybeSyncPoint, query.isDefault || maybeSyncPoint.viewExistsForQuery(query) {
            let removedAndEvents = maybeSyncPoint.removeEventRegistration(eventRegistration, forQuery: query, cancelError: cancelError)
            if maybeSyncPoint.isEmpty {
                syncPointTree = syncPointTree.removeValue(atPath: path)
            }
            let removed = removedAndEvents.removedQueries
            cancelEvents = removedAndEvents.cancelEvents

            // We may have just removed one of many listeners and can short-circuit
            // this whole process We may also not have removed a default listener,
            // in which case all of the descendant listeners should already be
            // properly set up.
            //
            // Since indexed queries can shadow if they don't have other query
            // constraints, check for loadsAllData: instead of isDefault:
            let defaultQueryIndex = removed.firstIndex { $0.loadsAllData }
            let removingDefault = defaultQueryIndex != nil
            for query in removed {
                persistenceManager?.setQueryInactive(query)
            }
            let covered = syncPointTree.find(onPath: path) { $1.hasCompleteView
            } ?? false
            if removingDefault && !covered {
                let subtree = syncPointTree.subtree(atPath: path)
                // There are potentially child listeners. Determine what if any
                // listens we need to send before executing the removal
                if !subtree.isEmpty {
                    // We need to fold over our subtree and collect the listeners to
                    // send
                    let newViews: [FView] = collectDistinctViewsForSubTree(subtree)
                    // Ok, we've collected all the listens we need. Set them up.
                    for view in newViews {
                        let newQuery = view.query
                        let listenContainer: FListenContainer = createListenerForView(view)
                        _ = listenProvider.startListening?(queryForListening(newQuery), tag(for: newQuery).map { NSNumber(value: $0) }, listenContainer, listenContainer.onComplete)
                    }
                } else {
                    // There's nothing below us, so nothing we need to start
                    // listening on

                }
            }

            // If we removed anything and we're not covered by a higher up listen,
            // we need to stop listening on this query. The above block has us
            // covered in terms of making sure we're set up on listens lower in the
            // tree. Also, note that if we have a cancelError, it's already been
            // removed at the provider level.
            if !covered && !removed.isEmpty && cancelError == nil {
                // If we removed a default, then we weren't listening on any of the
                // other queries here. Just cancel the one default. Otherwise, we
                // need to iterate through and cancel each individual query
                if removingDefault {
                    // We don't tag default listeners
                    listenProvider.stopListening?(queryForListening(query), nil)
                } else {
                    for queryToRemove in removed {
                        let tagToRemove = tag(for: queryToRemove)
                        listenProvider.stopListening?(queryForListening(queryToRemove), tagToRemove.map { NSNumber(value: $0) })
                    }
                }
            }
            // Now, clear all the tags we're tracking for the removed listens.
            removeTags(removed)

        } else {
            // No-op, this listener must've been already removed
        }
        return cancelEvents
    }

    @objc public func keepQuery(_ query: FQuerySpec, synced keepSynced: Bool) {
        // Only do something if we actually need to add/remove an event registration
        if keepSynced && !keepSyncedQueries.contains(query) {
            _ = addEventRegistration(FKeepSyncedEventRegistration.instance, forQuery: query)
            keepSyncedQueries.insert(query)
        } else if !keepSynced && keepSyncedQueries.contains(query) {
            _ = removeEventRegistration(FKeepSyncedEventRegistration.instance, forQuery: query, cancelError: nil)
            keepSyncedQueries.remove(query)
        }
    }

    @objc public func removeAllWrites() -> [FEvent] {
        persistenceManager?.removeAllUserWrites()
        let removedWrites = pendingWriteTree.removeAllWrites()
        if !removedWrites.isEmpty {
            let affectedTree: FImmutableTree<Bool> = .empty.setValue(true, atPath: .empty)
            return applyOperationToSyncPoints(FAckUserWrite(path: .empty, affectedTree: affectedTree, revert: true))
        } else {
            return []
        }
    }

    /** Returns a non-empty cache node if one exists. Otherwise returns null. */
    @objc public func persistenceServerCache(_ querySpec: FQuerySpec) -> FIndexedNode? {
        guard let cacheNode = persistenceManager?.serverCacheForQuery(querySpec) else {
            return nil
        }
        if cacheNode.node.isEmpty {
            return nil
        }
        return cacheNode.indexedNode
    }

    @objc public func getServerValue(_ query: FQuerySpec) -> FNode? {
        var serverCacheNode: FNode? = nil
        var targetSyncPoint: FSyncPoint? = nil
        _ = syncPointTree.forEachOn(path: query.path) { pathToSyncPoint, syncPoint in
            let relativePath = FPath.relativePath(from: pathToSyncPoint, to: query.path)
            serverCacheNode = syncPoint.completeEventCacheAtPath(relativePath)
            targetSyncPoint = syncPoint
            return serverCacheNode == nil
        }
        let target: FSyncPoint
        if let targetSyncPoint = targetSyncPoint {
            target = targetSyncPoint
            serverCacheNode = serverCacheNode ?? targetSyncPoint.completeServerCacheAtPath(.empty)
        } else {
            target = FSyncPoint(persistenceManager: persistenceManager)
            syncPointTree = syncPointTree.setValue(target, atPath: query.path)
        }

        let indexed = FIndexedNode(node: serverCacheNode ?? FEmptyNode.emptyNode, index: query.index)
        let serverCache = FCacheNode(indexedNode: indexed, isFullyInitialized: serverCacheNode != nil, isFiltered: false)
        let view = target.getView(query, writesCache: pendingWriteTree.childWritesForPath(query.path), serverCache: serverCache)
        return view.completeEventCache
    }

    /**
     * Returns a complete cache, if we have one, of the data at a particular path.
     * The location must have a listener above it, but as this is only used by
     * transaction code, that should always be the case anyways.
     *
     * Note: this method will *include* hidden writes from transaction with
     * applyLocally set to false.
     * @param path The path to the data we want
     * @param writeIdsToExclude A specific set to be excluded
     */
    @objc public func calcCompleteEventCacheAtPath(_ path: FPath, excludeWriteIds: [Int]) -> FNode? {
        let includeHiddenSets = true
        let writeTree = pendingWriteTree
        let serverCache: FNode? = syncPointTree.find(onPath: path) { pathSoFar, syncPoint in
            let relativePath = FPath.relativePath(from: pathSoFar, to: path)
            return syncPoint.completeServerCacheAtPath(relativePath)
        }
        return writeTree.calculateCompleteEventCacheAtPath(path, completeServerCache: serverCache, excludeWriteIds: excludeWriteIds, includeHiddenWrites: includeHiddenSets)
    }

    /**
     * This collapses multiple unfiltered views into a single view, since we only
     * need a single listener for them.
     * @return NSArray of FView
     */
    private func collectDistinctViewsForSubTree(_ subtree: FImmutableTree<FSyncPoint>) -> [FView] {
        return subtree.fold { relativePath, maybeChildSyncPoint, childMap in
            if let completeView = maybeChildSyncPoint?.completeView {
                return [ completeView ]
            } else {
                // No complete view here, flatten any deeper listens into an array
                var views: [FView] = maybeChildSyncPoint?.queryViews ?? []
                views.append(contentsOf: childMap.values.flatMap { $0 })
                return views
            }
        }
    }

    private func removeTags(_ queries: [FQuerySpec]) {
        for removedQuery in queries {
            if !removedQuery.loadsAllData {
                // We should have a tag for this
                guard let removedQueryTag = queryToTagMap[removedQuery] else { continue }
                queryToTagMap.removeValue(forKey: removedQuery)
                tagToQueryMap.removeValue(forKey: removedQueryTag)
            }
        }
    }

    private func queryForListening(_ query: FQuerySpec) -> FQuerySpec {
        if query.loadsAllData && !query.isDefault {
            // We treat queries that load all data as default queries
            return FQuerySpec.defaultQueryAtPath(query.path)
        } else {
            return query
        }
    }

    /**
     * For a given new listen, manage the de-duplication of outstanding
     * subscriptions.
     * @return array of FEvent events to support synchronous data sources
     */
    private func setupListenerOnQuery(_ query: FQuerySpec, view: FView) -> [FEvent] {
        let path = query.path
        let tagId = tag(for: query)
        let listenContainer = createListenerForView(view)

        let events: [FEvent] = listenProvider.startListening?(queryForListening(query), tagId.map { NSNumber(value: $0) }, listenContainer, listenContainer.onComplete) ?? []

        let subtree = syncPointTree.subtree(atPath: path)

        // The root of this subtree has our query. We're here because we definitely
        // need to send a listen for that, but we may need to shadow other listens
        // as well.
        if tagId != nil {
            assert(subtree.value?.hasCompleteView != true, "If we're adding a query, it shouldn't be shadowed")
        } else {
            // Shadow everything at or below this location, this is a default
            // listener.
            let queriesToStop: [FQuerySpec] = subtree.fold { relativePath, maybeChildSyncPoint, childMap in
                if let completeView = maybeChildSyncPoint?.completeView, !relativePath.isEmpty {
                    return [completeView.query]
                } else {
                    // No default listener here, flatten any deeper queries into
                    // an array
                    var queries: [FQuerySpec] = []
                    if let maybeChildSyncPoint = maybeChildSyncPoint {
                        queries.append(contentsOf: maybeChildSyncPoint.queryViews.map(\.query))
                    }
                    queries.append(contentsOf: childMap.values.flatMap { $0 })
                    return queries
                }
            }
            for queryToStop in queriesToStop {
                listenProvider.stopListening?(queryForListening(queryToStop), tag(for: queryToStop).map { NSNumber(value: $0) })
            }
        }
        return events
    }

    private func createListenerForView(_ view: FView) -> FListenContainer {
        let query = view.query
        let tagId = tag(for: query)

        let listenContainer = FListenContainer(view: view) { status in
            if status == "ok" {
                if let tagId = tagId {
                    return self.applyTaggedListenCompleteAtPath(query.path, tagId: tagId)
                } else {
                    return self.applyListenCompleteAtPath(query.path)
                }
            } else {
                // If a listen failed, kill all of the listeners here, not just
                // the one that triggered the error. Note that this may need to
                // be scoped to just this listener if we change permissions on
                // filtered children
                let error = FUtilitiesSwift.error(for: status, reason: nil)
                FFWarn("I-RDB038012", "Listener at \(query.path) failed: \(status)")
                return self.removeEventRegistration(nil, forQuery: query, cancelError: error)
            }
        }
        return listenContainer
    }

    /**
    * A helper method that visits all descendant and ancestor SyncPoints, applying
    the operation.
    *
    * NOTES:
    * - Descendant SyncPoints will be visited first (since we raise events
    depth-first).

    * - We call applyOperation: on each SyncPoint passing three things:
    *   1. A version of the Operation that has been made relative to the SyncPoint
    location.
    *   2. A WriteTreeRef of any writes we have cached at the SyncPoint location.
    *   3. A snapshot Node with cached server data, if we have it.

    * - We concatenate all of the events returned by each SyncPoint and return the
    result.
    *
    * @return Array of FEvent
    */
    private func applyOperationToSyncPoints(_ operation: FOperation) -> [FEvent] {
        applyOperationHelper(operation, syncPointTree: syncPointTree, serverCache: nil, writesCache: pendingWriteTree.childWritesForPath(.empty))
    }

    /**
     * Recursive helper for applyOperationToSyncPoints_
     */
    private func applyOperationHelper(_ operation: FOperation, syncPointTree: FImmutableTree<FSyncPoint>, serverCache: FNode?, writesCache: FWriteTreeRef) -> [FEvent] {
        var serverCache = serverCache
        guard !operation.path.isEmpty else {
            return applyOperationDescendantsHelper(operation, syncPointTree: syncPointTree, serverCache: serverCache, writesCache: writesCache)
        }
        let syncPoint = syncPointTree.value
        // If we don't have cached server data, see if we can get it from this
        // SyncPoint
        if let syncPoint = syncPoint, serverCache == nil {
            serverCache = syncPoint.completeServerCacheAtPath(.empty)
        }
        var events: [FEvent] = []
        if let childKey = operation.path.getFront() {
            let childOperation = operation.operationForChild(childKey)
            let childTree = syncPointTree.getChild(key: childKey)
            if let childTree = childTree, let childOperation = childOperation {
                let childServerCache = serverCache?.getImmediateChild(childKey)
                let childWritesCache = writesCache.childWriteTreeRef(childKey)
                events.append(contentsOf: applyOperationHelper(childOperation, syncPointTree: childTree, serverCache: childServerCache, writesCache: childWritesCache))
            }
        }
        if let syncPoint = syncPoint {
            events.append(contentsOf: syncPoint.applyOperation(operation, writesCache: writesCache, serverCache: serverCache))
        }
        return events
    }

    /**
     *  Recursive helper for applyOperationToSyncPoints:
     */
    private func applyOperationDescendantsHelper(_ operation: FOperation, syncPointTree: FImmutableTree<FSyncPoint>, serverCache: FNode?, writesCache: FWriteTreeRef) -> [FEvent] {
        let syncPoint = syncPointTree.value
        // If we don't have cached server data, see if we can get it from this
        // SyncPoint
        let resolvedServerCache: FNode?
        if let serverCache = serverCache {
            resolvedServerCache = serverCache
        } else if let syncPoint = syncPoint {
            resolvedServerCache = syncPoint.completeServerCacheAtPath(.empty)
        } else {
            resolvedServerCache = nil
        }
        var events: [FEvent] = []
        syncPointTree.forEachChildTree { childKey, childTree in
            let childServerCache = resolvedServerCache?.getImmediateChild(childKey)
            let childWritesCache = writesCache.childWriteTreeRef(childKey)
            if let childOperation = operation.operationForChild(childKey) {
                events.append(contentsOf: self.applyOperationDescendantsHelper(childOperation, syncPointTree: childTree, serverCache: childServerCache, writesCache: childWritesCache))
            }
        }
        if let syncPoint = syncPoint {
            events.append(contentsOf: syncPoint.applyOperation(operation, writesCache: writesCache, serverCache: resolvedServerCache))
        }
        return events
    }
}
