//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 05/03/2022.
//

import Foundation

// WARNING: If you change this, you need to write a migration script
let kFPersistenceVersion = "1"

let  kFServerDBPath = "server_data"
let  kFWritesDBPath = "writes"

let  kFUserWriteId = "id"
let  kFUserWritePath = "path"
let  kFUserWriteOverwrite = "o"
let  kFUserWriteMerge = "m"

let  kFTrackedQueryId = "id"
let  kFTrackedQueryPath = "path"
let  kFTrackedQueryParams = "p"
let  kFTrackedQueryLastUse = "lu"
let  kFTrackedQueryIsComplete = "c"
let  kFTrackedQueryIsActive = "a"

let  kFServerCachePrefix = "/server_cache/"
// '~' is the last non-control character in the ASCII table until 127
// We wan't the entire range of thing stored in the DB
let kFServerCacheRangeEnd = "/server_cache~"
let kFTrackedQueriesPrefix = "/tracked_queries/"
let kFTrackedQueryKeysPrefix = "/tracked_query_keys/"

// Failed to load JSON because a valid JSON turns out to be NaN while
// deserializing
let kFNanFailureCode = 3840

enum XXXDummyError: Error {
    case internalError
}

private func writeRecordKey(writeId: Int) -> String { "\(writeId)" }

private func serverCacheKey(_ path: FPath) -> String {
    kFServerCachePrefix + path.toStringWithTrailingSlash()
}

private func trackedQueryKey(trackedQueryId: Int) -> String {
    "\(kFTrackedQueriesPrefix)\(trackedQueryId)"
}

private func trackedQueryKeysKeyPrefix(trackedQueryId: Int) -> String {
    "\(kFTrackedQueryKeysPrefix)\(trackedQueryId)/"
}

private func trackedQueryKeysKey(trackedQueryId: Int, key: String) -> String {
    "\(kFTrackedQueryKeysPrefix)\(trackedQueryId)/\(key)"
}

@objc public class FLevelDBStorageEngine: NSObject, FStorageEngine {
    private var writesDB: APLevelDB!
    private var serverCacheDB: APLevelDB!
    private var basePath: URL
    
    @objc public static var firebaseDir: URL {
        // XXX TODO: Handle linux (and more) too. Note that for macOS this differs from previously
#if os(iOS) || os(watchOS) || os(macOS)
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDir = urls[0] // Yes, it's a hard error if we have no documents directory
        return documentsDir.appendingPathComponent("firebase")
#elseif os(tvOS)
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cachesDir = urls[0] // Yes, it's a hard error if we have no documents directory
        return cachesDir.appendingPathComponent("firebase")
#endif
    }

    @objc public init(path: String) {
        self.basePath = FLevelDBStorageEngine.firebaseDir.appendingPathComponent(path)
        /* For reference:
         serverDataDB = [aPersistence createDbByName:@"server_data"];
         FPangolinDB *completenessDb = [aPersistence
         createDbByName:@"server_complete"];
         */
        super.init()
        FLevelDBStorageEngine.ensureDir(&self.basePath, markAsDoNotBackup: true)
        runMigration()
        openDatabases()
    }

    private func runMigration() {
        // Currently we're at version 1, so all we need to do is write that to a
        // file
        let versionFile =
        basePath.appendingPathComponent("version")

        let oldVersion = try? String(contentsOf: versionFile, encoding: .utf8)
        if let oldVersion = oldVersion {
            if oldVersion == kFPersistenceVersion {
                // Everythings fine no need for migration
            } else if oldVersion.isEmpty {
                FFWarn("I-RDB076036",
                       "Version file empty. Assuming database version 1.")
            } else {
                // If we add more versions in the future, we need to run migration here
                fatalError("Unrecognized database version: \(oldVersion)")
            }
        } else {
            do {
                try kFPersistenceVersion.write(to: versionFile, atomically: false, encoding: .utf8)
            } catch {
                FFWarn("I-RDB076001", "Failed to write version for database: \(error)")
            }
        }
    }

    @objc public func runLegacyMigration(_ info: FRepoInfo) {
        fatalError("Not yet supported")
        /*
         - (void)runLegacyMigration:(FRepoInfo *)info {
             NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(
                 NSDocumentDirectory, NSUserDomainMask, YES);
             NSString *documentsDir = [dirPaths objectAtIndex:0];
             NSString *firebaseDir =
                 [documentsDir stringByAppendingPathComponent:@"firebase"];
             NSString *repoHashString =
                 [NSString stringWithFormat:@"%@_%@", info.host, info.namespace];
             NSString *legacyBaseDir =
                 [NSString stringWithFormat:@"%@/1/%@/v1", firebaseDir, repoHashString];
             if ([[NSFileManager defaultManager] fileExistsAtPath:legacyBaseDir]) {
                 FFWarn(@"I-RDB076002", @"Legacy database found, migrating...");
                 // We only need to migrate writes
                 NSError *error = nil;
                 APLevelDB *writes = [APLevelDB
                     levelDBWithPath:[legacyBaseDir stringByAppendingPathComponent:
                                                        @"outstanding_puts"]
                               error:&error];
                 if (writes != nil) {
                     __block NSUInteger numberOfWritesRestored = 0;
                     // Maybe we could use write batches, but what the heck, I'm sure
                     // it'll go fine :P
                     [writes enumerateKeysAndValuesAsData:^(NSString *key, NSData *data,
                                                            BOOL *stop) {
         #pragma clang diagnostic push
         #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                       // Update the deprecated API when minimum iOS version is 11+.
                       id pendingPut = [NSKeyedUnarchiver unarchiveObjectWithData:data];
         #pragma clang diagnostic pop
                       if ([pendingPut isKindOfClass:[FPendingPut class]]) {
                           FPendingPut *put = pendingPut;
                           id<FNode> newNode =
                               [FSnapshotUtilities nodeFrom:put.data
                                                   priority:put.priority];
                           [self saveUserOverwrite:newNode
                                            atPath:put.path
                                           writeId:[key integerValue]];
                           numberOfWritesRestored++;
                       } else if ([pendingPut
                                      isKindOfClass:[FPendingPutPriority class]]) {
                           // This is for backwards compatibility. Older clients will
                           // save FPendingPutPriority. New ones will need to read it and
                           // translate.
                           FPendingPutPriority *putPriority = pendingPut;
                           FPath *priorityPath =
                               [putPriority.path childFromString:@".priority"];
                           id<FNode> newNode =
                               [FSnapshotUtilities nodeFrom:putPriority.priority
                                                   priority:nil];
                           [self saveUserOverwrite:newNode
                                            atPath:priorityPath
                                           writeId:[key integerValue]];
                           numberOfWritesRestored++;
                       } else if ([pendingPut isKindOfClass:[FPendingUpdate class]]) {
                           FPendingUpdate *update = pendingPut;
                           FCompoundWrite *merge = [FCompoundWrite
                               compoundWriteWithValueDictionary:update.data];
                           [self saveUserMerge:merge
                                        atPath:update.path
                                       writeId:[key integerValue]];
                           numberOfWritesRestored++;
                       } else {
                           FFWarn(@"I-RDB076003",
                                  @"Failed to migrate legacy write, meh!");
                       }
                     }];
                     FFWarn(@"I-RDB076004", @"Migrated %lu writes",
                            (unsigned long)numberOfWritesRestored);
                     [writes close];
                     FFWarn(@"I-RDB076005", @"Deleting legacy database...");
                     BOOL success =
                         [[NSFileManager defaultManager] removeItemAtPath:legacyBaseDir
                                                                    error:&error];
                     if (!success) {
                         FFWarn(@"I-RDB076006", @"Failed to delete legacy database: %@",
                                error);
                     } else {
                         FFWarn(@"I-RDB076007", @"Finished migrating legacy database.");
                     }
                 } else {
                     FFWarn(@"I-RDB076008", @"Failed to migrate old database: %@",
                            error);
                 }
             }
         }

         */
    }

    private func openDatabases() {
        self.serverCacheDB = createDb(dbName: kFServerDBPath)
        self.writesDB = createDb(dbName: kFWritesDBPath)
    }

    private func purgeDatabase(dbPath: String) {
        let path = basePath.appendingPathComponent(dbPath)
        do {
            FFWarn("I-RDB076009", "Deleting database at path \(path)")
            try FileManager.default.removeItem(at: path)
        } catch {
            fatalError("Failed to delete database files: \(error)")
        }
    }

    @objc public func purgeEverything() {
        close()
        for path in [kFServerDBPath, kFWritesDBPath] {
            purgeDatabase(dbPath: path)
        }
        openDatabases()
    }

    public func close() {
        // XXX TODO: Original code contained an autorelease around the following to ensure connection is dropped
        serverCacheDB.close()
        serverCacheDB = nil
        writesDB.close()
        writesDB = nil
    }

    public func createDb(dbName: String) -> APLevelDB {
        let path = basePath.appendingPathComponent(dbName)
        do {
            return try APLevelDB(path: path.path)
        } catch {
            FFWarn("I-RDB076036",
                   "Failed to read database persistence file '\(dbName)': \(error)")
            // Delete the database and try again.
            purgeDatabase(dbPath: dbName)

            do {
                return try APLevelDB(path: path.path)
            } catch {
                fatalError("Error initializing persistence: \(error)")
            }
        }
    }

    public func saveUserOverwrite(_ node: FNode, atPath path: FPath, writeId: Int) {
        let write: [String: Any] = [
            kFUserWriteId : writeId,
            kFUserWritePath : path.toStringWithTrailingSlash(),
            kFUserWriteOverwrite : node.val(forExport: true)
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: write, options: [])
            _ = writesDB.setData(data, forKey: writeRecordKey(writeId: writeId))
        } catch {
            assertionFailure("Failed to serialize user overwrite: \(write), (Error: \(error)")
        }
    }

    public func saveUserMerge(_ merge: FCompoundWrite, atPath path: FPath, writeId: Int) {
        let write: [String: Any] = [
            kFUserWriteId : writeId,
            kFUserWritePath : path.toStringWithTrailingSlash(),
            kFUserWriteMerge : merge.valForExport(true)
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: write, options: [])
            _ = writesDB.setData(data, forKey: writeRecordKey(writeId: writeId))
        } catch {
            assertionFailure("Failed to serialize user overwrite: \(write), (Error: \(error)")
        }
    }

    public func removeUserWrite(_ writeId: Int) {
        _ = writesDB.removeKey(writeRecordKey(writeId: writeId))
    }

    public func removeAllUserWrites() {
        var count = 0
        let start = Date()
        let batch = writesDB.beginWriteBatch()
        writesDB.enumerateKeys { key, stop in
            batch.removeKey(key)
            count += 1
        }
        let success = batch.commit()
        if !success {
            FFWarn("I-RDB076010", "Failed to remove all users writes on disk!")
        } else {
            FFDebug("I-RDB076011", "Removed \(count) writes in \(start.timeIntervalSinceNow * -1000)ms")
        }
    }

    public var userWrites: [FWriteRecord] {
        let date = Date()
        var writes: [FWriteRecord] = []
        writesDB.enumerateKeysAndValues { (key: String, data: Data, stop: inout Bool) in
            do {
                guard let writeJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                guard let writeId = writeJSON[kFUserWriteId] as? Int else { return }
                guard let pathString = writeJSON[kFUserWritePath] as? String else { return }
                let path = FPath(with: pathString)
                /// XXX TODO: Let FWriteRecord be Decodable!
                let writeRecord: FWriteRecord
                if let dictionary = writeJSON[kFUserWriteMerge] as? [String: Any] {
                    // It's a merge
                    let merge = FCompoundWrite.compoundWrite(valueDictionary: dictionary)
                    writeRecord = FWriteRecord(path: path, merge: merge, writeId: writeId)
                } else if let overwrite = writeJSON[kFUserWriteOverwrite] {
                    let node = FSnapshotUtilitiesSwift.nodeFrom(overwrite)
                    writeRecord = FWriteRecord(path: path, overwrite: node, writeId: writeId, visible: true)
                } else {
                    fatalError("Persisted write did not contain merge or overwrite!")
                }
                writes.append(writeRecord)
            } catch {
                if (error as NSError).code == kFNanFailureCode {
                    FFWarn("I-RDB076012",
                           "Failed to deserialize write (\(String(data: data, encoding: .utf8) ?? "-"), likely because of out of range doubles (Error: \(error))")
                    FFWarn("I-RDB076013", "Removing failed write with key \(key)")
                    _ = self.writesDB.removeKey(key)
                } else {
                    fatalError("Failed to deserialize write: \(error)")
                }
            }
        }
        // Make sure writes are sorted
        writes.sort { $0.writeId < $1.writeId }
        FFDebug("I-RDB076014", "Loaded \(writes.count) writes in \(date.timeIntervalSinceNow * -1000)ms")
        return writes
    }

    public func serverCache(atPath path: FPath) -> FNode {
        let start = Date()
        let data = internalNestedData(for: path)
        let node = FSnapshotUtilitiesSwift.nodeFrom(data)
        FFDebug("I-RDB076015", "Loaded node with \(node.numChildren()) children at \(path) in \(start.timeIntervalSinceNow * -1000)ms")
        return node
    }

    private func internalNestedData(for path: FPath) -> Any? {
        let baseKey = serverCacheKey(path)

        // HACK to make sure iter is freed now to avoid race conditions (if self.db
        // is deleted before iter, you get an access violation).
        return autoreleasepool {
            let iter = APLevelDBIterator.iterator(levelDB: serverCacheDB)
            _ = iter.seek(toKey: baseKey)
            if let key = iter.key() {
                if !key.hasPrefix(baseKey) {
                    // No data.
                    return nil
                } else {
                    return internalNestedDataFromIterator(iter,
                                                          andKeyPrefix:baseKey)
                }
            } else {
                // No data.
                return nil

            }
        }
    }

    private func internalNestedDataFromIterator(_ iterator: APLevelDBIterator, andKeyPrefix prefix: String) -> Any? {
        var key = iterator.key()
        if key == prefix {
            let result = deserializePrimitive(iterator.valueAsData())
            _ = iterator.nextKey()
            return result
        } else {
            var dict: [String: Any] = [:]
            while let aKey = key, (key?.hasPrefix(prefix) ?? false) {
                let index = aKey.index(aKey.startIndex, offsetBy: prefix.count)
                let relativePath = aKey[index...]
                let pathPieces = relativePath.components(separatedBy: "/")
                assert(pathPieces.count > 0)
                let childName = pathPieces[0]
                let childPath = "\(prefix)\(childName)/"
                if let childValue = internalNestedDataFromIterator(iterator, andKeyPrefix: childPath) {
                    dict[childName] = childValue
                }
                key = iterator.key()
            }

            return dict
        }
    }

    private func serializePrimitive(_ value: Any) -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
        } catch {
            fatalError("Failed to serialize primitive: \(error)")
        }
    }

    private func fixDoubleParsing(_ value: Any) -> Any {
        if let decimal = value as? NSDecimalNumber {
            // In case the value is an NSDecimalNumber, we may be dealing with
            // precisions that are higher than what can be represented in a double.
            // In this case it does not suffice to check for integral numbers by
            // casting the [value doubleValue] to an int64_t, because this will
            // cause the compared values to be rounded to double precision.
            // Coupled with a bug in [NSDecimalNumber longLongValue] that triggers
            // when converting values with high precision, this would cause
            // values of high precision, but with an integral 'doubleValue'
            // representation to be converted to bogus values.
            // A radar for the NSDecimalNumber issue can be found here:
            // http://www.openradar.me/radar?id=5007005597040640
            // Consider the NSDecimalNumber value: 999.9999999999999487
            // This number has a 'doubleValue' of 1000. Using the previous version
            // of this method would cause the value to be interpreted to be integral
            // and then the resulting value would be based on the longLongValue
            // which due to the NSDecimalNumber issue would turn out as -844.
            // By using NSDecimal logic to test for integral values,
            // 999.9999999999999487 will not be considered integral, and instead
            // of triggering the 'longLongValue' issue, it will be returned as
            // the 'doubleValue' representation (1000).
            // Please note, that even without the NSDecimalNumber issue, the
            // 'correct' longLongValue of 999.9999999999999487 is 999 and not 1000,
            // so the previous code would cause issues even without the bug
            // referenced in the radar.
            var original: Decimal = decimal.decimalValue
            var rounded: Decimal = 0
            NSDecimalRound(&rounded, &original, 0, .plain);
            if (NSDecimalCompare(&original, &rounded) != .orderedSame) {
                let doubleString = decimal.stringValue as NSString
                return NSNumber(value: doubleString.doubleValue)
            } else {
                return NSNumber(value: decimal.int64Value)
            }
        } else if let number = value as? NSNumber {
            // The parser for double values in JSONSerialization at the root takes
            // some short-cuts and delivers wrong results (wrong rounding) for some
            // double values, including 2.47. Because we use the exact bytes for
            // hashing on the server this will lead to hash mismatches. The parser
            // of NSNumber seems to be more in line with what the server expects, so
            // we use that here
            let type = CFNumberGetType(number as CFNumber)
            if (type == .doubleType || type == .floatType) {
                // The NSJSON parser returns all numbers as double values, even
                // those that contain no exponent. To make sure that the String
                // conversion below doesn't unexpectedly reduce precision, we make
                // sure that our number is indeed not an integer.
                if Double(Int64(number.doubleValue)) != number.doubleValue {
                    let doubleString = number.stringValue as NSString
                    return NSNumber(value: doubleString.doubleValue)
                } else {
                    return NSNumber(value: number.int64Value)
                }
            }
        }
        return value
    }

    private func deserializePrimitive(_ data: Data?) -> Any {
        guard let data = data else { return NSNull() }
        do {
            let result = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            return fixDoubleParsing(result)
        } catch {
            if (error as NSError).code == kFNanFailureCode {
                FFWarn("I-RDB076034",
                       "Failed to load primitive \(String(data: data, encoding: .utf8) ?? "-"), likely because doubles where out of range (Error: \(error))")
                return NSNull()
            } else {
                fatalError("Failed to deserialize primitive: \(error)")
            }
        }
    }

    private static func ensureDir(_ path: inout URL, markAsDoNotBackup: Bool) {
        do {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        } catch {
            fatalError("Failed to create persistence directory. Error: \(error) Path: \(path.path)")
        }
        guard markAsDoNotBackup else { return }
        do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try path.setResourceValues(values)
        } catch {
            FFWarn(
                "I-RDB076035",
                "Failed to mark firebase database folder as do not backup: \(error)")
            fatalError("Failed to mark folder \(path.path) as do not backup")
        }
    }

    public func serverCache(forKeys keys: Set<String>, atPath path: FPath) -> FNode {
        let start = Date()
        var node: FNode = FEmptyNode.emptyNode
        for key in keys {
            let data = internalNestedData(for: path.child(fromString: key))
            node = node.updateImmediateChild(key, withNewChild: FSnapshotUtilitiesSwift.nodeFrom(data))
        }
        FFDebug("I-RDB076016",
                "Loaded node with \(node.numChildren()) children for \(keys.count) keys at \(path) in \(start.timeIntervalSinceNow * -1000)ms")
        return node
    }

    private func removeAllLeafNodes(on path: FPath, batch: APLevelDBWriteBatch) {
        var path: FPath? = path
        while let aPath = path {
            batch.removeKey(serverCacheKey(aPath))
            path = aPath.parent()
        }
        // Make sure to delete any nodes at the root
        batch.removeKey(serverCacheKey(.empty))
    }

    private func removeAllWrites(withPrefix prefix: String, batch: APLevelDBWriteBatch, database: APLevelDB) {
        database.enumerateKeys(withPrefix: prefix, usingBlock: { key, stop in batch.removeKey(key) })
    }

    public func updateServerCache(_ node: FNode, atPath path: FPath, merge: Bool) {
        let start = Date()
        let batch = serverCacheDB.beginWriteBatch()
        // Remove any leaf nodes that might be higher up
        removeAllLeafNodes(on: path, batch: batch)
        var counter = 0
        if merge {
            // remove any children that exist
            node.enumerateChildren { childKey, childNode, stop in
                let childPath = path.child(fromString: childKey)
                self.removeAllWrites(withPrefix: serverCacheKey(childPath), batch: batch, database: self.serverCacheDB)
                self.saveNodeInternal(childNode, atPath: childPath, batch: batch, counter: &counter)
            }
        } else {
            // remove everything
            removeAllWrites(withPrefix: serverCacheKey(path), batch: batch, database: serverCacheDB)
            saveNodeInternal(node, atPath: path, batch: batch, counter: &counter)
        }
        let success = batch.commit()
        if !success {
            FFWarn("I-RDB076017", "Failed to update server cache on disk!")
        } else {
            FFDebug("I-RDB076018", "Saved \(counter) leaf nodes for overwrite in \(start.timeIntervalSinceNow * -1000)ms")
        }
    }

    public func updateServerCache(merge: FCompoundWrite, atPath path: FPath) {
        let start = Date()
        var count = 0
        let batch = serverCacheDB.beginWriteBatch()
        // Remove any leaf nodes that might be higher up
        removeAllLeafNodes(on: path, batch: batch)
        merge.enumerateWrites { relativePath, node, stop in
            let childPath = path.child(relativePath)
            self.removeAllWrites(withPrefix: serverCacheKey(childPath), batch: batch, database: self.serverCacheDB)
            self.saveNodeInternal(node, atPath: childPath, batch: batch, counter: &count)
        }
        let success = batch.commit()
        if !success {
            FFWarn("I-RDB076019", "Failed to update server cache on disk!")
        } else {
            FFDebug("I-RDB076020", "Saved \(count) leaf nodes for merge in \(start.timeIntervalSinceNow * -1000)ms")
        }
    }

    private func saveNodeInternal(_ node: FNode, atPath path: FPath, batch: APLevelDBWriteBatch, counter: inout Int) {
        let data = node.val(forExport: true)
        guard !(data is NSNull) else { return }

        internalSetNestedData(data, forKey: serverCacheKey(path), withBatch: batch, counter: &counter)
    }

    private func internalSetNestedData(_ value: Any, forKey key: String, withBatch batch: APLevelDBWriteBatch, counter: inout Int) {
        if let dictionary = value as? [String: Any] {
            for (childKey, obj) in dictionary {
                let childPath = "\(key)\(childKey)/"
                internalSetNestedData(obj, forKey: childPath, withBatch: batch, counter: &counter)
            }
        } else {
            let data = serializePrimitive(value)
            batch.setData(data, forKey: key)
            counter += 1
        }
    }

    public var serverCacheEstimatedSizeInBytes: Int {
        // Use the exact size, because for pruning the approximate size can lead to
        // weird situations where we prune everything because no compaction is ever
        // run
        serverCacheDB.exactSize(from: kFServerCachePrefix,
                                to: kFServerCacheRangeEnd)
    }

    public func pruneCache(_ pruneForest: FPruneForest, atPath path: FPath) {
        // TODO: be more intelligent, don't scan entire database...
        var pruned = 0
        var kept = 0
        let start = Date()

        let prefix = serverCacheKey(path)
        let batch = serverCacheDB.beginWriteBatch()
        serverCacheDB.enumerateKeys(withPrefix: prefix) { (dbKey: String, stop) in
            let index = dbKey.index(dbKey.startIndex, offsetBy: prefix.count)
            let pathStr = String(dbKey[index...])
            let relativePath = FPath(with: pathStr)
            if pruneForest.shouldPruneUnkeptDescendants(atPath: relativePath) {
                pruned += 1
                batch.removeKey(dbKey)
            } else {
                kept += 1
            }
        }
        let success = batch.commit()
        if !success {
            FFWarn("I-RDB076021", "Failed to prune cache on disk!")
        } else {
            FFDebug("I-RDB076022", "Pruned \(pruned) paths, kept \(kept) paths in \(start.timeIntervalSinceNow * -1000)ms")
        }
    }

    // MARK: Tracked queries

    public func loadTrackedQueries() -> [FTrackedQuery] {
        let date = Date()
        var trackedQueries: [FTrackedQuery] = []
        serverCacheDB.enumerateKeys(withPrefix: kFTrackedQueriesPrefix, asData: { key, data, stop in
            do {
                guard let queryJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw XXXDummyError.internalError
                }
                guard let queryId = queryJSON[kFTrackedQueryId] as? Int else {
                    throw XXXDummyError.internalError
                }
                guard let pathString = queryJSON[kFTrackedQueryPath] as? String else {
                    throw XXXDummyError.internalError
                }
                let path = FPath(with: pathString)
                guard let queryObject = queryJSON[kFTrackedQueryParams] as? [String: Any] else {
                    throw XXXDummyError.internalError
                }
                let params = FQueryParams.fromQueryObject(queryObject)
                let query = FQuerySpec(path: path, params: params)
                guard let isComplete = queryJSON[kFTrackedQueryIsComplete] as? Bool else {
                    throw XXXDummyError.internalError
                }
                guard let isActive = queryJSON[kFTrackedQueryIsActive] as? Bool else {
                    throw XXXDummyError.internalError
                }
                guard let lastUse = queryJSON[kFTrackedQueryLastUse] as? TimeInterval else {
                    throw XXXDummyError.internalError
                }
                let trackedQuery = FTrackedQuery(id: queryId,
                                                 query: query,
                                                 lastUse: lastUse,
                                                 isActive: isActive,
                                                 isComplete: isComplete)
                trackedQueries.append(trackedQuery)

            } catch {
                if (error as NSError).code == kFNanFailureCode {
                    FFWarn(
                        "I-RDB076023",
                        "Failed to deserialize tracked query (\(String(data: data, encoding: .utf8) ?? "-")), likely because of out of range doubles (Error: \(error))")
                    FFWarn("I-RDB076024",
                           "Removing failed tracked query with key \(key)")
                    _ = self.serverCacheDB.removeKey(key)
                } else {
                    fatalError("Failed to deserialize tracked query: \(error)")
                }

            }
        })
        FFDebug("I-RDB076025", "Loaded \(trackedQueries.count) tracked queries in \(date.timeIntervalSinceNow * -1000)ms")
        return trackedQueries
    }

    public func removeTrackedQuery(_ queryId: Int) {
        let start = Date()
        let batch = serverCacheDB.beginWriteBatch()
        batch.removeKey(trackedQueryKey(trackedQueryId: queryId))
        var keyCount = 0
        serverCacheDB.enumerateKeys(withPrefix: trackedQueryKeysKeyPrefix(trackedQueryId: queryId), usingBlock: { key, stop in
            batch.removeKey(key)
            keyCount += 1
        })
        let success = batch.commit()
        if !success {
            FFWarn("I-RDB076026", "Failed to remove tracked query on disk!")
        } else {
            FFDebug("I-RDB076027", "Removed query with id \(queryId) (and removed \(keyCount) keys) in \(start.timeIntervalSinceNow * -1000)ms")
        }
    }

    public func saveTrackedQuery(_ query: FTrackedQuery) {
        let start = Date()
        let trackedQuery: [String: Any] = [
            kFTrackedQueryId : query.queryId,
            kFTrackedQueryPath : query.query.path.toStringWithTrailingSlash(),
            kFTrackedQueryParams : query.query.params.wireProtocolParams,
            kFTrackedQueryLastUse : query.lastUse,
            kFTrackedQueryIsComplete : query.isComplete,
            kFTrackedQueryIsActive : query.isActive
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: trackedQuery)
            _ = serverCacheDB.setData(data, forKey: trackedQueryKey(trackedQueryId: query.queryId))
        } catch {
            assertionFailure("Failed to serialize tracked query (Error: \(error)")
        }
        FFDebug("I-RDB076028", "Saved tracked query \(query.queryId) in \(start.timeIntervalSinceNow * -1000)ms")
    }

    public func setTrackedQueryKeys(_ keys: Set<String>, forQueryId queryId: Int) {
        let start = Date()
        var removed = 0
        var added = 0
        let batch = serverCacheDB.beginWriteBatch()
        var seenKeys: Set<String> = []
        // First, delete any keys that might be stored and are not part of the
        // current keys
        serverCacheDB.enumerateKeys(withPrefix: trackedQueryKeysKeyPrefix(trackedQueryId: queryId), asStrings: { dbKey, actualKey, stop in
            if keys.contains(actualKey) {
                // Already in DB
                seenKeys.insert(actualKey)
            } else {
                // Not part of set, delete key
                batch.removeKey(dbKey)
                removed += 1
            }
        })
        // Next add any keys that are missing in the database
        for childKey in keys {
            if !seenKeys.contains(childKey) {
                batch.setString(childKey, forKey: trackedQueryKeysKey(trackedQueryId: queryId, key: childKey))
                added += 1
            }
        }
        let success = batch.commit()
        if !success {
            FFWarn("I-RDB076029", "Failed to set tracked queries on disk!")
        } else {
            FFDebug("I-RDB076030", "Set \(keys.count) tracked keys (\(added) added, \(removed) removed) for query \(queryId) in \(start.timeIntervalSinceNow * -1000)ms")
        }
    }

    public func updateTrackedQueryKeys(addedKeys added: Set<String>, removedKeys removed: Set<String>, forQueryId queryId: Int) {
        let start = Date()
        let batch = serverCacheDB.beginWriteBatch()
        for key in removed {
            batch.removeKey(trackedQueryKeysKey(trackedQueryId: queryId, key: key))
        }
        for key in added {
            batch.setString(key, forKey: trackedQueryKeysKey(trackedQueryId: queryId, key: key))
        }
        let success = batch.commit()
        if !success {
            FFWarn("I-RDB076031", "Failed to update tracked queries on disk!")
        } else {
            FFDebug("I-RDB076032", "Added \(added.count) tracked keys, removed \(removed.count) for query \(queryId) in \(start.timeIntervalSinceNow * -1000)ms")
        }
    }

    public func trackedQueryKeysForQuery(_ queryId: Int) -> Set<String> {
        let start = Date()
        var set: Set<String> = []

        serverCacheDB.enumerateKeys(withPrefix: trackedQueryKeysKeyPrefix(trackedQueryId: queryId), asStrings: { dbKey, actualKey, stop in
            // XXX TODO: The [NSString stringWithUTF8String: ...] is just added in order to fix
            // tests since apparently a set of bridged strings compared unequal to a set of unbridged strings
            set.insert(NSString(utf8String: (actualKey as NSString).utf8String!)! as String)
//            set.insert(actualKey)
        })

        FFDebug("I-RDB076033", "Loaded \(set.count) tracked keys for query \(queryId) in \(start.timeIntervalSinceNow * -1000)ms")
        return set
    }

}
