//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 18/04/2022.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum FTransactionStatus: Int {
    case initializing = 0   // 0
    case run                // 1
    case sent               // 2
    case completed          // 3
    case sentNeedsAbort     // 4
    case needsAbort         // 5
}

let kFirebaseCoreErrorDomain = "com.firebase.core"

@objc public class FRepo: NSObject, FPersistentConnectionDelegate {
    var config: DatabaseConfig

    private var repoInfo: FRepoInfo
    private let connection: FPersistentConnection
    private let infoData: FSnapshotHolder
    private var onDisconnect: FSparseSnapshotTree
    private let eventRaiser: FEventRaiser
    private var serverSyncTree: FSyncTree!
    private var infoSyncTree: FSyncTree!

    private var persistenceManager: FPersistenceManager?
    private var serverClock: FClock
    internal var database: Database
//    @property(nonatomic, strong, readwrite) FAuthenticationManager *auth;
    var writeIdCounter: Int = 0
    var hijackHash: Bool = false
    var transactionQueueTree: FTree<[FTupleTransaction]> = FTree()
    var loggedTransactionPersistenceWarning: Bool = false

    // For testing.
    internal var dataUpdateCount: Int = 0
    internal var rangeMergeUpdateCount: Int = 0

    private let dispatchQueue: DispatchQueue = DatabaseQuery.sharedQueue


    @objc public init(repoInfo info: FRepoInfo, config: DatabaseConfig, database: Database) {
        print("FREPO INIT", config, info, database)
        self.config = config
        self.repoInfo = info
        self.database = database

        // Access can occur outside of shared queue, so the clock needs to be
        // initialized here
        self.serverClock = FOffsetClock(clock: FSystemClock.clock, offset: 0)
        self.connection = FPersistentConnection(repoInfo: info, dispatchQueue: dispatchQueue, config: config)

        // Needs to be called before authentication manager is instantiated
        self.eventRaiser = FEventRaiser(queue: config.callbackQueue)

        // A list of data pieces and paths to be set when this client disconnects
        self.onDisconnect = FSparseSnapshotTree()
        self.infoData = FSnapshotHolder()

        super.init()
        dispatchQueue.async {
            self.deferredInit()
        }
    }

    private var interceptServerDataCallback: ((String, Any) -> Any)?

    private func deferredInit() {
        print("DEFERRED INIT")
        // TODO: cleanup on dealloc
        config.contextProvider.listenForAuthTokenChanges { [weak self] token in
            self?.connection.refreshAuthToken(token)
        }
        config.contextProvider.listenForAppCheckTokenChanges { [weak self] token in
            self?.connection.refreshAppCheckToken(token)
        }

        // Open connection now so that by the time we are connected the deferred
        // init has run This relies on the fact that all callbacks run on repos
        // queue
        connection.delegate = self
        connection.open()

        dataUpdateCount = 0
        rangeMergeUpdateCount = 0
        interceptServerDataCallback = nil
        if config.persistenceEnabled {
            let repoHashString = "\(repoInfo.host)/\(repoInfo.namespace)"
            let persistencePrefix = "\(config.sessionIdentifier)/\(repoHashString)"
            let cachePolicy = FLRUCachePolicy(maxSize: config.persistenceCacheSizeBytes)
            let engine: FStorageEngine
            if let forceStorageEngine = config.forceStorageEngine {
                engine = forceStorageEngine
            } else {
                let levelDBEngine = FLevelDBStorageEngine(path: persistencePrefix)
                // We need the repo info to run the legacy migration. Future
                // migrations will be managed by the database itself Remove this
                // once we are confident that no-one is using legacy migration
                // anymore...
//                levelDBEngine.runLegacyMigration(repoInfo)
                engine = levelDBEngine
            }
            self.persistenceManager = FPersistenceManager(storageEngine: engine, cachePolicy: cachePolicy)
        } else {
            self.persistenceManager = nil
        }
        initTransactions()

        let infoListenProvider = FListenProvider(startListening: { [weak self] query, tagId, hash, onComplete in
            guard let self = self else { return [] }
            var infoEvents: [FEvent] = []
            let node = self.infoData.getNode(query.path)
            // This is possibly a hack, but we have different semantics for .info
            // endpoints. We don't raise null events on initial data...
            if !node.isEmpty {
                infoEvents = self.infoSyncTree.applyServerOverwriteAtPath(query.path, newData: node)
                self.eventRaiser.raiseCallback {
                    _ = onComplete(kFWPResponseForActionStatusOk)
                }
            }
            return infoEvents
        }, stopListening: { _, _ in })

        self.infoSyncTree = FSyncTree(listenProvider: infoListenProvider)

        let serverListenProvider = FListenProvider(startListening: { [weak self] query, tagId, hash, onComplete in
            self?.connection.listen(query, tagId: tagId, hash: hash, onComplete: { [weak self] status in
                let events = onComplete(status)
                self?.eventRaiser.raiseEvents(events)
            })
            // No synchronous events for network-backed sync trees
            return []
        }, stopListening: { [weak self] query, tag in
            self?.connection.unlisten(query, tagId: tag)
        })
        self.serverSyncTree = FSyncTree(persistenceManager: self.persistenceManager, listenProvider: serverListenProvider)

        restoreWrites()

        updateInfo(kDotInfoConnected, withValue: false)

        setupNotifications()
    }

    private func restoreWrites() {
        let writes = self.persistenceManager?.userWrites ?? []
        let serverValues = FServerValues.generateServerValues(self.serverClock)
        var lastWriteId = Int.min
        for write in writes {
            let writeId = write.writeId
            let callback: (String, String?) -> Void = { status, errorReason in
                self.warnIfWriteFailedAtPath(write.path, status: status, message: "Persisted write")
                self.ackWrite(writeId, rerunTransactionsAtPath: write.path, status: status)
            }
            if lastWriteId >= writeId {
                fatalError("Restored writes were not in order!")
            }
            lastWriteId = writeId
            self.writeIdCounter = writeId + 1
            if let overwrite = write.overwrite {
                FFLog("I-RDB038001", "Restoring overwrite with id \(writeId)")
                connection.putData(overwrite.val(forExport: true),
                                   forPath: write.path.description,
                                   withHash: nil,
                                   withCallback: callback)
                let resolved = FServerValues.resolveDeferredValueSnapshot(overwrite, withSyncTree: serverSyncTree, atPath: write.path, serverValues: serverValues)
                _ = serverSyncTree.applyUserOverwriteAtPath(write.path,
                                                            newData: resolved,
                                                            writeId: writeId,
                                                            isVisible: true)

            } else if let merge = write.merge {
                FFLog("I-RDB038002", "Restoring merge with id \(writeId)")
                self.connection.mergeData(merge,
                                          forPath: write.path.description,
                                          withCallback: callback)
                let resolved = FServerValues.resolveDeferredValueCompoundWrite(merge,
                                                                               withSyncTree: serverSyncTree,
                                                                               atPath: write.path,
                                                                               serverValues: serverValues)
                _ = serverSyncTree.applyUserMergeAtPath(write.path,
                                                        changedChildren: resolved,
                                                        writeId: writeId)
            }
        }
    }

    var name: String { repoInfo.namespace }
    public override var description: String { repoInfo.description }
    @objc public func interrupt() {
        connection.interruptForReason(kFInterruptReasonRepoInterrupt)
    }
    @objc public func resume() {
        connection.resumeForReason(kFInterruptReasonRepoInterrupt)
    }

    // NOTE: Typically if you're calling this, you should be in an @autoreleasepool
    // block to make sure that ARC kicks in and cleans up things no longer
    // referenced (i.e. pendingPutsDB).
    @objc public func dispose() {
        connection.interruptForReason(kFInterruptReasonRepoInterrupt)

        // We need to nil out any references to LevelDB, to make sure the
        // LevelDB exclusive locks are released.
        persistenceManager?.close()
    }

    private func nextWriteId() -> Int {
        defer { writeIdCounter += 1 }
        return writeIdCounter
    }

    @objc public var serverTime: TimeInterval { serverClock.currentTime }

    @objc public func set(_ path: FPath, withNode node: FNode, withCallback onComplete: ((Error?, DatabaseReference) -> Void)?) {
        let value = node.val(forExport: true)
        FFLog("I-RDB038003", "Setting: \(path) with \(value) pri: \(node.getPriority().val())")

        // TODO: Optimize this behavior to either (a) store flag to skip resolving
        // where possible and / or (b) store unresolved paths on JSON parse
        let serverValues = FServerValues.generateServerValues(serverClock)
        let existing = serverSyncTree.calcCompleteEventCacheAtPath(path, excludeWriteIds: [])
        let newNode = FServerValues.resolveDeferredValueSnapshot(node,
                                                                 withExisting: existing,
                                                                 serverValues: serverValues)
        let writeId = nextWriteId()
        persistenceManager?.saveUserOverwrite(node, atPath: path, writeId: writeId)
        let events = serverSyncTree.applyUserOverwriteAtPath(path, newData: newNode, writeId: writeId, isVisible: true)
        eventRaiser.raiseEvents(events)
        connection.putData(value, forPath: path.description, withHash: nil) { [weak self] status, errorReason in
            guard let self = self else { return }
            self.warnIfWriteFailedAtPath(path, status: status, message: "setValue: or removeValue:")
            self.ackWrite(writeId, rerunTransactionsAtPath: path, status: status)
            if let onComplete = onComplete {
                self.callOnComplete(onComplete, withStatus: status, errorReason: errorReason, andPath: path)
            }
        }
        let affectedPath = abortTransactionsAtPath(path, error: kFTransactionSet)
        rerunTransactionsForPath(affectedPath)
    }

    @objc public func update(_ path: FPath, withNodes nodes: FCompoundWrite, withCallback callback: ((Error?, DatabaseReference) -> Void)?) {
        let values = nodes.valForExport(true)
        FFLog("I-RDB038004", "Updating: \(path) with \(values)")
        let serverValues = FServerValues.generateServerValues(serverClock)
        let resolved = FServerValues.resolveDeferredValueCompoundWrite(nodes,
                                                                       withSyncTree: serverSyncTree,
                                                                       atPath: path,
                                                                       serverValues: serverValues)
        if !resolved.isEmpty {
            let writeId = nextWriteId()
            persistenceManager?.saveUserMerge(nodes, atPath: path, writeId: writeId)
            let events = serverSyncTree.applyUserMergeAtPath(path, changedChildren: resolved, writeId: writeId)
            eventRaiser.raiseEvents(events)
            connection.mergeData(values, forPath: path.description) { [weak self] status, errorReason in
                guard let self = self else { return }
                self.warnIfWriteFailedAtPath(path, status: status, message: "updateChildValues:")
                self.ackWrite(writeId, rerunTransactionsAtPath: path, status: status)
                if let callback = callback {
                    self.callOnComplete(callback, withStatus: status, errorReason: errorReason, andPath: path)
                }
            }
            nodes.enumerateWrites { childPath, node, stop in
                let pathFromRoot = path.child(childPath)
                FFLog("I-RDB038005", "Cancelling transactions at path: \(pathFromRoot)")
                let affectedPath = self.abortTransactionsAtPath(pathFromRoot, error: kFTransactionSet)
                self.rerunTransactionsForPath(affectedPath)
            }
        } else {
            FFLog("I-RDB038006", "update called with empty data. Doing nothing")
            // Do nothing, just call the callback
            if let callback = callback {
                callOnComplete(callback, withStatus: "ok", errorReason: nil, andPath: path)
            }
        }
    }

    internal func onDisconnectCancel(_ path: FPath, withCallback callback: ((Error?, DatabaseReference) -> Void)?) {
        connection.onDisconnectCancelPath(path) { [weak self] status, errorReason in
            let success = status == kFWPResponseForActionStatusOk
            if success {
                _ = self?.onDisconnect.forgetPath(path)
            } else {
                FFLog("I-RDB038007",
                      "cancelDisconnectOperations: at \(path) failed: \(status)")
            }
            if let callback = callback {
                self?.callOnComplete(callback, withStatus: status, errorReason: errorReason, andPath: path)
            }
        }
    }

    internal func onDisconnectSet(_ path: FPath, withNode node: FNode, withCallback callback: ((Error?, DatabaseReference) -> Void)?) {
        connection.onDisconnectPutData(node.val(forExport: true), forPath: path) { [weak self] status, errorReason in
            let success = status == kFWPResponseForActionStatusOk
            if success {
                self?.onDisconnect.rememberData(node, onPath: path)
            } else {
                FFWarn("I-RDB038008",
                       "onDisconnectSetValue: or onDisconnectRemoveValue: at \(path) failed: \(status)")
            }
            if let callback = callback {
                self?.callOnComplete(callback, withStatus: status, errorReason: errorReason, andPath: path)
            }
        }
    }

    internal func onDisconnectUpdate(_ path: FPath, withNodes nodes: FCompoundWrite, withCallback callback: ((Error?, DatabaseReference) -> Void)?) {
        guard !nodes.isEmpty else {
            // Do nothing, just call the callback
            if let callback = callback {
                callOnComplete(callback, withStatus: "ok", errorReason: nil, andPath: path)
            }
            return
        }
        let values = nodes.valForExport(true)
        connection.onDisconnectMergeData(values, forPath: path) { [weak self] status, errorReason in
            let success = status == kFWPResponseForActionStatusOk
            if success {
                nodes.enumerateWrites { relativePath, nodeUnresolved, stop in
                    let childPath = path.child(relativePath)
                    self?.onDisconnect.rememberData(nodeUnresolved, onPath: childPath)
                }
            } else {
                FFWarn("I-RDB038009",
                       "onDisconnectUpdateChildValues: at \(path) failed \(status)")
            }
            if let callback = callback {
                self?.callOnComplete(callback, withStatus: status, errorReason: errorReason, andPath: path)
            }
        }
    }

    internal func purgeOutstandingWrites() {
        FFLog("I-RDB038010", "Purging outstanding writes")
        let events = serverSyncTree.removeAllWrites()
        eventRaiser.raiseEvents(events)
        // Abort any transactions
        _ = abortTransactionsAtPath(.empty, error: kFErrorWriteCanceled)
        // Remove outstanding writes from connection
        connection.purgeOutstandingWrites()
    }

    internal func getData(_ query: DatabaseQuery, withCompletionBlock block: @escaping (Error?, DataSnapshot?) -> Void) {
        let querySpec = query.querySpec
        if let node = serverSyncTree.getServerValue(querySpec) {
            eventRaiser.raiseCallback {
                block(nil, DataSnapshot(ref: query.ref, indexedNode: FIndexedNode(node: node, index: querySpec.index)))
            }
            return
        }
        // XXX TODO: LOOK AT LATEST MASTER ON THE FB REPO. THIS HAS BEEN CHANGED TO USE SOME TAGGING STUFF
        persistenceManager?.setQueryActive(querySpec)
        connection.getDataAtPath(querySpec.path.description,
                                 withParams: querySpec.params.wireProtocolParams) { [weak self] status, data, errorReason in
            guard let self = self else { return }
            if status != kFWPResponseForActionStatusOk {
                FFLog("I-RDB038024",
                      "getValue for query \(querySpec.path) falling back to disk cache")

                if let node = self.serverSyncTree.persistenceServerCache(querySpec) {
                    self.eventRaiser.raiseCallback {
                        block(nil, DataSnapshot(ref: query.ref, indexedNode: node))
                    }
                } else {
                    let errorDict: [String: Any] = [
                        NSLocalizedFailureReasonErrorKey: errorReason ?? "",
                        NSLocalizedDescriptionKey: "Unable to get latest value for query \(querySpec), client offline with no active listeners and no matching disk cache entries"
                    ]
                    let error = NSError(domain: kFirebaseCoreErrorDomain, code: 1, userInfo: errorDict)
                    self.eventRaiser.raiseCallback {
                        block(error, nil)
                    }
                    self.persistenceManager?.setQueryInactive(querySpec)
                    return
                }

            } else {
                // status OK
                let node = FSnapshotUtilitiesSwift.nodeFrom(data)
                let events = self.serverSyncTree.applyServerOverwriteAtPath(querySpec.path, newData: node)
                self.eventRaiser.raiseEvents(events)
                self.eventRaiser.raiseCallback {
                    block(nil, DataSnapshot(ref: query.ref, indexedNode: FIndexedNode(node: node, index: querySpec.index)))
                }
            }
            self.persistenceManager?.setQueryInactive(querySpec)


        }
    }

    internal func addEventRegistration(_ eventRegistration: FEventRegistration, forQuery query: FQuerySpec) {
        let events: [FEvent]
        if query.path.getFront() == kDotInfoPrefix {
            events = self.infoSyncTree.addEventRegistration(eventRegistration,
                                                            forQuery:query)
        } else {
            events = self.serverSyncTree.addEventRegistration(eventRegistration,
                                                              forQuery:query)
        }
        self.eventRaiser.raiseEvents(events)
    }

    internal func removeEventRegistration(_ eventRegistration: FEventRegistration, forQuery query: FQuerySpec) {
        // These are guaranteed not to raise events, since we're not passing in a
        // cancelError. However we can future-proof a little bit by handling the
        // return values anyways.
        FFLog("I-RDB038011", "Removing event registration with hande: \(eventRegistration.handle)")
        let events: [FEvent]
        if query.path.getFront() == kDotInfoPrefix {
            events = infoSyncTree.removeEventRegistration(eventRegistration, forQuery: query, cancelError: nil)
        } else {
            events = serverSyncTree.removeEventRegistration(eventRegistration, forQuery: query, cancelError: nil)
        }
        eventRaiser.raiseEvents(events)
    }

    internal func keepQuery(_ query: FQuerySpec, synced: Bool) {
        assert(query.path.getFront() != kDotInfoPrefix,
                 "Can't keep .info tree synced!")
        serverSyncTree.keepQuery(query, synced: synced)
    }

    private func updateInfo(_ pathString: String, withValue value: Any) {
        // hack to make serverTimeOffset available in a threadsafe way. Property is
        // marked as atomic
        if pathString == kDotInfoServerTimeOffset {
            let offset: TimeInterval = (value as? Double ?? 0) / 1000
            self.serverClock = FOffsetClock(clock: FSystemClock.clock, offset: offset)
        }
        let path = FPath(with: "\(kDotInfoPrefix)/\(pathString)")
        let newNode = FSnapshotUtilitiesSwift.nodeFrom(value)
        infoData.updateSnapshot(path, withNewSnapshot: newNode)
        let events = infoSyncTree.applyServerOverwriteAtPath(path, newData: newNode)
        eventRaiser.raiseEvents(events)
    }

    private func callOnComplete(_ onComplete: @escaping (Error?, DatabaseReference) -> Void, withStatus status: String, errorReason: String?, andPath path: FPath) {
        let ref = DatabaseReference(repo: self, path: path)
        let statusOk = status == kFWPResponseForActionStatusOk
        var error: Error? = nil
        if !statusOk {
            error = FUtilitiesSwift.error(for: status, reason: errorReason)
        }
        eventRaiser.raiseCallback {
            onComplete(error, ref)
        }
    }

    private func ackWrite(_ writeId: Int, rerunTransactionsAtPath path: FPath, status: String) {
        if status == kFErrorWriteCanceled {
            // This write was already removed, we just need to ignore it...
        } else {
            let success = status == kFWPResponseForActionStatusOk
            let clearEvents = serverSyncTree.ackUserWriteWithWriteId(writeId, revert: !success, persist: true, clock: serverClock)
            if !clearEvents.isEmpty {
                _ = rerunTransactionsForPath(path)
            }
            eventRaiser.raiseEvents(clearEvents)
        }
    }

    private func warnIfWriteFailedAtPath(_ path: FPath, status: String, message: String) {
        if status != kFWPResponseForActionStatusOk && status != kFErrorWriteCanceled {
            FFWarn("I-RDB038012", "\(message) at \(path) failed: \(status)")
        }
    }

    // MARK: -
    // MARK: FPersistentConnectionDelegate methods

    public func onDataUpdate(_ fpconnection: FPersistentConnection, forPath pathString: String, message: Any, isMerge: Bool, tagId: Int?) {
        FFLog("I-RDB038013", "onDataUpdateForPath: \(pathString) withMessage: \(message)")

        // For testing.
        self.dataUpdateCount += 1

        let path = FPath(with: pathString)
        let data = interceptServerDataCallback?(pathString, message) ?? message
        let events: [FEvent]
        if let tagId = tagId {
            if isMerge {
                let taggedChildren = FCompoundWrite.compoundWrite(valueDictionary: data as? [String: Any] ?? [:])
                events = serverSyncTree.applyTaggedQueryMergeAtPath(path, changedChildren: taggedChildren, tagId: tagId)
            } else {
                let taggedSnap = FSnapshotUtilitiesSwift.nodeFrom(data)
                events = serverSyncTree.applyTaggedQueryOverwriteAtPath(path, newData: taggedSnap, tagId: tagId)
            }
        } else {
            if isMerge {
                let changedChildren = FCompoundWrite.compoundWrite(valueDictionary: data as? [String: Any] ?? [:])
                events = serverSyncTree.applyServerMergeAtPath(path, changedChildren: changedChildren)
            } else {
                let snap = FSnapshotUtilitiesSwift.nodeFrom(data)
                events = serverSyncTree.applyServerOverwriteAtPath(path, newData: snap)
            }
        }
        if !events.isEmpty {
            // Since we have a listener outstanding for each transaction, receiving
            // any events is a proxy for some change having occurred.
            rerunTransactionsForPath(path)
        }
        eventRaiser.raiseEvents(events)

    }

    public func onRangeMerge(_ ranges: [FRangeMerge], forPath pathString: String, tagId: Int?) {
        FFLog("I-RDB038014", "onRangeMerge: \(pathString) => \(ranges)")

        // For testing
        self.rangeMergeUpdateCount += 1

        let path = FPath(with: pathString)
        let events: [FEvent]
        if let tagId = tagId {
            events = serverSyncTree.applyTaggedServerRangeMergeAtPath(path, updates: ranges, tagId: tagId)
        } else {
            events = serverSyncTree.applyServerRangeMergeAtPath(path, updates: ranges)
        }
        if !events.isEmpty {
            // Since we have a listener outstanding for each transaction, receiving
            // any events is a proxy for some change having occurred.
            rerunTransactionsForPath(path)
        }
        eventRaiser.raiseEvents(events)
    }

    public func onConnect(_ fpconnection: FPersistentConnection) {
        updateInfo(kDotInfoConnected, withValue: true)
    }

    public func onDisconnect(_ fpconnection: FPersistentConnection) {
        updateInfo(kDotInfoConnected, withValue: false)
        runOnDisconnectEvents()
    }

    public func onServerInfoUpdate(_ fpconnection: FPersistentConnection, updates: [String : Any]) {
        for (key, val) in updates {
            updateInfo(key, withValue: val)
        }
    }

    // MARK: -
    private func setupNotifications() {
#if canImport(UIKit)
        FFLog("I-RDB038015", "Registering for background notification.")
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
#else
        FFLog("I-RDB038016",
              "Skipped registering for background notification.")
#endif
    }

    @objc public func didEnterBackground() {
        guard config.persistenceEnabled else {
            return
        }

// Targetted compilation is ONLY for testing. UIKit is weak-linked in actual
// release build.
#if canImport(UIKit)
        // The idea is to wait until any outstanding sets get written to disk. Since
        // the sets might still be in our dispatch queue, we wait for the dispatch
        // queue to catch up and for persistence to catch up. This may be
        // undesirable though.  The dispatch queue might just be processing a bunch
        // of incoming data or something.  We might want to keep track of whether
        // there are any unpersisted sets or something.
        FFLog("I-RDB038017",
              "Entering background.  Starting background task to finish work.")

        var bgTask: UIBackgroundTaskIdentifier?
        bgTask = UIApplication.shared.beginBackgroundTask {
            if let bgTask = bgTask {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }

        let start = Date()
        dispatchQueue.async {
            let finishTime = start.timeIntervalSinceNow * -1
            FFLog("I-RDB038018", "Background task completed.  Queue time: \(finishTime)")
            if let bgTask = bgTask {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }
    #endif
    }

    // MARK: -
    // MARK: Internal methods

    /**
     * Applies all the changes stored up in the onDisconnect tree
     */
    private func runOnDisconnectEvents() {
        FFLog("I-RDB038019", "Running onDisconnectEvents")
        let serverValues = FServerValues.generateServerValues(serverClock)
        var events: [FEvent] = []

        onDisconnect.forEachTreeAtPath(.empty) { path, node in
            let existing = serverSyncTree.calcCompleteEventCacheAtPath(path,
                             excludeWriteIds: [])
            let resolved = FServerValues.resolveDeferredValueSnapshot(node,
                                withExisting:existing,
                                serverValues:serverValues)
            events.append(contentsOf: serverSyncTree.applyServerOverwriteAtPath(path, newData: resolved))
            let affectedPath = abortTransactionsAtPath(path, error: kFTransactionSet)
            rerunTransactionsForPath(affectedPath)
        }

        self.onDisconnect = FSparseSnapshotTree()
        eventRaiser.raiseEvents(events)
    }

    @objc public func dumpListens() -> [FQuerySpec : FOutstandingQuery] {
        connection.dumpListens()
    }

    // MARK: -
    // MARK: Transactions

    /**
     * Setup the transaction data structures
     */
    func initTransactions() {
        self.transactionQueueTree = FTree()
        self.hijackHash = false
        self.loggedTransactionPersistenceWarning = false
    }

    /**
     * Creates a new transaction, add its to the transactions we're tracking, and
     * sends it to the server if possible
     */
    internal func startTransactionOnPath(_ path: FPath, update: @escaping (MutableData) -> TransactionResult, onComplete: ((Error?, Bool, DataSnapshot?) -> Void)?, withLocalEvents applyLocally: Bool) {
        if config.persistenceEnabled && !loggedTransactionPersistenceWarning {
            loggedTransactionPersistenceWarning = true
            FFInfo("I-RDB038020", """
runTransactionBlock: usage detected while persistence is \n
enabled. Please be aware that transactions \n
*will not* be persisted across app restarts. \n
See \n
https://www.firebase.com/docs/ios/guide/
offline-capabilities.html#section-handling-transactions-
offline for more details.
""")
        }
        let watchRef = DatabaseReference(repo: self, path: path)
        // make sure we're listening on this node
        // Note: we can't do this asynchronously. To preserve event ordering, it has
        // to be done in this block. This is ok, this block is guaranteed to be our
        // own event loop
        let handle = FUtilitiesSwift.LUIDGenerator()
        let registration = FValueEventRegistration(repo: self, handle: handle, callback: nil, cancelCallback: nil)
        watchRef.repo.addEventRegistration(registration, forQuery: watchRef.querySpec)
        let unwatcher: () -> Void = { watchRef.removeObserverWithHandle(handle) }
        // Save all the data that represents this transaction
        let transaction = FTupleTransaction(
            path: path,
            update: update,
            onComplete: onComplete,
            status: FTransactionStatus.initializing,
            order: FUtilitiesSwift.LUIDGenerator(),
            applyLocally: applyLocally,
            retryCount: 0,
            unwatcher: unwatcher,
            currentWriteId: nil,
            currentInputSnapshot: nil,
            currentOutputSnapshotRaw: nil,
            currentOutputSnapshotResolved: nil
        )
        // Run transaction initially
        let currentState = latestStateAtPath(path, excludeWriteIds: [])
        transaction.currentInputSnapshot = currentState
        let mutableCurrent = MutableData(node: currentState)
        let result = transaction.update(mutableCurrent)
        if !result.isSuccess {
            // Abort the transaction
            transaction.unwatcher()
            transaction.currentOutputSnapshotRaw = nil
            transaction.currentOutputSnapshotResolved = nil
            if let onComplete = transaction.onComplete {
                let ref = DatabaseReference(repo: self, path: transaction.path)
                let indexedNode = FIndexedNode(node: currentState) // XXX TODO: Assume this is the same as transaction.currentInputSnapshot, but not 100000% convinced
                let snap = DataSnapshot(ref: ref, indexedNode: indexedNode)
                eventRaiser.raiseCallback {
                    onComplete(nil, false, snap)
                }
            }
        } else {
            // Note: different from js. We don't need to validate, FIRMutableData
            // does validation. We also don't have to worry about priorities. Just
            // mark as run and add to queue.
            transaction.status = .run
            let queueNode = transactionQueueTree.subTree(transaction.path)
            var nodeQueue = queueNode.getValue() ?? []
            nodeQueue.append(transaction)
            queueNode.setValue(nodeQueue)

            // Update visibleData and raise events
            // Note: We intentionally raise events after updating all of our
            // transaction state, since the user could start new transactions from
            // the event callbacks
            let serverValues = FServerValues.generateServerValues(serverClock)
            let newValUnresolved = result.update!.nodeValue // XXX TODO
            let newVal = FServerValues.resolveDeferredValueSnapshot(newValUnresolved, withExisting: currentState, serverValues: serverValues)
            transaction.currentOutputSnapshotRaw = newValUnresolved
            transaction.currentOutputSnapshotResolved = newVal
            let currentWriteId = nextWriteId()
            transaction.currentWriteId = currentWriteId

            let events = serverSyncTree.applyUserOverwriteAtPath(path, newData: newVal, writeId: currentWriteId, isVisible: transaction.applyLocally)
            eventRaiser.raiseEvents(events)
            sendAllReadyTransactions()
        }
    }

    /**
     * Sends any already-run transactions that aren't waiting for outstanding
     * transactions to complete.
     *
     * Externally, call the version with no arguments.
     * Internally, calls itself recursively with a particular transactionQueueTree
     * node to recurse through the tree
     */
    private func sendAllReadyTransactions() {
        let node = self.transactionQueueTree

        pruneCompletedTransactionsBelowNode(node)
        sendReadyTransactionsForTree(node)
    }

    private func sendReadyTransactionsForTree(_ node: FTree<[FTupleTransaction]>) {
        if node.getValue() != nil {
            let queue = buildTransactionQueueAtNode(node)
            assert(!queue.isEmpty, "Sending zero length transaction queue")
            let notRunIndex = queue.firstIndex { transaction in
                transaction.status != .run
            }
            if notRunIndex == nil {
                sendTransactionQueue(queue, atPath: node.path)
            }
        } else if node.hasChildren {
            node.forEachChild { child in
                sendReadyTransactionsForTree(child)
            }
        }
    }

    /**
     * Given a list of run transactions, send them to the server and then handle the
     * result (success or failure).
     */
    private func sendTransactionQueue(_ queue: [FTupleTransaction], atPath path: FPath) {
        // Mark transactions as sent and bump the retry count
        let writeIdsToExclude: [Int] = queue.compactMap(\.currentWriteId)
        let latestState = latestStateAtPath(path, excludeWriteIds: writeIdsToExclude)
        var snapToSend = latestState
        var latestHash = latestState.dataHash()
        for transaction in queue {
            assert(transaction.status == .run, "[FRepo sendTransactionQueue:] items in queue should all be run.")
            FFLog("I-RDB038021", "Transaction at \(transaction.path) set to SENT")
            transaction.status = .sent
            transaction.retryCount += 1
            let relativePath = FPath.relativePath(from: path, to: transaction.path)
            // If we've gotten to this point, the output snapshot must be defined.
            snapToSend = snapToSend.updateChild(relativePath, withNewChild: transaction.currentOutputSnapshotRaw!)
            let dataToSend = snapToSend.val(forExport: true)
            let pathToSend = path.description
            latestHash = hijackHash ? "badhash" : latestHash

            // Send the put
            connection.putData(dataToSend, forPath: pathToSend, withHash: latestHash) { [weak self] status, errorReason in
                guard let self = self else { return }
                FFLog("I-RDB038022", "Transaction put response: \(pathToSend) : \(status)")

                var events: [FEvent] = []
                if status == kFWPResponseForActionStatusOk {
                    // Queue up the callbacks and fire them after cleaning up all of
                    // our transaction state, since the callback could trigger more
                    // transactions or sets.
                    var callbacks: [() -> Void] = []
                    for transaction in queue {
                        transaction.status = .completed
                        events.append(contentsOf: self.serverSyncTree.ackUserWriteWithWriteId(transaction.currentWriteId!, revert: false, persist: false, clock: self.serverClock))
                        if let onComplete = transaction.onComplete  {
                            // We never unset the output snapshot, and given that this
                            // transaction is complete, it should be set
                            let node = transaction.currentOutputSnapshotResolved!
                            let indexedNode = FIndexedNode.indexedNode(node: node)
                            let ref = DatabaseReference(repo: self, path: transaction.path)
                            let snapshot = DataSnapshot(ref: ref, indexedNode: indexedNode)
                            callbacks.append {
                                onComplete(nil, true, snapshot)
                            }
                        }
                        transaction.unwatcher()
                    }

                    // Now remove the completed transactions.
                    self.pruneCompletedTransactionsBelowNode(self.transactionQueueTree.subTree(path))
                    // There may be pending transactions that we can now send.
                    self.sendAllReadyTransactions()

                    // Finally, trigger onComplete callbacks
                    self.eventRaiser.raiseCallbacks(callbacks)
                } else {
                    // transactions are no longer sent. Update their status
                    // appropriately.
                    if status == kFWPResponseForActionStatusDataStale {
                        for transaction in queue {
                            if transaction.status == .sentNeedsAbort {
                                transaction.status = .needsAbort
                            } else {
                                transaction.status = .run
                            }
                        }
                    } else {
                        FFWarn("I-RDB038023",
                               "runTransactionBlock: at \(path) failed: \(status)")
                        for transaction in queue {
                            transaction.status = .needsAbort
                            transaction.setAbortStatus(abortStatus: status, reason: errorReason)
                        }

                    }
                }
                _ = self.rerunTransactionsForPath(path)
                self.eventRaiser.raiseEvents(events)
            }
        }
    }

    /**
     * Finds all transactions dependent on the data at changed Path and reruns them.
     *
     * Should be called any time cached data changes.
     *
     * Return the highest path that was affected by rerunning transactions. This is
     * the path at which events need to be raised for.
     */
    private func rerunTransactionsForPath(_ changedPath: FPath) -> FPath {
        // For the common case that there are no transactions going on, skip all
        // this!
        if transactionQueueTree.isEmpty {
            return changedPath
        } else {
            let rootMostTransactionNode = getAncestorTransactionNodeForPath(changedPath)
            let path = rootMostTransactionNode.path
            let queue = buildTransactionQueueAtNode(rootMostTransactionNode)
            rerunTransactionQueue(queue, atPath: path)
            return path
        }
    }

    /**
     * Does all the work of rerunning transactions (as well as cleans up aborted
     * transactions and whatnot).
     */
    private func rerunTransactionQueue(_ queue: [FTupleTransaction], atPath path: FPath) {
        guard !queue.isEmpty else { return }

        // Queue up the callbacks and fire them after cleaning up all of our
        // transaction state, since the callback could trigger more transactions or
        // sets.
        var events: [FEvent] = []
        var callbacks: [() -> Void] = []

        // Ignore, by default, all of the sets in this queue, since we're re-running
        // all of them. However, we want to include the results of new sets
        // triggered as part of this re-run, so we don't want to ignore a range,
        // just these specific sets.
        var writeIdsToExclude = queue.compactMap(\.currentWriteId)

        for transaction in queue {
            let relativePath = FPath.relativePath(from: path, to: transaction.path)
            var abortTransaction = false

            switch transaction.status {
            case .needsAbort:
                abortTransaction = true
                if transaction.abortStatus != kFErrorWriteCanceled {
                    let ackEvents = serverSyncTree.ackUserWriteWithWriteId(transaction.currentWriteId ?? 0, revert: true, persist: false, clock: serverClock)
                    events.append(contentsOf: ackEvents)
                }
            case .run:
                if transaction.retryCount >= kFTransactionMaxRetries {
                    abortTransaction = true
                    transaction.setAbortStatus(abortStatus: kFTransactionTooManyRetries, reason: nil)
                    let ackEvents = serverSyncTree.ackUserWriteWithWriteId(transaction.currentWriteId ?? 0, revert: true, persist: false, clock: serverClock)
                    events.append(contentsOf: ackEvents)
                } else {
                    // This code reruns a transaction
                    let currentNode = latestStateAtPath(transaction.path, excludeWriteIds: writeIdsToExclude)
                    transaction.currentInputSnapshot = currentNode
                    let mutableCurrent = MutableData(node: currentNode)
                    let result = transaction.update(mutableCurrent)
                    if result.isSuccess {
                        let oldWriteId = transaction.currentWriteId!
                        let serverValues = FServerValues.generateServerValues(serverClock)
                        let newVal = result.update!.nodeValue
                        let newValResolved = FServerValues.resolveDeferredValueSnapshot(newVal, withExisting: transaction.currentInputSnapshot, serverValues: serverValues)
                        transaction.currentOutputSnapshotRaw = newVal
                        transaction.currentOutputSnapshotResolved = newValResolved

                        transaction.currentWriteId = self.nextWriteId()
                        // Mutates writeIdsToExclude in place
                        writeIdsToExclude.removeAll(where: { $0 == oldWriteId })
                        let overwriteEvents = serverSyncTree.applyUserOverwriteAtPath(transaction.path, newData: transaction.currentOutputSnapshotResolved!, writeId: transaction.currentWriteId!, isVisible: transaction.applyLocally)
                        events.append(contentsOf: overwriteEvents)
                        let ackEvents = serverSyncTree.ackUserWriteWithWriteId(oldWriteId, revert: true, persist: false, clock: serverClock)
                        events.append(contentsOf: ackEvents)
                    } else {
                        abortTransaction = true
                        // The user aborted the transaction. JS treats ths as a
                        // "nodata" abort, but it's not an error, so we don't send
                        // them an error.
                        transaction.setAbortStatus(abortStatus: nil, reason: nil)
                        let ackEvents = serverSyncTree.ackUserWriteWithWriteId(transaction.currentWriteId ?? 0, revert: true, persist: false, clock: serverClock)
                        events.append(contentsOf: ackEvents)
                    }
                }
            default:
                ()
            }

            eventRaiser.raiseEvents(events)
            events = []
            if abortTransaction {
                // Abort
                transaction.status = .completed
                transaction.unwatcher()
                if let onComplete = transaction.onComplete {
                    let ref = DatabaseReference(repo: self, path: transaction.path)
                    let lastInput = FIndexedNode(node: transaction.currentInputSnapshot!) // XXX TODO
                    let snap = DataSnapshot(ref: ref, indexedNode: lastInput)
                    callbacks.append {
                        // Unlike JS, no need to check for "nodata" because ObjC has
                        // abortError = nil
                        let err = transaction.abortError
                        onComplete(err, false, snap)
                    }
                }
            }
        }

        // Note: unlike current js client, we don't need to preserve priority. Users
        // can set priority via FIRMutableData

        // Clean up completed transactions.
        pruneCompletedTransactionsBelowNode(transactionQueueTree)

        // Now fire callbacks, now that we're in a good, known state.
        eventRaiser.raiseCallbacks(callbacks)

        // Try to send the transaction result to the server
        sendAllReadyTransactions()
    }

    

    private func getAncestorTransactionNodeForPath(_ path: FPath) -> FTree<[FTupleTransaction]> {
        var path = path
        var transactionNode = transactionQueueTree
        while let front = path.getFront(), transactionNode.getValue() == nil {
            transactionNode = transactionNode.subTree(FPath(with: front))
            path = path.popFront()
        }
        return transactionNode
    }

    private func buildTransactionQueueAtNode(_ node: FTree<[FTupleTransaction]>) -> [FTupleTransaction] {
        var queue: [FTupleTransaction] = []
        aggregateTransactionQueuesForNode(node, andQueue: &queue)
        queue.sort { $0.order < $1.order }
        return queue
    }

    private func aggregateTransactionQueuesForNode(_ node: FTree<[FTupleTransaction]>, andQueue queue: inout [FTupleTransaction]) {
        if let nodeValue = node.getValue() {
            queue.append(contentsOf: nodeValue)
        }
        node.forEachChild { child in
            aggregateTransactionQueuesForNode(child, andQueue: &queue)
        }
    }

    /**
     * Remove COMPLETED transactions at or below this node in the
     * transactionQueueTree
     */
    private func pruneCompletedTransactionsBelowNode(_ node: FTree<[FTupleTransaction]>) {
        if let queue = node.getValue() {
            let filtered = queue.filter {
                $0.status != .completed
            }
            if filtered.isEmpty {
                node.setValue(nil)
            } else {
                node.setValue(filtered)
            }
        }
        node.forEachChild { child in
            pruneCompletedTransactionsBelowNode(child)
        }
    }

    /**
     *  Aborts all transactions on ancestors or descendants of the specified path.
     * Called when doing a setValue: or updateChildValues: since we consider them
     * incompatible with transactions
     *
     *  @param path path for which we want to abort related transactions.
     */
    private func abortTransactionsAtPath(_ path: FPath, error: String) -> FPath {
        // For the common case that there are no transactions going on, skip all
        // this!
        if transactionQueueTree.isEmpty {
            return path
        }
        let affectedPath = getAncestorTransactionNodeForPath(path).path
        let transactionNode = transactionQueueTree.subTree(path)
        transactionNode.forEachAncestor { ancestor in
            abortTransactionsAtNode(ancestor, error: error)
            return false
        }
        abortTransactionsAtNode(transactionNode, error: error)
        transactionNode.forEachDescendant { child in
            abortTransactionsAtNode(child, error: error)
        }
        return affectedPath
    }

    /**
     * Abort transactions stored in this transactions queue node.
     *
     * @param node Node to abort transactions for.
     */
    private func abortTransactionsAtNode(_ node: FTree<[FTupleTransaction]>, error: String) {
        guard var queue = node.getValue() else {
            return
        }
        // Queue up the callbacks and fire them after cleaning up all of our
        // transaction state, since can be immediately aborted and removed.
        var callbacks: [() -> Void] = []

        // Go through queue. Any already-sent transactions must be marked for
        // abort, while the unsent ones can be immediately aborted and removed
        var events: [FEvent] = []

        var lastSent = -1
        // Note: all of the sent transactions will be at the front of the queue,
        // so safe to increment lastSent
        for transaction in queue {
            if transaction.status == .sentNeedsAbort {
                // No-op. already marked.
            } else if transaction.status == .sent {
                // Mark this transaction for abort when it returns
                lastSent += 1
                transaction.status = .sentNeedsAbort
                transaction.setAbortStatus(abortStatus: error, reason: nil)
            } else {
                // we can abort this immediately
                transaction.unwatcher()
/*
 if ([error isEqualToString:kFTransactionSet]) {
     [events
         addObjectsFromArray:
             [self.serverSyncTree
                 ackUserWriteWithWriteId:
                     [transaction.currentWriteId integerValue]
                                  revert:YES
                                 persist:NO
                                   clock:self.serverClock]];
 } else {
     // If it was cancelled it was already removed from the sync
     // tree, no need to ack
     NSAssert([error isEqualToString:kFErrorWriteCanceled], nil);
 }

 if (transaction.onComplete) {
     NSError *abortReason = [FUtilities errorForStatus:error
                                             andReason:nil];
     FIRDataSnapshot *snapshot = nil;
     fbt_void_void cb = ^{
       transaction.onComplete(abortReason, NO, snapshot);
     };
     [callbacks addObject:[cb copy]];
 }

 */
            }
            if lastSent == -1 {
                // We're not waiting for any sent transactions. We can clear the
                // queue.
                node.setValue(nil)
            } else {
                // Remove the transactions we aborted
                queue.removeLast(queue.count - (lastSent + 1))
            }
            // Now fire the callbacks
            self.eventRaiser.raiseCallbacks(callbacks)
        }
    }

    /**
     * @param writeIdsToExclude A specific set to exclude
     */
    private func latestStateAtPath(_ path: FPath, excludeWriteIds: [Int]) -> FNode {
        let latestState = serverSyncTree.calcCompleteEventCacheAtPath(path, excludeWriteIds: excludeWriteIds)
        return latestState ?? FEmptyNode.emptyNode
    }
}


/*

 - (id _Nonnull)initWithRepoInfo:(FRepoInfo *_Nullable)info
                          config:(FIRDatabaseConfig *_Nullable)config;

 - (void)set:(FPath *_Nullable)path
         withNode:(id _Nullable)node
     withCallback:(fbt_void_nserror_ref _Nullable)onComplete;
 - (void)update:(FPath *_Nullable)path
        withNodes:(FCompoundWrite *_Nullable)compoundWrite
     withCallback:(fbt_void_nserror_ref _Nullable)callback;
 - (void)purgeOutstandingWrites;

 - (void)getData:(FIRDatabaseQuery *_Nullable)query
     withCompletionBlock:
         (void (^_Nonnull)(NSError *_Nullable error,
                           FIRDataSnapshot *_Nullable snapshot))block;

 - (void)addEventRegistration:(id<FEventRegistration> _Nullable)eventRegistration
                     forQuery:(FQuerySpec *_Nullable)query;
 - (void)removeEventRegistration:
             (id<FEventRegistration> _Nullable)eventRegistration
                        forQuery:(FQuerySpec *_Nullable)query;
 - (void)keepQuery:(FQuerySpec *_Nullable)query synced:(BOOL)synced;

 - (NSString *_Nullable)name;
 - (NSTimeInterval)serverTime;

 - (void)onDataUpdate:(FPersistentConnection *_Nullable)fpconnection
              forPath:(NSString *_Nullable)pathString
              message:(id _Nullable)message
              isMerge:(BOOL)isMerge
                tagId:(NSNumber *_Nullable)tagId;
 - (void)onConnect:(FPersistentConnection *_Nullable)fpconnection;
 - (void)onDisconnect:(FPersistentConnection *_Nullable)fpconnection;

 // Disconnect methods
 - (void)onDisconnectCancel:(FPath *_Nullable)path
               withCallback:(fbt_void_nserror_ref _Nullable)callback;
 - (void)onDisconnectSet:(FPath *_Nullable)path
                withNode:(id<FNode> _Nullable)node
            withCallback:(fbt_void_nserror_ref _Nullable)callback;
 - (void)onDisconnectUpdate:(FPath *_Nullable)path
                  withNodes:(FCompoundWrite *_Nullable)compoundWrite
               withCallback:(fbt_void_nserror_ref _Nullable)callback;

 // Connection Management.
 - (void)interrupt;
 - (void)resume;

 // Transactions
 - (void)startTransactionOnPath:(FPath *_Nullable)path
                         update:
                             (fbt_transactionresult_mutabledata _Nullable)update
                     onComplete:
                         (fbt_void_nserror_bool_datasnapshot _Nullable)onComplete
                withLocalEvents:(BOOL)applyLocally;

 // Testing methods
 - (NSDictionary *_Nullable)dumpListens;
 - (void)dispose;
 - (void)setHijackHash:(BOOL)hijack;

 @property(nonatomic, strong, readonly) FAuthenticationManager *_Nullable auth;
 @property(nonatomic, strong, readonly) FIRDatabase *_Nullable database;

 @end

 */
