/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

#import "FirebaseDatabase/Sources/Persistence/FLevelDBStorageEngine.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Core/FWriteRecord.h"
#import "FirebaseDatabase/Sources/Persistence/FPendingPut.h"
#import "FirebaseDatabase/Sources/Persistence/FPruneForest.h"
#import "FirebaseDatabase/Sources/Persistence/FTrackedQuery.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseDatabase/Sources/third_party/Wrap-leveldb/APLevelDB.h"

@interface FLevelDBStorageEngine ()

@property(nonatomic, strong) NSString *basePath;
@property(nonatomic, strong) APLevelDB *writesDB;
@property(nonatomic, strong) APLevelDB *serverCacheDB;

@end

// WARNING: If you change this, you need to write a migration script
static NSString *const kFPersistenceVersion = @"1";

static NSString *const kFServerDBPath = @"server_data";
static NSString *const kFWritesDBPath = @"writes";

static NSString *const kFUserWriteId = @"id";
static NSString *const kFUserWritePath = @"path";
static NSString *const kFUserWriteOverwrite = @"o";
static NSString *const kFUserWriteMerge = @"m";

static NSString *const kFTrackedQueryId = @"id";
static NSString *const kFTrackedQueryPath = @"path";
static NSString *const kFTrackedQueryParams = @"p";
static NSString *const kFTrackedQueryLastUse = @"lu";
static NSString *const kFTrackedQueryIsComplete = @"c";
static NSString *const kFTrackedQueryIsActive = @"a";

static NSString *const kFServerCachePrefix = @"/server_cache/";
// '~' is the last non-control character in the ASCII table until 127
// We wan't the entire range of thing stored in the DB
static NSString *const kFServerCacheRangeEnd = @"/server_cache~";
static NSString *const kFTrackedQueriesPrefix = @"/tracked_queries/";
static NSString *const kFTrackedQueryKeysPrefix = @"/tracked_query_keys/";

// Failed to load JSON because a valid JSON turns out to be NaN while
// deserializing
static const NSInteger kFNanFailureCode = 3840;

static NSString *writeRecordKey(NSUInteger writeId) {
    return [NSString stringWithFormat:@"%lu", (unsigned long)(writeId)];
}

static NSString *serverCacheKey(FPath *path) {
    return [NSString stringWithFormat:@"%@%@", kFServerCachePrefix,
                                      ([path toStringWithTrailingSlash])];
}

static NSString *trackedQueryKey(NSUInteger trackedQueryId) {
    return [NSString stringWithFormat:@"%@%lu", kFTrackedQueriesPrefix,
                                      (unsigned long)trackedQueryId];
}

static NSString *trackedQueryKeysKeyPrefix(NSUInteger trackedQueryId) {
    return [NSString stringWithFormat:@"%@%lu/", kFTrackedQueryKeysPrefix,
                                      (unsigned long)trackedQueryId];
}

static NSString *trackedQueryKeysKey(NSUInteger trackedQueryId, NSString *key) {
    return [NSString stringWithFormat:@"%@%lu/%@", kFTrackedQueryKeysPrefix,
                                      (unsigned long)trackedQueryId, key];
}

@implementation FLevelDBStorageEngine
#pragma mark - Constructors

- (id)initWithPath:(NSString *)dbPath {
    self = [super init];
    if (self) {
        self.basePath = [[FLevelDBStorageEngine firebaseDir]
            stringByAppendingPathComponent:dbPath];
        /* For reference:
         serverDataDB = [aPersistence createDbByName:@"server_data"];
         FPangolinDB *completenessDb = [aPersistence
         createDbByName:@"server_complete"];
         */
        [FLevelDBStorageEngine ensureDir:self.basePath markAsDoNotBackup:YES];
        [self runMigration];
        [self openDatabases];
    }
    return self;
}

- (void)runMigration {
    // Currently we're at version 1, so all we need to do is write that to a
    // file
    NSString *versionFile =
        [self.basePath stringByAppendingPathComponent:@"version"];
    NSError *error;
    NSString *oldVersion =
        [NSString stringWithContentsOfFile:versionFile
                                  encoding:NSUTF8StringEncoding
                                     error:&error];
    if (!oldVersion) {
        // This is probably fine, we don't have a version file yet
        BOOL success = [kFPersistenceVersion writeToFile:versionFile
                                              atomically:NO
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
        if (!success) {
            FFWarn(@"I-RDB076001", @"Failed to write version for database: %@",
                   error);
        }
    } else if ([oldVersion isEqualToString:kFPersistenceVersion]) {
        // Everythings fine no need for migration
    } else if ([oldVersion length] == 0) {
        FFWarn(@"I-RDB076036",
               @"Version file empty. Assuming database version 1.");
    } else {
        // If we add more versions in the future, we need to run migration here
        [NSException raise:NSInternalInconsistencyException
                    format:@"Unrecognized database version: %@", oldVersion];
    }
}

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
              NSError *error;
              id pendingPut = [NSKeyedUnarchiver
                  unarchivedObjectOfClasses:
                      [NSSet setWithObjects:[FPendingPut class],
                                            [FPendingPutPriority class],
                                            [FPendingUpdate class], nil]
                                   fromData:data
                                      error:&error];
              if (error) {
                  FFWarn(@"I-RDB076003", @"Failed to migrate legacy write: %@",
                         error);
              } else if ([pendingPut isKindOfClass:[FPendingPut class]]) {
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
                         @"Failed to migrate legacy write: unrecognized class "
                         @"\"%@\"",
                         [pendingPut class]);
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

- (void)openDatabases {
    self.serverCacheDB = [self createDB:kFServerDBPath];
    self.writesDB = [self createDB:kFWritesDBPath];
}

- (void)purgeDatabase:(NSString *)dbPath {
    NSString *path = [self.basePath stringByAppendingPathComponent:dbPath];
    NSError *error;
    FFWarn(@"I-RDB076009", @"Deleting database at path %@", path);
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:path
                                                              error:&error];
    if (!success) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Failed to delete database files: %@", error];
    }
}

- (void)purgeEverything {
    [self close];
    [@[ kFServerDBPath, kFWritesDBPath ]
        enumerateObjectsUsingBlock:^(NSString *dbPath, NSUInteger idx,
                                     BOOL *stop) {
          [self purgeDatabase:dbPath];
        }];

    [self openDatabases];
}

- (void)close {
    // autoreleasepool will cause deallocation which will close the DB
    @autoreleasepool {
        [self.serverCacheDB close];
        self.serverCacheDB = nil;
        [self.writesDB close];
        self.writesDB = nil;
    }
}

+ (NSString *)firebaseDir {
#if TARGET_OS_IOS || TARGET_OS_WATCH ||                                        \
    (defined(TARGET_OS_VISION) && TARGET_OS_VISION)
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [dirPaths objectAtIndex:0];
    return [documentsDir stringByAppendingPathComponent:@"firebase"];
#elif TARGET_OS_TV
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(
        NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDir = [dirPaths objectAtIndex:0];
    return [cachesDir stringByAppendingPathComponent:@"firebase"];
#elif TARGET_OS_OSX
    return [NSHomeDirectory() stringByAppendingPathComponent:@".firebase"];
#endif
}

- (APLevelDB *)createDB:(NSString *)dbName {
    NSError *err = nil;
    NSString *path = [self.basePath stringByAppendingPathComponent:dbName];
    APLevelDB *db = [APLevelDB levelDBWithPath:path error:&err];

    if (err) {
        FFWarn(@"I-RDB076036",
               @"Failed to read database persistence file '%@': %@", dbName,
               [err localizedDescription]);
        err = nil;

        // Delete the database and try again.
        [self purgeDatabase:dbName];
        db = [APLevelDB levelDBWithPath:path error:&err];

        if (err) {
            NSString *reason = [NSString
                stringWithFormat:@"Error initializing persistence: %@",
                                 [err description]];
            @throw [NSException
                exceptionWithName:@"FirebaseDatabasePersistenceFailure"
                           reason:reason
                         userInfo:nil];
        }
    }

    return db;
}

- (void)saveUserOverwrite:(id<FNode>)node
                   atPath:(FPath *)path
                  writeId:(NSUInteger)writeId {
    NSDictionary *write = @{
        kFUserWriteId : @(writeId),
        kFUserWritePath : [path toStringWithTrailingSlash],
        kFUserWriteOverwrite : [node valForExport:YES]
    };
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:write
                                                   options:0
                                                     error:&error];
    NSAssert(data, @"Failed to serialize user overwrite: %@, (Error: %@)",
             write, error);
    [self.writesDB setData:data forKey:writeRecordKey(writeId)];
}

- (void)saveUserMerge:(FCompoundWrite *)merge
               atPath:(FPath *)path
              writeId:(NSUInteger)writeId {
    NSDictionary *write = @{
        kFUserWriteId : @(writeId),
        kFUserWritePath : [path toStringWithTrailingSlash],
        kFUserWriteMerge : [merge valForExport:YES]
    };
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:write
                                                   options:0
                                                     error:&error];
    NSAssert(data, @"Failed to serialize user merge: %@ (Error: %@)", write,
             error);
    [self.writesDB setData:data forKey:writeRecordKey(writeId)];
}

- (void)removeUserWrite:(NSUInteger)writeId {
    [self.writesDB removeKey:writeRecordKey(writeId)];
}

- (void)removeAllUserWrites {
    __block NSUInteger count = 0;
    NSDate *start = [NSDate date];
    id<APLevelDBWriteBatch> batch = [self.writesDB beginWriteBatch];
    [self.writesDB enumerateKeys:^(NSString *key, BOOL *stop) {
      [batch removeKey:key];
      count++;
    }];
    BOOL success = [batch commit];
    if (!success) {
        FFWarn(@"I-RDB076010", @"Failed to remove all users writes on disk!");
    } else {
        FFDebug(@"I-RDB076011", @"Removed %lu writes in %fms",
                (unsigned long)count, [start timeIntervalSinceNow] * -1000);
    }
}

- (NSArray *)userWrites {
    NSDate *date = [NSDate date];
    NSMutableArray *writes = [NSMutableArray array];
    [self.writesDB enumerateKeysAndValuesAsData:^(NSString *key, NSData *data,
                                                  BOOL *stop) {
      NSError *error = nil;
      NSDictionary *writeJSON = [NSJSONSerialization JSONObjectWithData:data
                                                                options:0
                                                                  error:&error];
      if (writeJSON == nil) {
          if (error.code == kFNanFailureCode) {
              FFWarn(@"I-RDB076012",
                     @"Failed to deserialize write (%@), likely because of out "
                     @"of range doubles (Error: %@)",
                     [[NSString alloc] initWithData:data
                                           encoding:NSUTF8StringEncoding],
                     error);
              FFWarn(@"I-RDB076013", @"Removing failed write with key %@", key);
              [self.writesDB removeKey:key];
          } else {
              [NSException raise:NSInternalInconsistencyException
                          format:@"Failed to deserialize write: %@", error];
          }
      } else {
          NSInteger writeId =
              ((NSNumber *)writeJSON[kFUserWriteId]).integerValue;
          FPath *path = [FPath pathWithString:writeJSON[kFUserWritePath]];
          FWriteRecord *writeRecord;
          if (writeJSON[kFUserWriteMerge] != nil) {
              // It's a merge
              FCompoundWrite *merge = [FCompoundWrite
                  compoundWriteWithValueDictionary:writeJSON[kFUserWriteMerge]];
              writeRecord = [[FWriteRecord alloc] initWithPath:path
                                                         merge:merge
                                                       writeId:writeId];
          } else {
              // It's an overwrite
              NSAssert(writeJSON[kFUserWriteOverwrite] != nil,
                       @"Persisted write did not contain merge or overwrite!");
              id<FNode> node =
                  [FSnapshotUtilities nodeFrom:writeJSON[kFUserWriteOverwrite]];
              writeRecord = [[FWriteRecord alloc] initWithPath:path
                                                     overwrite:node
                                                       writeId:writeId
                                                       visible:YES];
          }
          [writes addObject:writeRecord];
      }
    }];
    // Make sure writes are sorted
    [writes sortUsingComparator:^NSComparisonResult(FWriteRecord *one,
                                                    FWriteRecord *two) {
      if (one.writeId < two.writeId) {
          return NSOrderedAscending;
      } else if (one.writeId > two.writeId) {
          return NSOrderedDescending;
      } else {
          return NSOrderedSame;
      }
    }];
    FFDebug(@"I-RDB076014", @"Loaded %lu writes in %fms",
            (unsigned long)writes.count, [date timeIntervalSinceNow] * -1000);
    return writes;
}

- (id<FNode>)serverCacheAtPath:(FPath *)path {
    NSDate *start = [NSDate date];
    id data = [self internalNestedDataForPath:path];
    id<FNode> node = [FSnapshotUtilities nodeFrom:data];
    FFDebug(@"I-RDB076015", @"Loaded node with %d children at %@ in %fms",
            [node numChildren], path, [start timeIntervalSinceNow] * -1000);
    return node;
}

- (id<FNode>)serverCacheForKeys:(NSSet *)keys atPath:(FPath *)path {
    NSDate *start = [NSDate date];
    __block id<FNode> node = [FEmptyNode emptyNode];
    [keys enumerateObjectsUsingBlock:^(NSString *key, BOOL *stop) {
      id data = [self internalNestedDataForPath:[path childFromString:key]];
      node = [node updateImmediateChild:key
                           withNewChild:[FSnapshotUtilities nodeFrom:data]];
    }];
    FFDebug(@"I-RDB076016",
            @"Loaded node with %d children for %lu keys at %@ in %fms",
            [node numChildren], (unsigned long)keys.count, path,
            [start timeIntervalSinceNow] * -1000);
    return node;
}

- (void)updateServerCache:(id<FNode>)node
                   atPath:(FPath *)path
                    merge:(BOOL)merge {
    NSDate *start = [NSDate date];
    id<APLevelDBWriteBatch> batch = [self.serverCacheDB beginWriteBatch];
    // Remove any leaf nodes that might be higher up
    [self removeAllLeafNodesOnPath:path batch:batch];
    __block NSUInteger counter = 0;
    if (merge) {
        // remove any children that exist
        [node enumerateChildrenUsingBlock:^(NSString *childKey,
                                            id<FNode> childNode, BOOL *stop) {
          FPath *childPath = [path childFromString:childKey];
          [self removeAllWithPrefix:serverCacheKey(childPath)
                              batch:batch
                           database:self.serverCacheDB];
          [self saveNodeInternal:childNode
                          atPath:childPath
                           batch:batch
                         counter:&counter];
        }];
    } else {
        // remove everything
        [self removeAllWithPrefix:serverCacheKey(path)
                            batch:batch
                         database:self.serverCacheDB];
        [self saveNodeInternal:node atPath:path batch:batch counter:&counter];
    }
    BOOL success = [batch commit];
    if (!success) {
        FFWarn(@"I-RDB076017", @"Failed to update server cache on disk!");
    } else {
        FFDebug(@"I-RDB076018", @"Saved %lu leaf nodes for overwrite in %fms",
                (unsigned long)counter, [start timeIntervalSinceNow] * -1000);
    }
}

- (void)updateServerCacheWithMerge:(FCompoundWrite *)merge
                            atPath:(FPath *)path {
    NSDate *start = [NSDate date];
    __block NSUInteger counter = 0;
    id<APLevelDBWriteBatch> batch = [self.serverCacheDB beginWriteBatch];
    // Remove any leaf nodes that might be higher up
    [self removeAllLeafNodesOnPath:path batch:batch];
    [merge enumerateWrites:^(FPath *relativePath, id<FNode> node, BOOL *stop) {
      FPath *childPath = [path child:relativePath];
      [self removeAllWithPrefix:serverCacheKey(childPath)
                          batch:batch
                       database:self.serverCacheDB];
      [self saveNodeInternal:node
                      atPath:childPath
                       batch:batch
                     counter:&counter];
    }];
    BOOL success = [batch commit];
    if (!success) {
        FFWarn(@"I-RDB076019", @"Failed to update server cache on disk!");
    } else {
        FFDebug(@"I-RDB076020", @"Saved %lu leaf nodes for merge in %fms",
                (unsigned long)counter, [start timeIntervalSinceNow] * -1000);
    }
}

- (void)saveNodeInternal:(id<FNode>)node
                  atPath:(FPath *)path
                   batch:(id<APLevelDBWriteBatch>)batch
                 counter:(NSUInteger *)counter {
    id data = [node valForExport:YES];
    if (data != nil && ![data isKindOfClass:[NSNull class]]) {
        [self internalSetNestedData:data
                             forKey:serverCacheKey(path)
                          withBatch:batch
                            counter:counter];
    }
}

- (NSUInteger)serverCacheEstimatedSizeInBytes {
    // Use the exact size, because for pruning the approximate size can lead to
    // weird situations where we prune everything because no compaction is ever
    // run
    return [self.serverCacheDB exactSizeFrom:kFServerCachePrefix
                                          to:kFServerCacheRangeEnd];
}

- (void)pruneCache:(FPruneForest *)pruneForest atPath:(FPath *)path {
    // TODO: be more intelligent, don't scan entire database...

    __block NSUInteger pruned = 0;
    __block NSUInteger kept = 0;
    NSDate *start = [NSDate date];

    NSString *prefix = serverCacheKey(path);
    id<APLevelDBWriteBatch> batch = [self.serverCacheDB beginWriteBatch];

    [self.serverCacheDB
        enumerateKeysWithPrefix:prefix
                     usingBlock:^(NSString *dbKey, BOOL *stop) {
                       NSString *pathStr =
                           [dbKey substringFromIndex:prefix.length];
                       FPath *relativePath = [[FPath alloc] initWith:pathStr];
                       if ([pruneForest shouldPruneUnkeptDescendantsAtPath:
                                            relativePath]) {
                           pruned++;
                           [batch removeKey:dbKey];
                       } else {
                           kept++;
                       }
                     }];
    BOOL success = [batch commit];
    if (!success) {
        FFWarn(@"I-RDB076021", @"Failed to prune cache on disk!");
    } else {
        FFDebug(@"I-RDB076022", @"Pruned %lu paths, kept %lu paths in %fms",
                (unsigned long)pruned, (unsigned long)kept,
                [start timeIntervalSinceNow] * -1000);
    }
}

#pragma mark - Tracked Queries

- (NSArray *)loadTrackedQueries {
    NSDate *date = [NSDate date];
    NSMutableArray *trackedQueries = [NSMutableArray array];
    [self.serverCacheDB
        enumerateKeysWithPrefix:kFTrackedQueriesPrefix
                         asData:^(NSString *key, NSData *data, BOOL *stop) {
                           NSError *error = nil;
                           NSDictionary *queryJSON =
                               [NSJSONSerialization JSONObjectWithData:data
                                                               options:0
                                                                 error:&error];
                           if (queryJSON == nil) {
                               if (error.code == kFNanFailureCode) {
                                   FFWarn(
                                       @"I-RDB076023",
                                       @"Failed to deserialize tracked query "
                                       @"(%@), likely because of out of range "
                                       @"doubles (Error: %@)",
                                       [[NSString alloc]
                                           initWithData:data
                                               encoding:NSUTF8StringEncoding],
                                       error);
                                   FFWarn(@"I-RDB076024",
                                          @"Removing failed tracked query with "
                                          @"key %@",
                                          key);
                                   [self.serverCacheDB removeKey:key];
                               } else {
                                   [NSException
                                        raise:NSInternalInconsistencyException
                                       format:@"Failed to deserialize tracked "
                                              @"query: %@",
                                              error];
                               }
                           } else {
                               NSUInteger queryId =
                                   ((NSNumber *)queryJSON[kFTrackedQueryId])
                                       .unsignedIntegerValue;
                               FPath *path =
                                   [FPath pathWithString:
                                              queryJSON[kFTrackedQueryPath]];
                               FQueryParams *params = [FQueryParams
                                   fromQueryObject:queryJSON
                                                       [kFTrackedQueryParams]];
                               FQuerySpec *query =
                                   [[FQuerySpec alloc] initWithPath:path
                                                             params:params];
                               BOOL isComplete =
                                   [queryJSON[kFTrackedQueryIsComplete]
                                       boolValue];
                               BOOL isActive =
                                   [queryJSON[kFTrackedQueryIsActive]
                                       boolValue];
                               NSTimeInterval lastUse =
                                   [queryJSON[kFTrackedQueryLastUse]
                                       doubleValue];

                               FTrackedQuery *trackedQuery =
                                   [[FTrackedQuery alloc]
                                       initWithId:queryId
                                            query:query
                                          lastUse:lastUse
                                         isActive:isActive
                                       isComplete:isComplete];

                               [trackedQueries addObject:trackedQuery];
                           }
                         }];
    FFDebug(@"I-RDB076025", @"Loaded %lu tracked queries in %fms",
            (unsigned long)trackedQueries.count,
            [date timeIntervalSinceNow] * -1000);
    return trackedQueries;
}

- (void)removeTrackedQuery:(NSUInteger)queryId {
    NSDate *start = [NSDate date];
    id<APLevelDBWriteBatch> batch = [self.serverCacheDB beginWriteBatch];
    [batch removeKey:trackedQueryKey(queryId)];
    __block NSUInteger keyCount = 0;
    [self.serverCacheDB
        enumerateKeysWithPrefix:trackedQueryKeysKeyPrefix(queryId)
                     usingBlock:^(NSString *key, BOOL *stop) {
                       [batch removeKey:key];
                       keyCount++;
                     }];

    BOOL success = [batch commit];
    if (!success) {
        FFWarn(@"I-RDB076026", @"Failed to remove tracked query on disk!");
    } else {
        FFDebug(@"I-RDB076027",
                @"Removed query with id %lu (and removed %lu keys) in %fms",
                (unsigned long)queryId, (unsigned long)keyCount,
                [start timeIntervalSinceNow] * -1000);
    }
}

- (void)saveTrackedQuery:(FTrackedQuery *)query {
    NSDate *start = [NSDate date];
    NSDictionary *trackedQuery = @{
        kFTrackedQueryId : @(query.queryId),
        kFTrackedQueryPath : [query.query.path toStringWithTrailingSlash],
        kFTrackedQueryParams : [query.query.params wireProtocolParams],
        kFTrackedQueryLastUse : @(query.lastUse),
        kFTrackedQueryIsComplete : @(query.isComplete),
        kFTrackedQueryIsActive : @(query.isActive)
    };
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:trackedQuery
                                                   options:0
                                                     error:&error];
    NSAssert(data, @"Failed to serialize tracked query (Error: %@)", error);
    [self.serverCacheDB setData:data forKey:trackedQueryKey(query.queryId)];
    FFDebug(@"I-RDB076028", @"Saved tracked query %lu in %fms",
            (unsigned long)query.queryId, [start timeIntervalSinceNow] * -1000);
}

- (void)setTrackedQueryKeys:(NSSet *)keys forQueryId:(NSUInteger)queryId {
    NSDate *start = [NSDate date];
    __block NSUInteger removed = 0;
    __block NSUInteger added = 0;
    id<APLevelDBWriteBatch> batch = [self.serverCacheDB beginWriteBatch];
    NSMutableSet *seenKeys = [NSMutableSet set];
    // First, delete any keys that might be stored and are not part of the
    // current keys
    [self.serverCacheDB
        enumerateKeysWithPrefix:trackedQueryKeysKeyPrefix(queryId)
                      asStrings:^(NSString *dbKey, NSString *actualKey,
                                  BOOL *stop) {
                        if ([keys containsObject:actualKey]) {
                            // Already in DB
                            [seenKeys addObject:actualKey];
                        } else {
                            // Not part of set, delete key
                            [batch removeKey:dbKey];
                            removed++;
                        }
                      }];

    // Next add any keys that are missing in the database
    [keys enumerateObjectsUsingBlock:^(NSString *childKey, BOOL *stop) {
      if (![seenKeys containsObject:childKey]) {
          [batch setString:childKey
                    forKey:trackedQueryKeysKey(queryId, childKey)];
          added++;
      }
    }];
    BOOL success = [batch commit];
    if (!success) {
        FFWarn(@"I-RDB076029", @"Failed to set tracked queries on disk!");
    } else {
        FFDebug(@"I-RDB076030",
                @"Set %lu tracked keys (%lu added, %lu removed) for query %lu "
                @"in %fms",
                (unsigned long)keys.count, (unsigned long)added,
                (unsigned long)removed, (unsigned long)queryId,
                [start timeIntervalSinceNow] * -1000);
    }
}

- (void)updateTrackedQueryKeysWithAddedKeys:(NSSet *)added
                                removedKeys:(NSSet *)removed
                                 forQueryId:(NSUInteger)queryId {
    NSDate *start = [NSDate date];
    id<APLevelDBWriteBatch> batch = [self.serverCacheDB beginWriteBatch];
    [removed enumerateObjectsUsingBlock:^(NSString *key, BOOL *stop) {
      [batch removeKey:trackedQueryKeysKey(queryId, key)];
    }];
    [added enumerateObjectsUsingBlock:^(NSString *key, BOOL *stop) {
      [batch setString:key forKey:trackedQueryKeysKey(queryId, key)];
    }];
    BOOL success = [batch commit];
    if (!success) {
        FFWarn(@"I-RDB076031", @"Failed to update tracked queries on disk!");
    } else {
        FFDebug(@"I-RDB076032",
                @"Added %lu tracked keys, removed %lu for query %lu in %fms",
                (unsigned long)added.count, (unsigned long)removed.count,
                (unsigned long)queryId, [start timeIntervalSinceNow] * -1000);
    }
}

- (NSSet *)trackedQueryKeysForQuery:(NSUInteger)queryId {
    NSDate *start = [NSDate date];
    NSMutableSet *set = [NSMutableSet set];
    [self.serverCacheDB
        enumerateKeysWithPrefix:trackedQueryKeysKeyPrefix(queryId)
                      asStrings:^(NSString *dbKey, NSString *actualKey,
                                  BOOL *stop) {
                        [set addObject:actualKey];
                      }];
    FFDebug(@"I-RDB076033", @"Loaded %lu tracked keys for query %lu in %fms",
            (unsigned long)set.count, (unsigned long)queryId,
            [start timeIntervalSinceNow] * -1000);
    return set;
}

#pragma mark - Internal methods

- (void)removeAllLeafNodesOnPath:(FPath *)path
                           batch:(id<APLevelDBWriteBatch>)batch {
    while (!path.isEmpty) {
        [batch removeKey:serverCacheKey(path)];
        path = [path parent];
    }
    // Make sure to delete any nodes at the root
    [batch removeKey:serverCacheKey([FPath empty])];
}

- (void)removeAllWithPrefix:(NSString *)prefix
                      batch:(id<APLevelDBWriteBatch>)batch
                   database:(APLevelDB *)database {
    assert(prefix != nil);

    [database enumerateKeysWithPrefix:prefix
                           usingBlock:^(NSString *key, BOOL *stop) {
                             [batch removeKey:key];
                           }];
}

#pragma mark - Internal helper methods

- (void)internalSetNestedData:(id)value
                       forKey:(NSString *)key
                    withBatch:(id<APLevelDBWriteBatch>)batch
                      counter:(NSUInteger *)counter {
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        [dictionary enumerateKeysAndObjectsUsingBlock:^(id childKey, id obj,
                                                        BOOL *stop) {
          assert(obj != nil);
          NSString *childPath =
              [NSString stringWithFormat:@"%@%@/", key, childKey];
          [self internalSetNestedData:obj
                               forKey:childPath
                            withBatch:batch
                              counter:counter];
        }];
    } else {
        NSData *data = [self serializePrimitive:value];
        [batch setData:data forKey:key];
        (*counter)++;
    }
}

- (id)internalNestedDataForPath:(FPath *)path {
    NSAssert(path != nil, @"Path was nil!");

    NSString *baseKey = serverCacheKey(path);

    // HACK to make sure iter is freed now to avoid race conditions (if self.db
    // is deleted before iter, you get an access violation).
    @autoreleasepool {
        APLevelDBIterator *iter =
            [APLevelDBIterator iteratorWithLevelDB:self.serverCacheDB];

        [iter seekToKey:baseKey];
        if (iter.key == nil || ![iter.key hasPrefix:baseKey]) {
            // No data.
            return nil;
        } else {
            return [self internalNestedDataFromIterator:iter
                                           andKeyPrefix:baseKey];
        }
    }
}

- (id)internalNestedDataFromIterator:(APLevelDBIterator *)iterator
                        andKeyPrefix:(NSString *)prefix {
    NSString *key = iterator.key;

    if ([key isEqualToString:prefix]) {
        id result = [self deserializePrimitive:iterator.valueAsData];
        [iterator nextKey];
        return result;
    } else {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        while (key != nil && [key hasPrefix:prefix]) {
            NSString *relativePath = [key substringFromIndex:prefix.length];
            NSArray *pathPieces =
                [relativePath componentsSeparatedByString:@"/"];
            assert(pathPieces.count > 0);
            NSString *childName = pathPieces[0];
            NSString *childPath =
                [NSString stringWithFormat:@"%@%@/", prefix, childName];
            id childValue = [self internalNestedDataFromIterator:iterator
                                                    andKeyPrefix:childPath];
            [dict setValue:childValue forKey:childName];

            key = iterator.key;
        }
        return dict;
    }
}

- (NSData *)serializePrimitive:(id)value {
    // HACK: The built-in serialization only works on dicts and arrays.  So we
    // create an array and then strip off the leading / trailing byte (the [ and
    // ]).
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[ value ]
                                                   options:0
                                                     error:&error];
    NSAssert(data, @"Failed to serialize primitive: %@", error);

    return [data subdataWithRange:NSMakeRange(1, data.length - 2)];
}

- (id)fixDoubleParsing:(id)value
    __attribute__((no_sanitize("float-cast-overflow"))) {
    if ([value isKindOfClass:[NSDecimalNumber class]]) {
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
        NSDecimal original = [(NSDecimalNumber *)value decimalValue];
        NSDecimal rounded;
        NSDecimalRound(&rounded, &original, 0, NSRoundPlain);
        if (NSDecimalCompare(&original, &rounded) != NSOrderedSame) {
            NSString *doubleString = [value stringValue];
            return [NSNumber numberWithDouble:[doubleString doubleValue]];
        } else {
            return [NSNumber numberWithLongLong:[value longLongValue]];
        }
    } else if ([value isKindOfClass:[NSNumber class]]) {
        // The parser for double values in JSONSerialization at the root takes
        // some short-cuts and delivers wrong results (wrong rounding) for some
        // double values, including 2.47. Because we use the exact bytes for
        // hashing on the server this will lead to hash mismatches. The parser
        // of NSNumber seems to be more in line with what the server expects, so
        // we use that here
        CFNumberType type = CFNumberGetType((CFNumberRef)value);
        if (type == kCFNumberDoubleType || type == kCFNumberFloatType) {
            // The NSJSON parser returns all numbers as double values, even
            // those that contain no exponent. To make sure that the String
            // conversion below doesn't unexpectedly reduce precision, we make
            // sure that our number is indeed not an integer.
            if ((double)(int64_t)[value doubleValue] != [value doubleValue]) {
                NSString *doubleString = [value stringValue];
                return [NSNumber numberWithDouble:[doubleString doubleValue]];
            } else {
                return [NSNumber numberWithLongLong:[value longLongValue]];
            }
        }
    }
    return value;
}

- (id)deserializePrimitive:(NSData *)data {
    NSError *error = nil;
    id result =
        [NSJSONSerialization JSONObjectWithData:data
                                        options:NSJSONReadingAllowFragments
                                          error:&error];
    if (result != nil) {
        return [self fixDoubleParsing:result];
    } else {
        if (error.code == kFNanFailureCode) {
            FFWarn(@"I-RDB076034",
                   @"Failed to load primitive %@, likely because doubles where "
                   @"out of range (Error: %@)",
                   [[NSString alloc] initWithData:data
                                         encoding:NSUTF8StringEncoding],
                   error);
            return [NSNull null];
        } else {
            [NSException raise:NSInternalInconsistencyException
                        format:@"Failed to deserialiaze primitive: %@", error];
            return nil;
        }
    }
}

+ (void)ensureDir:(NSString *)path markAsDoNotBackup:(BOOL)markAsDoNotBackup {
    NSError *error;
    BOOL success =
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
    if (!success) {
        @throw [NSException
            exceptionWithName:@"FailedToCreatePersistenceDir"
                       reason:@"Failed to create persistence directory."
                     userInfo:@{@"path" : path}];
    }

    if (markAsDoNotBackup) {
        NSURL *firebaseDirURL = [NSURL fileURLWithPath:path];
        success = [firebaseDirURL setResourceValue:@YES
                                            forKey:NSURLIsExcludedFromBackupKey
                                             error:&error];
        if (!success) {
            FFWarn(
                @"I-RDB076035",
                @"Failed to mark firebase database folder as do not backup: %@",
                error);
            [NSException raise:@"Error marking as do not backup"
                        format:@"Failed to mark folder %@ as do not backup",
                               firebaseDirURL];
        }
    }
}

@end
