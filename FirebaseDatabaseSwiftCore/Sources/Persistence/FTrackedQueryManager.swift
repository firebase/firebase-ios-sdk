//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 12/03/2022.
//

import Foundation

@objc public class FTrackedQueryManager: NSObject {
    let storageEngine: FStorageEngine
    let clock: FClock
    var trackedQueryTree: FImmutableTreeSwift<[FQueryParams: FTrackedQuery]>
    var currentQueryId: Int = 0
    @objc public init(storageEngine: FStorageEngine, clock: FClock) {
        self.storageEngine = storageEngine
        self.clock = clock
        self.trackedQueryTree = .empty()
        super.init()
        let lastUse = clock.currentTime

        let trackedQueries = storageEngine.loadTrackedQueries()
        for trackedQuery in trackedQueries {
            currentQueryId = max(trackedQuery.queryId, currentQueryId)
            let newQuery: FTrackedQuery
            if trackedQuery.isActive {
                newQuery = trackedQuery
                    .setActiveState(false)
                    .updateLastUse(lastUse)
                FFDebug("I-RDB081001", "Setting active query \(trackedQuery.queryId) from previous app start inactive")
                storageEngine.saveTrackedQuery(newQuery)
            } else {
                newQuery = trackedQuery
            }
            cacheTrackedQuery(newQuery)
        }
    }
    private static func assertValidTrackedQuery(_ query: FQuerySpec) {
        assert(!query.loadsAllData || query.isDefault,
               "Can't have tracked non-default query that loads all data")
    }
    private static func normalizeQuery(_ query: FQuerySpec) -> FQuerySpec {
        query.loadsAllData ? FQuerySpec.defaultQueryAtPath(query.path) : query
    }

    @objc public func findTrackedQuery(_ query: FQuerySpec) -> FTrackedQuery? {
        let query = FTrackedQueryManager.normalizeQuery(query)
        guard let set = trackedQueryTree.value(atPath: query.path) else {
            return nil
        }
        return set[query.params]
    }

    @objc public func isQueryComplete(_ query: FQuerySpec) -> Bool {
        if isIncludedInDefaultCompleteQuery(query) {
            return true
        } else if query.loadsAllData {
            // We didn't find a default complete query, so must not be complete.
            return false
        } else {
            guard let trackedQueries = trackedQueryTree.value(atPath: query.path) else {
                return false
            }
            return trackedQueries[query.params]?.isComplete ?? false
        }
    }

    @objc public func removeTrackedQuery(_ query: FQuerySpec) {
        let query = FTrackedQueryManager.normalizeQuery(query)
        guard let trackedQuery = findTrackedQuery(query) else {
            assertionFailure("Tracked query must exist to be removed!")
            return
        }
        guard var trackedQueries = trackedQueryTree.value(atPath: query.path) else {
            return
        }
        trackedQueries.removeValue(forKey: query.params)
        trackedQueryTree = trackedQueryTree.setValue(trackedQueries, atPath: query.path)
        storageEngine.removeTrackedQuery(trackedQuery.queryId)
    }

    @objc public func setQueryComplete(_ query: FQuerySpec) {
        let query = FTrackedQueryManager.normalizeQuery(query)
        guard var trackedQuery = findTrackedQuery(query) else {
            // We might have removed a query and pruned it before we got the
            // complete message from the server...
            FFWarn("I-RDB081002",
                   "Trying to set a query complete that is not tracked!")
            return
        }
        if trackedQuery.isComplete {
            // Nothing to do, already marked complete
        } else {
            trackedQuery = trackedQuery.setComplete()
            storageEngine.saveTrackedQuery(trackedQuery)
            cacheTrackedQuery(trackedQuery)
        }
    }

    @objc public func setQueriesCompleteAtPath(_ path: FPath) {
        trackedQueryTree.subtree(atPath: path).forEach { path, trackedQueries in
            for trackedQuery in trackedQueries.values {
                if !trackedQuery.isComplete {
                    let newTrackedQuery = trackedQuery.setComplete()
                    self.storageEngine.saveTrackedQuery(newTrackedQuery)
                    self.cacheTrackedQuery(newTrackedQuery)
                }
            }
        }
    }

    @objc public func setQueryActive(_ query: FQuerySpec) {
        setQueryActive(query, isActive: true)
    }
    @objc public func setQueryInactive(_ query: FQuerySpec) {
        setQueryActive(query, isActive: false)
    }

    private func setQueryActive(_ query: FQuerySpec, isActive: Bool) {
        let query = FTrackedQueryManager.normalizeQuery(query)
        let trackedQuery = findTrackedQuery(query)

        // Regardless of whether it's now active or no langer active, we update the
        // lastUse time
        let lastUse = clock.currentTime
        let resultingQuery: FTrackedQuery
        if let trackedQuery = trackedQuery {
            resultingQuery = trackedQuery
                .updateLastUse(lastUse)
                .setActiveState(isActive)
        } else {
            assert(isActive, "If we're setting the query to inactive, we should already be tracking it!")
            resultingQuery = FTrackedQuery(id: currentQueryId,
                                           query: query,
                                           lastUse: lastUse,
                                           isActive: isActive)
            currentQueryId += 1

        }
        storageEngine.saveTrackedQuery(resultingQuery)
        cacheTrackedQuery(resultingQuery)
    }

    @objc public func hasActiveDefaultQueryAtPath(_ path: FPath) -> Bool {
        trackedQueryTree.rootMostValue(onPath: path, matching: { trackedQueries in
            return (trackedQueries[FQueryParams.defaultInstance]?.isActive) ?? false
        }) != nil
    }

    private func isIncludedInDefaultCompleteQuery(_ query: FQuerySpec) -> Bool {
        trackedQueryTree.rootMostValue(onPath: query.path, matching: { trackedQueries in
            return (trackedQueries[FQueryParams.defaultInstance]?.isComplete) ?? false
        }) != nil

    }
    
    @objc public func ensureCompleteTrackedQueryAtPath(_ path: FPath) {
        let query = FQuerySpec.defaultQueryAtPath(path)
        if !isIncludedInDefaultCompleteQuery(query) {
            let resultingQuery: FTrackedQuery
            if let trackedQuery = findTrackedQuery(query) {
                assert(!trackedQuery.isComplete,
                       "This should have been handled above!")
                resultingQuery = trackedQuery.setComplete()
            } else {
                resultingQuery = FTrackedQuery(id: currentQueryId, query: query, lastUse: clock.currentTime, isActive: false, isComplete: true)
                currentQueryId += 1
            }
            storageEngine.saveTrackedQuery(resultingQuery)
            cacheTrackedQuery(resultingQuery)
        }
    }

    private func cacheTrackedQuery(_ query: FTrackedQuery) {
        FTrackedQueryManager.assertValidTrackedQuery(query.query)
        var resultingDict: [FQueryParams : FTrackedQuery]
        let trackedDict = trackedQueryTree.value(atPath: query.query.path)
        resultingDict = trackedDict ?? [:]
        resultingDict[query.query.params] = query
        trackedQueryTree = trackedQueryTree.setValue(resultingDict, atPath: query.query.path)
    }

    private func numberOfQueriesToPrune(cachePolicy: FCachePolicy,
                                        prunableCount numPrunable: Int) -> Int {
        let numPercent = Int(ceil(Double(numPrunable) * cachePolicy.percentOfQueriesToPruneAtOnce))
        let maxToKeep = cachePolicy.maxNumberOfQueriesToKeep
        let numMax = numPrunable > maxToKeep ? numPrunable - maxToKeep : 0
        // Make sure we get below number of max queries to prune
        return min(max(numMax, numPercent), numPrunable)
    }

    @objc public func pruneOldQueries(_ cachePolicy: FCachePolicy) -> FPruneForest {
        var prunableQueries: [FTrackedQuery] = []
        var unprunableQueries: [FTrackedQuery] = []
        trackedQueryTree.forEach { path, trackedQueries in
            for trackedQuery in trackedQueries.values {
                if !trackedQuery.isActive {
                    prunableQueries.append(trackedQuery)
                } else {
                    unprunableQueries.append(trackedQuery)
                }
            }
        }
        prunableQueries.sort { $0.lastUse < $1.lastUse }
        var pruneForest = FPruneForest.empty()
        let numToPrune = numberOfQueriesToPrune(cachePolicy: cachePolicy, prunableCount: prunableQueries.count)

        // TODO: do in transaction
        for toPrune in prunableQueries[0 ..< numToPrune] {
            pruneForest = pruneForest.prunePath(toPrune.query.path)
            removeTrackedQuery(toPrune.query)
        }

        // Keep the rest of the prunable queries
        for toKeep in prunableQueries[numToPrune...] {
            pruneForest = pruneForest.keepPath(toKeep.query.path)
        }

        // Also keep unprunable queries
        for toKeep in unprunableQueries {
            pruneForest = pruneForest.keepPath(toKeep.query.path)
        }
        return pruneForest
    }

    @objc public var numberOfPrunableQueries: Int {
        var count = 0

        trackedQueryTree.forEach { path, trackedQueries in
            for trackedQuery in trackedQueries.values {
                if !trackedQuery.isActive {
                    count += 1
                }
            }
        }
        return count
    }

    private func filteredQueryIdsAtPath(_ path: FPath) -> Set<Int> {
        guard let queries = trackedQueryTree.value(atPath: path) else {
            return []
        }
        var ids: Set<Int> = []
        for query in queries.values {
            if !query.query.loadsAllData {
                ids.insert(query.queryId)
            }
        }
        return ids
    }

    @objc public func knownCompleteChildrenAtPath(_ path: FPath) -> Set<String> {
        assert(!isQueryComplete(FQuerySpec.defaultQueryAtPath(path)), "Path is fully complete")
        var completeChildren: Set<String> = []
        // First, get complete children from any queries at this location.
        let queryIds = filteredQueryIdsAtPath(path)
        for queryId in queryIds {
            let keys = storageEngine.trackedQueryKeysForQuery(queryId)
            completeChildren.formUnion(keys)
        }
        // Second, get any complete default queries immediately below us.
        trackedQueryTree.subtree(atPath: path).forEachChildTree { childKey, childTree in
            guard let queries = childTree.value else { return }
            if queries[FQueryParams.defaultInstance]?.isComplete ?? false {
                completeChildren.insert(childKey)
            }
        }
        return completeChildren
    }


    // For testing
    @objc public func verifyCache() {
        let storedTrackedQueries = storageEngine.loadTrackedQueries()
        var trackedQueries: [FTrackedQuery] = []
        trackedQueryTree.forEach { path, queryDict in
            trackedQueries.append(contentsOf: queryDict.values)
        }
        trackedQueries.sort { $0.queryId < $1.queryId }
        let sortedStoredTrackedQueries = storedTrackedQueries.sorted { $0.queryId < $1.queryId }
        if trackedQueries != sortedStoredTrackedQueries {
            fatalError("Tracked queries and queries stored on disk don't match")
        }
    }
}
