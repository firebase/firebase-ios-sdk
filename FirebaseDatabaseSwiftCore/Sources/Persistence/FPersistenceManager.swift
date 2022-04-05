//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 14/03/2022.
//

import Foundation

@objc public class FPersistenceManager: NSObject {
    var storageEngine: FStorageEngine!
    let cachePolicy: FCachePolicy
    var trackedQueryManager: FTrackedQueryManager!
    var serverCacheUpdatesSinceLastPruneCheck: Int

    @objc public init(storageEngine: FStorageEngine, cachePolicy: FCachePolicy) {
        self.storageEngine = storageEngine
        self.cachePolicy = cachePolicy
        self.trackedQueryManager = FTrackedQueryManager(storageEngine: storageEngine, clock: FSystemClock.clock)
        self.serverCacheUpdatesSinceLastPruneCheck = 0
    }

    @objc public func close() {
        storageEngine.close()
        self.storageEngine = nil
        self.trackedQueryManager = nil
    }

    @objc public func saveUserOverwrite(_ node: FNode, atPath path: FPath, writeId: Int) {
        storageEngine.saveUserOverwrite(node, atPath: path, writeId: writeId)
    }

    @objc public func saveUserMerge(_ merge: FCompoundWrite, atPath path: FPath, writeId: Int) {
        storageEngine.saveUserMerge(merge, atPath: path, writeId: writeId)
    }
    @objc public func removeUserWrite(_ writeId: Int) {
        storageEngine.removeUserWrite(writeId)
    }
    @objc public func removeAllUserWrites() {
        storageEngine.removeAllUserWrites()
    }
    @objc public var userWrites: [FWriteRecord] {
        storageEngine.userWrites
    }

    @objc public func serverCacheForQuery(_ query: FQuerySpec) -> FCacheNode {
        let trackedKeys: Set<String>?
        let complete: Bool
        // TODO[offline]: Should we use trackedKeys to find out if this location is
        // a child of a complete query?
        if trackedQueryManager.isQueryComplete(query) {
            complete = true
            if let trackedQuery = trackedQueryManager.findTrackedQuery(query), !query.loadsAllData && trackedQuery.isComplete {
                trackedKeys = storageEngine.trackedQueryKeysForQuery(trackedQuery.queryId)
            } else {
                trackedKeys = nil
            }
        } else {
            complete = false
            trackedKeys = trackedQueryManager.knownCompleteChildrenAtPath(query.path)
        }
        let node: FNode
        if let trackedKeys = trackedKeys {
            node = storageEngine.serverCache(forKeys: trackedKeys, atPath: query.path)
        } else {
            node = storageEngine.serverCache(atPath: query.path)
        }
        let indexedNode = FIndexedNode(node: node, index: query.index)
        return FCacheNode(indexedNode: indexedNode, isFullyInitialized: complete, isFiltered: trackedKeys != nil)
    }

    @objc public func updateServerCache(node: FNode, forQuery query: FQuerySpec) {
        let merge = !query.loadsAllData
        storageEngine.updateServerCache(node, atPath: query.path, merge: merge)
        setQueryComplete(query)
        doPruneCheckAfterServerUpdate()
    }

    @objc public func updateServerCache(merge: FCompoundWrite, atPath path: FPath) {
        storageEngine.updateServerCache(merge: merge, atPath: path)
        doPruneCheckAfterServerUpdate()
    }

    @objc public func applyUserWrite(_ write: FNode, toServerCacheAtPath path: FPath) {
        // This is a hack to guess whether we already cached this because we got a
        // server data update for this write via an existing active default query.
        // If we didn't, then we'll manually cache this and add a tracked query to
        // mark it complete and keep it cached. Unfortunately this is just a guess
        // and it's possible that we *did* get an update (e.g. via a filtered query)
        // and by overwriting the cache here, we'll actually store an incorrect
        // value (e.g. in the case that we wrote a ServerValue.TIMESTAMP and the
        // server resolved it to a different value).
        // TODO[offline]: Consider reworking.
        if !trackedQueryManager.hasActiveDefaultQueryAtPath(path) {
            storageEngine.updateServerCache(write, atPath: path, merge: false)
            trackedQueryManager.ensureCompleteTrackedQueryAtPath(path)
        }

    }
    @objc public func applyUserMerge(_ merge: FCompoundWrite, toServerCacheAtPath path: FPath) {
        // TODO[offline]: rework this to be more efficient
        merge.enumerateWrites { relativePath, node, stop in
            self.applyUserWrite(node, toServerCacheAtPath: path.child(relativePath))
        }
    }

    @objc public func setQueryComplete(_ query: FQuerySpec) {
        if query.loadsAllData {
            trackedQueryManager.setQueriesCompleteAtPath(query.path)
        } else {
            trackedQueryManager.setQueryComplete(query)
        }
    }

    @objc public func setQueryActive(_ spec: FQuerySpec) {
        trackedQueryManager.setQueryActive(spec)
    }

    @objc public func setQueryInactive(_ spec: FQuerySpec) {
        trackedQueryManager.setQueryInactive(spec)
    }

    private func doPruneCheckAfterServerUpdate() {
        serverCacheUpdatesSinceLastPruneCheck += 1
        guard !cachePolicy.shouldCheckCacheSize(serverCacheUpdatesSinceLastPruneCheck) else {
            return
        }
        FFDebug("I-RDB078001", "Reached prune check threshold. Checking...");

        let date = Date()
        self.serverCacheUpdatesSinceLastPruneCheck = 0
        var canPrune = true
        var cacheSize = storageEngine.serverCacheEstimatedSizeInBytes
        FFDebug("I-RDB078002", "Server cache size: \(cacheSize)")
        while (canPrune &&
               cachePolicy.shouldPruneCache(size: cacheSize,
                                            numberOfTrackedQueries: trackedQueryManager
                .numberOfPrunableQueries)) {
            let pruneForest = trackedQueryManager.pruneOldQueries(cachePolicy)
            if pruneForest.prunesAnything() {
                storageEngine.pruneCache(pruneForest,
                                         atPath: .empty)
            } else {
                canPrune = false
            }
            cacheSize = storageEngine.serverCacheEstimatedSizeInBytes
            FFDebug("I-RDB078003", "Cache size after pruning: \(cacheSize)")
        }
        FFDebug("I-RDB078004", "Pruning round took \(date.timeIntervalSinceNow * -1000)ms")
    }

    @objc public func setTrackedQueryKeys(_ keys: Set<String>, forQuery query: FQuerySpec) {
        assert(!query.loadsAllData,
                 "We should only track keys for filtered queries")
        guard let trackedQuery =
                trackedQueryManager.findTrackedQuery(query) else {
            assertionFailure("We only expect tracked keys for currently-active queries.")
            return
        }
        assert(trackedQuery.isActive,
                 "We only expect tracked keys for currently-active queries.")
        storageEngine.setTrackedQueryKeys(keys, forQueryId: trackedQuery.queryId)
    }

    @objc public func updateTrackedQueryKeys(withAddedKeys added: Set<String>, removedKeys removed: Set<String>, forQuery query: FQuerySpec) {
        assert(!query.loadsAllData,
                 "We should only track keys for filtered queries")
        guard let trackedQuery =
                trackedQueryManager.findTrackedQuery(query) else {
            assertionFailure("We only expect tracked keys for currently-active queries.")
            return
        }
        assert(trackedQuery.isActive,
                 "We only expect tracked keys for currently-active queries.")
        storageEngine.updateTrackedQueryKeys(addedKeys: added, removedKeys: removed, forQueryId: trackedQuery.queryId)
    }
}
