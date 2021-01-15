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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDataSnapshot_Private.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabase_Private.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRMutableData_Private.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRTransactionResult_Private.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/FListenProvider.h"
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/Core/FRepo.h"
#import "FirebaseDatabase/Sources/Core/FRepoManager.h"
#import "FirebaseDatabase/Sources/Core/FRepo_Private.h"
#import "FirebaseDatabase/Sources/Core/FServerValues.h"
#import "FirebaseDatabase/Sources/Core/FSnapshotHolder.h"
#import "FirebaseDatabase/Sources/Core/FSyncTree.h"
#import "FirebaseDatabase/Sources/Core/FWriteRecord.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FTree.h"
#import "FirebaseDatabase/Sources/Core/View/FEventRaiser.h"
#import "FirebaseDatabase/Sources/Core/View/FEventRegistration.h"
#import "FirebaseDatabase/Sources/Core/View/FValueEventRegistration.h"
#import "FirebaseDatabase/Sources/FClock.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Sources/Persistence/FCachePolicy.h"
#import "FirebaseDatabase/Sources/Persistence/FLevelDBStorageEngine.h"
#import "FirebaseDatabase/Sources/Persistence/FPersistenceManager.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDataSnapshot.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRMutableData.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRTransactionResult.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/FAtomicNumber.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleNodePath.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleSetIdPath.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleTransaction.h"
#import <dlfcn.h>

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif

@interface FRepo ()

@property(nonatomic, strong) FOffsetClock *serverClock;
@property(nonatomic, strong) FPersistenceManager *persistenceManager;
@property(nonatomic, strong) FIRDatabase *database;
@property(nonatomic, strong, readwrite) FAuthenticationManager *auth;
@property(nonatomic, strong) FSyncTree *infoSyncTree;
@property(nonatomic) NSInteger writeIdCounter;
@property(nonatomic) BOOL hijackHash;
@property(nonatomic, strong) FTree *transactionQueueTree;
@property(nonatomic) BOOL loggedTransactionPersistenceWarning;

/**
 * Test only. For load testing the server.
 */
@property(nonatomic, strong) id (^interceptServerDataCallback)
    (NSString *pathString, id data);
@end

@implementation FRepo

- (id)initWithRepoInfo:(FRepoInfo *)info
                config:(FIRDatabaseConfig *)config
              database:(FIRDatabase *)database {
    self = [super init];
    if (self) {
        self.repoInfo = info;
        self.config = config;
        self.database = database;

        // Access can occur outside of shared queue, so the clock needs to be
        // initialized here
        self.serverClock =
            [[FOffsetClock alloc] initWithClock:[FSystemClock clock] offset:0];

        self.connection = [[FPersistentConnection alloc]
            initWithRepoInfo:self.repoInfo
               dispatchQueue:[FIRDatabaseQuery sharedQueue]
                      config:self.config];

        // Needs to be called before authentication manager is instantiated
        self.eventRaiser =
            [[FEventRaiser alloc] initWithQueue:self.config.callbackQueue];

        dispatch_async([FIRDatabaseQuery sharedQueue], ^{
          [self deferredInit];
        });
    }
    return self;
}

- (void)deferredInit {
    // TODO: cleanup on dealloc
    __weak FRepo *weakSelf = self;
    [self.config.authTokenProvider listenForTokenChanges:^(NSString *token) {
      [weakSelf.connection refreshAuthToken:token];
    }];

    // Open connection now so that by the time we are connected the deferred
    // init has run This relies on the fact that all callbacks run on repos
    // queue
    self.connection.delegate = self;
    [self.connection open];

    self.dataUpdateCount = 0;
    self.rangeMergeUpdateCount = 0;
    self.interceptServerDataCallback = nil;

    if (self.config.persistenceEnabled) {
        NSString *repoHashString =
            [NSString stringWithFormat:@"%@_%@", self.repoInfo.host,
                                       self.repoInfo.namespace];
        NSString *persistencePrefix =
            [NSString stringWithFormat:@"%@/%@", self.config.sessionIdentifier,
                                       repoHashString];

        id<FCachePolicy> cachePolicy = [[FLRUCachePolicy alloc]
            initWithMaxSize:self.config.persistenceCacheSizeBytes];

        id<FStorageEngine> engine;
        if (self.config.forceStorageEngine != nil) {
            engine = self.config.forceStorageEngine;
        } else {
            FLevelDBStorageEngine *levelDBEngine =
                [[FLevelDBStorageEngine alloc] initWithPath:persistencePrefix];
            // We need the repo info to run the legacy migration. Future
            // migrations will be managed by the database itself Remove this
            // once we are confident that no-one is using legacy migration
            // anymore...
            [levelDBEngine runLegacyMigration:self.repoInfo];
            engine = levelDBEngine;
        }

        self.persistenceManager =
            [[FPersistenceManager alloc] initWithStorageEngine:engine
                                                   cachePolicy:cachePolicy];
    } else {
        self.persistenceManager = nil;
    }

    [self initTransactions];

    // A list of data pieces and paths to be set when this client disconnects
    self.onDisconnect = [[FSparseSnapshotTree alloc] init];
    self.infoData = [[FSnapshotHolder alloc] init];

    FListenProvider *infoListenProvider = [[FListenProvider alloc] init];
    infoListenProvider.startListening =
        ^(FQuerySpec *query, NSNumber *tagId, id<FSyncTreeHash> hash,
          fbt_nsarray_nsstring onComplete) {
          NSArray *infoEvents = @[];
          FRepo *strongSelf = weakSelf;
          id<FNode> node = [strongSelf.infoData getNode:query.path];
          // This is possibly a hack, but we have different semantics for .info
          // endpoints. We don't raise null events on initial data...
          if (![node isEmpty]) {
              infoEvents =
                  [strongSelf.infoSyncTree applyServerOverwriteAtPath:query.path
                                                              newData:node];
              [strongSelf.eventRaiser raiseCallback:^{
                onComplete(kFWPResponseForActionStatusOk);
              }];
          }
          return infoEvents;
        };
    infoListenProvider.stopListening = ^(FQuerySpec *query, NSNumber *tagId) {
    };
    self.infoSyncTree =
        [[FSyncTree alloc] initWithListenProvider:infoListenProvider];

    FListenProvider *serverListenProvider = [[FListenProvider alloc] init];
    serverListenProvider.startListening =
        ^(FQuerySpec *query, NSNumber *tagId, id<FSyncTreeHash> hash,
          fbt_nsarray_nsstring onComplete) {
          [weakSelf.connection listen:query
                                tagId:tagId
                                 hash:hash
                           onComplete:^(NSString *status) {
                             NSArray *events = onComplete(status);
                             [weakSelf.eventRaiser raiseEvents:events];
                           }];
          // No synchronous events for network-backed sync trees
          return @[];
        };
    serverListenProvider.stopListening = ^(FQuerySpec *query, NSNumber *tag) {
      [weakSelf.connection unlisten:query tagId:tag];
    };
    self.serverSyncTree =
        [[FSyncTree alloc] initWithPersistenceManager:self.persistenceManager
                                       listenProvider:serverListenProvider];

    [self restoreWrites];

    [self updateInfo:kDotInfoConnected withValue:@NO];

    [self setupNotifications];
}

- (void)restoreWrites {
    NSArray *writes = self.persistenceManager.userWrites;

    NSDictionary *serverValues =
        [FServerValues generateServerValues:self.serverClock];
    __block NSInteger lastWriteId = NSIntegerMin;
    [writes enumerateObjectsUsingBlock:^(FWriteRecord *write, NSUInteger idx,
                                         BOOL *stop) {
      NSInteger writeId = write.writeId;
      fbt_void_nsstring_nsstring callback =
          ^(NSString *status, NSString *errorReason) {
            [self warnIfWriteFailedAtPath:write.path
                                   status:status
                                  message:@"Persisted write"];
            [self ackWrite:writeId
                rerunTransactionsAtPath:write.path
                                 status:status];
          };
      if (lastWriteId >= writeId) {
          [NSException raise:NSInternalInconsistencyException
                      format:@"Restored writes were not in order!"];
      }
      lastWriteId = writeId;
      self.writeIdCounter = writeId + 1;

      if ([write isOverwrite]) {
          FFLog(@"I-RDB038001", @"Restoring overwrite with id %ld",
                (long)write.writeId);
          [self.connection putData:[write.overwrite valForExport:YES]
                           forPath:[write.path toString]
                          withHash:nil
                      withCallback:callback];
          id<FNode> resolved =
              [FServerValues resolveDeferredValueSnapshot:write.overwrite
                                             withSyncTree:self.serverSyncTree
                                                   atPath:write.path
                                             serverValues:serverValues];
          [self.serverSyncTree applyUserOverwriteAtPath:write.path
                                                newData:resolved
                                                writeId:writeId
                                              isVisible:YES];
      } else {
          FFLog(@"I-RDB038002", @"Restoring merge with id %ld",
                (long)write.writeId);
          [self.connection mergeData:[write.merge valForExport:YES]
                             forPath:[write.path toString]
                        withCallback:callback];
          FCompoundWrite *resolved = [FServerValues
              resolveDeferredValueCompoundWrite:write.merge
                                   withSyncTree:self.serverSyncTree
                                         atPath:write.path
                                   serverValues:serverValues];
          [self.serverSyncTree applyUserMergeAtPath:write.path
                                    changedChildren:resolved
                                            writeId:writeId];
      }
    }];
}

- (NSString *)name {
    return self.repoInfo.namespace;
}

- (NSString *)description {
    return [self.repoInfo description];
}

- (void)interrupt {
    [self.connection interruptForReason:kFInterruptReasonRepoInterrupt];
}

- (void)resume {
    [self.connection resumeForReason:kFInterruptReasonRepoInterrupt];
}

// NOTE: Typically if you're calling this, you should be in an @autoreleasepool
// block to make sure that ARC kicks in and cleans up things no longer
// referenced (i.e. pendingPutsDB).
- (void)dispose {
    [self.connection interruptForReason:kFInterruptReasonRepoInterrupt];

    // We need to nil out any references to LevelDB, to make sure the
    // LevelDB exclusive locks are released.
    [self.persistenceManager close];
}

- (NSInteger)nextWriteId {
    return self->_writeIdCounter++;
}

- (NSTimeInterval)serverTime {
    return [self.serverClock currentTime];
}

- (void)set:(FPath *)path
        withNode:(id<FNode>)node
    withCallback:(fbt_void_nserror_ref)onComplete {
    id value = [node valForExport:YES];
    FFLog(@"I-RDB038003", @"Setting: %@ with %@ pri: %@", [path toString],
          [value description], [[node getPriority] val]);

    // TODO: Optimize this behavior to either (a) store flag to skip resolving
    // where possible and / or (b) store unresolved paths on JSON parse
    NSDictionary *serverValues =
        [FServerValues generateServerValues:self.serverClock];
    id<FNode> existing = [self.serverSyncTree calcCompleteEventCacheAtPath:path
                                                           excludeWriteIds:@[]];
    id<FNode> newNode =
        [FServerValues resolveDeferredValueSnapshot:node
                                       withExisting:existing
                                       serverValues:serverValues];

    NSInteger writeId = [self nextWriteId];
    [self.persistenceManager saveUserOverwrite:node
                                        atPath:path
                                       writeId:writeId];
    NSArray *events = [self.serverSyncTree applyUserOverwriteAtPath:path
                                                            newData:newNode
                                                            writeId:writeId
                                                          isVisible:YES];
    [self.eventRaiser raiseEvents:events];

    [self.connection putData:value
                     forPath:[path toString]
                    withHash:nil
                withCallback:^(NSString *status, NSString *errorReason) {
                  [self warnIfWriteFailedAtPath:path
                                         status:status
                                        message:@"setValue: or removeValue:"];
                  [self ackWrite:writeId
                      rerunTransactionsAtPath:path
                                       status:status];
                  [self callOnComplete:onComplete
                            withStatus:status
                           errorReason:errorReason
                               andPath:path];
                }];

    FPath *affectedPath = [self abortTransactionsAtPath:path
                                                  error:kFTransactionSet];
    [self rerunTransactionsForPath:affectedPath];
}

- (void)update:(FPath *)path
       withNodes:(FCompoundWrite *)nodes
    withCallback:(fbt_void_nserror_ref)callback {
    NSDictionary *values = [nodes valForExport:YES];

    FFLog(@"I-RDB038004", @"Updating: %@ with %@", [path toString],
          [values description]);
    NSDictionary *serverValues =
        [FServerValues generateServerValues:self.serverClock];
    FCompoundWrite *resolved =
        [FServerValues resolveDeferredValueCompoundWrite:nodes
                                            withSyncTree:self.serverSyncTree
                                                  atPath:path
                                            serverValues:serverValues];

    if (!resolved.isEmpty) {
        NSInteger writeId = [self nextWriteId];
        [self.persistenceManager saveUserMerge:nodes
                                        atPath:path
                                       writeId:writeId];
        NSArray *events = [self.serverSyncTree applyUserMergeAtPath:path
                                                    changedChildren:resolved
                                                            writeId:writeId];
        [self.eventRaiser raiseEvents:events];

        [self.connection mergeData:values
                           forPath:[path description]
                      withCallback:^(NSString *status, NSString *errorReason) {
                        [self warnIfWriteFailedAtPath:path
                                               status:status
                                              message:@"updateChildValues:"];
                        [self ackWrite:writeId
                            rerunTransactionsAtPath:path
                                             status:status];
                        [self callOnComplete:callback
                                  withStatus:status
                                 errorReason:errorReason
                                     andPath:path];
                      }];

        [nodes enumerateWrites:^(FPath *childPath, id<FNode> node, BOOL *stop) {
          FPath *pathFromRoot = [path child:childPath];
          FFLog(@"I-RDB038005", @"Cancelling transactions at path: %@",
                pathFromRoot);
          FPath *affectedPath = [self abortTransactionsAtPath:pathFromRoot
                                                        error:kFTransactionSet];
          [self rerunTransactionsForPath:affectedPath];
        }];
    } else {
        FFLog(@"I-RDB038006", @"update called with empty data. Doing nothing");
        // Do nothing, just call the callback
        [self callOnComplete:callback
                  withStatus:@"ok"
                 errorReason:nil
                     andPath:path];
    }
}

- (void)onDisconnectCancel:(FPath *)path
              withCallback:(fbt_void_nserror_ref)callback {
    [self.connection
        onDisconnectCancelPath:path
                  withCallback:^(NSString *status, NSString *errorReason) {
                    BOOL success =
                        [status isEqualToString:kFWPResponseForActionStatusOk];
                    if (success) {
                        [self.onDisconnect forgetPath:path];
                    } else {
                        FFLog(@"I-RDB038007",
                              @"cancelDisconnectOperations: at %@ failed: %@",
                              path, status);
                    }

                    [self callOnComplete:callback
                              withStatus:status
                             errorReason:errorReason
                                 andPath:path];
                  }];
}

- (void)onDisconnectSet:(FPath *)path
               withNode:(id<FNode>)node
           withCallback:(fbt_void_nserror_ref)callback {
    [self.connection
        onDisconnectPutData:[node valForExport:YES]
                    forPath:path
               withCallback:^(NSString *status, NSString *errorReason) {
                 BOOL success =
                     [status isEqualToString:kFWPResponseForActionStatusOk];
                 if (success) {
                     [self.onDisconnect rememberData:node onPath:path];
                 } else {
                     FFWarn(@"I-RDB038008",
                            @"onDisconnectSetValue: or "
                            @"onDisconnectRemoveValue: at %@ failed: %@",
                            path, status);
                 }

                 [self callOnComplete:callback
                           withStatus:status
                          errorReason:errorReason
                              andPath:path];
               }];
}

- (void)onDisconnectUpdate:(FPath *)path
                 withNodes:(FCompoundWrite *)nodes
              withCallback:(fbt_void_nserror_ref)callback {
    if (!nodes.isEmpty) {
        NSDictionary *values = [nodes valForExport:YES];

        [self.connection
            onDisconnectMergeData:values
                          forPath:path
                     withCallback:^(NSString *status, NSString *errorReason) {
                       BOOL success = [status
                           isEqualToString:kFWPResponseForActionStatusOk];
                       if (success) {
                           [nodes enumerateWrites:^(FPath *relativePath,
                                                    id<FNode> nodeUnresolved,
                                                    BOOL *stop) {
                             FPath *childPath = [path child:relativePath];
                             [self.onDisconnect rememberData:nodeUnresolved
                                                      onPath:childPath];
                           }];
                       } else {
                           FFWarn(@"I-RDB038009",
                                  @"onDisconnectUpdateChildValues: at %@ "
                                  @"failed %@",
                                  path, status);
                       }

                       [self callOnComplete:callback
                                 withStatus:status
                                errorReason:errorReason
                                    andPath:path];
                     }];
    } else {
        // Do nothing, just call the callback
        [self callOnComplete:callback
                  withStatus:@"ok"
                 errorReason:nil
                     andPath:path];
    }
}

- (void)purgeOutstandingWrites {
    FFLog(@"I-RDB038010", @"Purging outstanding writes");
    NSArray *events = [self.serverSyncTree removeAllWrites];
    [self.eventRaiser raiseEvents:events];
    // Abort any transactions
    [self abortTransactionsAtPath:[FPath empty] error:kFErrorWriteCanceled];
    // Remove outstanding writes from connection
    [self.connection purgeOutstandingWrites];
}

- (void)getData:(FIRDatabaseQuery *)query
    withCompletionBlock:
        (void (^_Nonnull)(NSError *__nullable error,
                          FIRDataSnapshot *__nullable snapshot))block {
    FQuerySpec *querySpec = [query querySpec];
    id<FNode> node =
        [self.serverSyncTree calcCompleteEventCacheAtPath:querySpec.path
                                          excludeWriteIds:@[]];
    if (![node isEmpty]) {
        block(nil, [[FIRDataSnapshot alloc]
                       initWithRef:query.ref
                       indexedNode:[FIndexedNode
                                       indexedNodeWithNode:node
                                                     index:querySpec.index]]);
        return;
    }
    [self.persistenceManager setQueryActive:querySpec];
    [self.connection
        getDataAtPath:[query.path toString]
           withParams:querySpec.params.wireProtocolParams
         withCallback:^(NSString *status, id data, NSString *errorReason) {
           id<FNode> node;
           if (![status isEqualToString:kFWPResponseForActionStatusOk]) {
               FFLog(@"I-RDB038024",
                     @"getValue for query %@ falling back to disk cache",
                     [querySpec.path toString]);
               FIndexedNode *node =
                   [self.serverSyncTree persistenceServerCache:querySpec];
               if (node == nil) {
                   NSDictionary *errorDict = @{
                       NSLocalizedFailureReasonErrorKey : errorReason,
                       NSLocalizedDescriptionKey : [NSString
                           stringWithFormat:
                               @"Unable to get latest value for query %@, "
                               @"client offline with no active listeners "
                               @"and no matching disk cache entries",
                               querySpec]
                   };
                   block([NSError errorWithDomain:kFirebaseCoreErrorDomain
                                             code:1
                                         userInfo:errorDict],
                         nil);
                   return;
               }
               block(nil, [[FIRDataSnapshot alloc] initWithRef:query.ref
                                                   indexedNode:node]);
           } else {
               node = [FSnapshotUtilities nodeFrom:data];
               [self.eventRaiser
                   raiseEvents:[self.serverSyncTree
                                   applyServerOverwriteAtPath:[query path]
                                                      newData:node]];
               block(nil,
                     [[FIRDataSnapshot alloc]
                         initWithRef:query.ref
                         indexedNode:[FIndexedNode
                                         indexedNodeWithNode:node
                                                       index:querySpec.index]]);
           }
           [self.persistenceManager setQueryInactive:querySpec];
         }];
}

- (void)addEventRegistration:(id<FEventRegistration>)eventRegistration
                    forQuery:(FQuerySpec *)query {
    NSArray *events = nil;
    if ([[query.path getFront] isEqualToString:kDotInfoPrefix]) {
        events = [self.infoSyncTree addEventRegistration:eventRegistration
                                                forQuery:query];
    } else {
        events = [self.serverSyncTree addEventRegistration:eventRegistration
                                                  forQuery:query];
    }
    [self.eventRaiser raiseEvents:events];
}

- (void)removeEventRegistration:(id<FEventRegistration>)eventRegistration
                       forQuery:(FQuerySpec *)query {
    // These are guaranteed not to raise events, since we're not passing in a
    // cancelError. However we can future-proof a little bit by handling the
    // return values anyways.
    FFLog(@"I-RDB038011", @"Removing event registration with hande: %lu",
          (unsigned long)eventRegistration.handle);
    NSArray *events = nil;
    if ([[query.path getFront] isEqualToString:kDotInfoPrefix]) {
        events = [self.infoSyncTree removeEventRegistration:eventRegistration
                                                   forQuery:query
                                                cancelError:nil];
    } else {
        events = [self.serverSyncTree removeEventRegistration:eventRegistration
                                                     forQuery:query
                                                  cancelError:nil];
    }
    [self.eventRaiser raiseEvents:events];
}

- (void)keepQuery:(FQuerySpec *)query synced:(BOOL)synced {
    NSAssert(![[query.path getFront] isEqualToString:kDotInfoPrefix],
             @"Can't keep .info tree synced!");
    [self.serverSyncTree keepQuery:query synced:synced];
}

- (void)updateInfo:(NSString *)pathString withValue:(id)value {
    // hack to make serverTimeOffset available in a threadsafe way. Property is
    // marked as atomic
    if ([pathString isEqualToString:kDotInfoServerTimeOffset]) {
        NSTimeInterval offset = [(NSNumber *)value doubleValue] / 1000.0;
        self.serverClock =
            [[FOffsetClock alloc] initWithClock:[FSystemClock clock]
                                         offset:offset];
    }

    FPath *path = [[FPath alloc]
        initWith:[NSString
                     stringWithFormat:@"%@/%@", kDotInfoPrefix, pathString]];
    id<FNode> newNode = [FSnapshotUtilities nodeFrom:value];
    [self.infoData updateSnapshot:path withNewSnapshot:newNode];
    NSArray *events = [self.infoSyncTree applyServerOverwriteAtPath:path
                                                            newData:newNode];
    [self.eventRaiser raiseEvents:events];
}

- (void)callOnComplete:(fbt_void_nserror_ref)onComplete
            withStatus:(NSString *)status
           errorReason:(NSString *)errorReason
               andPath:(FPath *)path {
    if (onComplete) {
        FIRDatabaseReference *ref =
            [[FIRDatabaseReference alloc] initWithRepo:self path:path];
        BOOL statusOk = [status isEqualToString:kFWPResponseForActionStatusOk];
        NSError *err = nil;
        if (!statusOk) {
            err = [FUtilities errorForStatus:status andReason:errorReason];
        }
        [self.eventRaiser raiseCallback:^{
          onComplete(err, ref);
        }];
    }
}

- (void)ackWrite:(NSInteger)writeId
    rerunTransactionsAtPath:(FPath *)path
                     status:(NSString *)status {
    if ([status isEqualToString:kFErrorWriteCanceled]) {
        // This write was already removed, we just need to ignore it...
    } else {
        BOOL success = [status isEqualToString:kFWPResponseForActionStatusOk];
        NSArray *clearEvents =
            [self.serverSyncTree ackUserWriteWithWriteId:writeId
                                                  revert:!success
                                                 persist:YES
                                                   clock:self.serverClock];
        if ([clearEvents count] > 0) {
            [self rerunTransactionsForPath:path];
        }
        [self.eventRaiser raiseEvents:clearEvents];
    }
}

- (void)warnIfWriteFailedAtPath:(FPath *)path
                         status:(NSString *)status
                        message:(NSString *)message {
    if (!([status isEqualToString:kFWPResponseForActionStatusOk] ||
          [status isEqualToString:kFErrorWriteCanceled])) {
        FFWarn(@"I-RDB038012", @"%@ at %@ failed: %@", message, path, status);
    }
}

#pragma mark -
#pragma mark FPersistentConnectionDelegate methods

- (void)onDataUpdate:(FPersistentConnection *)fpconnection
             forPath:(NSString *)pathString
             message:(id)data
             isMerge:(BOOL)isMerge
               tagId:(NSNumber *)tagId {
    FFLog(@"I-RDB038013", @"onDataUpdateForPath: %@ withMessage: %@",
          pathString, data);

    // For testing.
    self.dataUpdateCount++;

    FPath *path = [[FPath alloc] initWith:pathString];
    data = self.interceptServerDataCallback
               ? self.interceptServerDataCallback(pathString, data)
               : data;
    NSArray *events = nil;

    if (tagId != nil) {
        if (isMerge) {
            NSDictionary *message = data;
            FCompoundWrite *taggedChildren =
                [FCompoundWrite compoundWriteWithValueDictionary:message];
            events =
                [self.serverSyncTree applyTaggedQueryMergeAtPath:path
                                                 changedChildren:taggedChildren
                                                           tagId:tagId];
        } else {
            id<FNode> taggedSnap = [FSnapshotUtilities nodeFrom:data];
            events =
                [self.serverSyncTree applyTaggedQueryOverwriteAtPath:path
                                                             newData:taggedSnap
                                                               tagId:tagId];
        }
    } else if (isMerge) {
        NSDictionary *message = data;
        FCompoundWrite *changedChildren =
            [FCompoundWrite compoundWriteWithValueDictionary:message];
        events = [self.serverSyncTree applyServerMergeAtPath:path
                                             changedChildren:changedChildren];
    } else {
        id<FNode> snap = [FSnapshotUtilities nodeFrom:data];
        events = [self.serverSyncTree applyServerOverwriteAtPath:path
                                                         newData:snap];
    }

    if ([events count] > 0) {
        // Since we have a listener outstanding for each transaction, receiving
        // any events is a proxy for some change having occurred.
        [self rerunTransactionsForPath:path];
    }

    [self.eventRaiser raiseEvents:events];
}

- (void)onRangeMerge:(NSArray *)ranges
             forPath:(NSString *)pathString
               tagId:(NSNumber *)tag {
    FFLog(@"I-RDB038014", @"onRangeMerge: %@ => %@", pathString, ranges);

    // For testing
    self.rangeMergeUpdateCount++;

    FPath *path = [[FPath alloc] initWith:pathString];
    NSArray *events;
    if (tag != nil) {
        events = [self.serverSyncTree applyTaggedServerRangeMergeAtPath:path
                                                                updates:ranges
                                                                  tagId:tag];
    } else {
        events = [self.serverSyncTree applyServerRangeMergeAtPath:path
                                                          updates:ranges];
    }
    if (events.count > 0) {
        // Since we have a listener outstanding for each transaction, receiving
        // any events is a proxy for some change having occurred.
        [self rerunTransactionsForPath:path];
    }

    [self.eventRaiser raiseEvents:events];
}

- (void)onConnect:(FPersistentConnection *)fpconnection {
    [self updateInfo:kDotInfoConnected withValue:@YES];
}

- (void)onDisconnect:(FPersistentConnection *)fpconnection {
    [self updateInfo:kDotInfoConnected withValue:@NO];
    [self runOnDisconnectEvents];
}

- (void)onServerInfoUpdate:(FPersistentConnection *)fpconnection
                   updates:(NSDictionary *)updates {
    for (NSString *key in updates) {
        id val = [updates objectForKey:key];
        [self updateInfo:key withValue:val];
    }
}

- (void)setupNotifications {
    NSString *const *backgroundConstant = (NSString *const *)dlsym(
        RTLD_DEFAULT, "UIApplicationDidEnterBackgroundNotification");
    if (backgroundConstant) {
        FFLog(@"I-RDB038015", @"Registering for background notification.");
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(didEnterBackground)
                   name:*backgroundConstant
                 object:nil];
    } else {
        FFLog(@"I-RDB038016",
              @"Skipped registering for background notification.");
    }
}

- (void)didEnterBackground {
    if (!self.config.persistenceEnabled)
        return;

// Targetted compilation is ONLY for testing. UIKit is weak-linked in actual
// release build.
#if TARGET_OS_IOS || TARGET_OS_TV
    // The idea is to wait until any outstanding sets get written to disk. Since
    // the sets might still be in our dispatch queue, we wait for the dispatch
    // queue to catch up and for persistence to catch up. This may be
    // undesirable though.  The dispatch queue might just be processing a bunch
    // of incoming data or something.  We might want to keep track of whether
    // there are any unpersisted sets or something.
    FFLog(@"I-RDB038017",
          @"Entering background.  Starting background task to finish work.");
    Class uiApplicationClass = NSClassFromString(@"UIApplication");
    assert(uiApplicationClass); // If we are here, we should be on iOS and
                                // UIApplication should be available.

    UIApplication *application = [uiApplicationClass sharedApplication];
    __block UIBackgroundTaskIdentifier bgTask =
        [application beginBackgroundTaskWithExpirationHandler:^{
          [application endBackgroundTask:bgTask];
        }];

    NSDate *start = [NSDate date];
    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
      NSTimeInterval finishTime = [start timeIntervalSinceNow] * -1;
      FFLog(@"I-RDB038018", @"Background task completed.  Queue time: %f",
            finishTime);
      [application endBackgroundTask:bgTask];
    });
#endif
}

#pragma mark -
#pragma mark Internal methods

/**
 * Applies all the changes stored up in the onDisconnect tree
 */
- (void)runOnDisconnectEvents {
    FFLog(@"I-RDB038019", @"Running onDisconnectEvents");
    NSDictionary *serverValues =
        [FServerValues generateServerValues:self.serverClock];
    NSMutableArray *events = [[NSMutableArray alloc] init];

    [self.onDisconnect
        forEachTreeAtPath:[FPath empty]
                       do:^(FPath *path, id<FNode> node) {
                         id<FNode> existing = [self.serverSyncTree
                             calcCompleteEventCacheAtPath:path
                                          excludeWriteIds:@[]];
                         id<FNode> resolved = [FServerValues
                             resolveDeferredValueSnapshot:node
                                             withExisting:existing
                                             serverValues:serverValues];
                         [events addObjectsFromArray:
                                     [self.serverSyncTree
                                         applyServerOverwriteAtPath:path
                                                            newData:resolved]];
                         FPath *affectedPath =
                             [self abortTransactionsAtPath:path
                                                     error:kFTransactionSet];
                         [self rerunTransactionsForPath:affectedPath];
                       }];

    self.onDisconnect = [[FSparseSnapshotTree alloc] init];
    [self.eventRaiser raiseEvents:events];
}

- (NSDictionary *)dumpListens {
    return [self.connection dumpListens];
}

#pragma mark -
#pragma mark Transactions

/**
 * Setup the transaction data structures
 */
- (void)initTransactions {
    self.transactionQueueTree = [[FTree alloc] init];
    self.hijackHash = NO;
    self.loggedTransactionPersistenceWarning = NO;
}

/**
 * Creates a new transaction, add its to the transactions we're tracking, and
 * sends it to the server if possible
 */
- (void)startTransactionOnPath:(FPath *)path
                        update:(fbt_transactionresult_mutabledata)update
                    onComplete:(fbt_void_nserror_bool_datasnapshot)onComplete
               withLocalEvents:(BOOL)applyLocally {
    if (self.config.persistenceEnabled &&
        !self.loggedTransactionPersistenceWarning) {
        self.loggedTransactionPersistenceWarning = YES;
        FFInfo(@"I-RDB038020",
               @"runTransactionBlock: usage detected while persistence is "
               @"enabled. Please be aware that transactions "
               @"*will not* be persisted across app restarts. "
               @"See "
               @"https://www.firebase.com/docs/ios/guide/"
               @"offline-capabilities.html#section-handling-transactions-"
               @"offline for more details.");
    }

    FIRDatabaseReference *watchRef =
        [[FIRDatabaseReference alloc] initWithRepo:self path:path];
    // make sure we're listening on this node
    // Note: we can't do this asynchronously. To preserve event ordering, it has
    // to be done in this block. This is ok, this block is guaranteed to be our
    // own event loop
    NSUInteger handle = [[FUtilities LUIDGenerator] integerValue];
    fbt_void_datasnapshot cb = ^(FIRDataSnapshot *snapshot) {
    };
    FValueEventRegistration *registration =
        [[FValueEventRegistration alloc] initWithRepo:self
                                               handle:handle
                                             callback:cb
                                       cancelCallback:nil];
    [watchRef.repo addEventRegistration:registration
                               forQuery:watchRef.querySpec];
    fbt_void_void unwatcher = ^{
      [watchRef removeObserverWithHandle:handle];
    };

    // Save all the data that represents this transaction
    FTupleTransaction *transaction = [[FTupleTransaction alloc] init];
    transaction.path = path;
    transaction.update = update;
    transaction.onComplete = onComplete;
    transaction.status = FTransactionInitializing;
    transaction.order = [FUtilities LUIDGenerator];
    transaction.applyLocally = applyLocally;
    transaction.retryCount = 0;
    transaction.unwatcher = unwatcher;
    transaction.currentWriteId = nil;
    transaction.currentInputSnapshot = nil;
    transaction.currentOutputSnapshotRaw = nil;
    transaction.currentOutputSnapshotResolved = nil;

    // Run transaction initially
    id<FNode> currentState = [self latestStateAtPath:path excludeWriteIds:nil];
    transaction.currentInputSnapshot = currentState;
    FIRMutableData *mutableCurrent =
        [[FIRMutableData alloc] initWithNode:currentState];
    FIRTransactionResult *result = transaction.update(mutableCurrent);

    if (!result.isSuccess) {
        // Abort the transaction
        transaction.unwatcher();
        transaction.currentOutputSnapshotRaw = nil;
        transaction.currentOutputSnapshotResolved = nil;
        if (transaction.onComplete) {
            FIRDatabaseReference *ref =
                [[FIRDatabaseReference alloc] initWithRepo:self
                                                      path:transaction.path];
            FIndexedNode *indexedNode = [FIndexedNode
                indexedNodeWithNode:transaction.currentInputSnapshot];
            FIRDataSnapshot *snap =
                [[FIRDataSnapshot alloc] initWithRef:ref
                                         indexedNode:indexedNode];
            [self.eventRaiser raiseCallback:^{
              transaction.onComplete(nil, NO, snap);
            }];
        }
    } else {
        // Note: different from js. We don't need to validate, FIRMutableData
        // does validation. We also don't have to worry about priorities. Just
        // mark as run and add to queue.
        transaction.status = FTransactionRun;
        FTree *queueNode = [self.transactionQueueTree subTree:transaction.path];
        NSMutableArray *nodeQueue = [queueNode getValue];
        if (nodeQueue == nil) {
            nodeQueue = [[NSMutableArray alloc] init];
        }
        [nodeQueue addObject:transaction];
        [queueNode setValue:nodeQueue];

        // Update visibleData and raise events
        // Note: We intentionally raise events after updating all of our
        // transaction state, since the user could start new transactions from
        // the event callbacks
        NSDictionary *serverValues =
            [FServerValues generateServerValues:self.serverClock];
        id<FNode> newValUnresolved = [result.update nodeValue];
        id<FNode> newVal =
            [FServerValues resolveDeferredValueSnapshot:newValUnresolved
                                           withExisting:currentState
                                           serverValues:serverValues];
        transaction.currentOutputSnapshotRaw = newValUnresolved;
        transaction.currentOutputSnapshotResolved = newVal;
        transaction.currentWriteId =
            [NSNumber numberWithInteger:[self nextWriteId]];

        NSArray *events = [self.serverSyncTree
            applyUserOverwriteAtPath:path
                             newData:newVal
                             writeId:[transaction.currentWriteId integerValue]
                           isVisible:transaction.applyLocally];
        [self.eventRaiser raiseEvents:events];

        [self sendAllReadyTransactions];
    }
}

/**
 * @param writeIdsToExclude A specific set to exclude
 */
- (id<FNode>)latestStateAtPath:(FPath *)path
               excludeWriteIds:(NSArray *)writeIdsToExclude {
    id<FNode> latestState =
        [self.serverSyncTree calcCompleteEventCacheAtPath:path
                                          excludeWriteIds:writeIdsToExclude];
    return latestState ? latestState : [FEmptyNode emptyNode];
}

/**
 * Sends any already-run transactions that aren't waiting for outstanding
 * transactions to complete.
 *
 * Externally, call the version with no arguments.
 * Internally, calls itself recursively with a particular transactionQueueTree
 * node to recurse through the tree
 */
- (void)sendAllReadyTransactions {
    FTree *node = self.transactionQueueTree;

    [self pruneCompletedTransactionsBelowNode:node];
    [self sendReadyTransactionsForTree:node];
}

- (void)sendReadyTransactionsForTree:(FTree *)node {
    NSMutableArray *queue = [node getValue];
    if (queue != nil) {
        queue = [self buildTransactionQueueAtNode:node];
        NSAssert([queue count] > 0, @"Sending zero length transaction queue");

        NSUInteger notRunIndex = [queue
            indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
              return ((FTupleTransaction *)obj).status != FTransactionRun;
            }];

        // If they're all run (and not sent), we can send them.  Else, we must
        // wait.
        if (notRunIndex == NSNotFound) {
            [self sendTransactionQueue:queue atPath:node.path];
        }
    } else if ([node hasChildren]) {
        [node forEachChild:^(FTree *child) {
          [self sendReadyTransactionsForTree:child];
        }];
    }
}

/**
 * Given a list of run transactions, send them to the server and then handle the
 * result (success or failure).
 */
- (void)sendTransactionQueue:(NSMutableArray *)queue atPath:(FPath *)path {
    // Mark transactions as sent and bump the retry count
    NSMutableArray *writeIdsToExclude = [[NSMutableArray alloc] init];
    for (FTupleTransaction *transaction in queue) {
        [writeIdsToExclude addObject:transaction.currentWriteId];
    }
    id<FNode> latestState = [self latestStateAtPath:path
                                    excludeWriteIds:writeIdsToExclude];
    id<FNode> snapToSend = latestState;
    NSString *latestHash = [latestState dataHash];
    for (FTupleTransaction *transaction in queue) {
        NSAssert(
            transaction.status == FTransactionRun,
            @"[FRepo sendTransactionQueue:] items in queue should all be run.");
        FFLog(@"I-RDB038021", @"Transaction at %@ set to SENT",
              transaction.path);
        transaction.status = FTransactionSent;
        transaction.retryCount++;
        FPath *relativePath = [FPath relativePathFrom:path to:transaction.path];
        // If we've gotten to this point, the output snapshot must be defined.
        snapToSend =
            [snapToSend updateChild:relativePath
                       withNewChild:transaction.currentOutputSnapshotRaw];
    }

    id dataToSend = [snapToSend valForExport:YES];
    NSString *pathToSend = [path description];
    latestHash = self.hijackHash ? @"badhash" : latestHash;

    // Send the put
    [self.connection
             putData:dataToSend
             forPath:pathToSend
            withHash:latestHash
        withCallback:^(NSString *status, NSString *errorReason) {
          FFLog(@"I-RDB038022", @"Transaction put response: %@ : %@",
                pathToSend, status);

          NSMutableArray *events = [[NSMutableArray alloc] init];
          if ([status isEqualToString:kFWPResponseForActionStatusOk]) {
              // Queue up the callbacks and fire them after cleaning up all of
              // our transaction state, since the callback could trigger more
              // transactions or sets.
              NSMutableArray *callbacks = [[NSMutableArray alloc] init];
              for (FTupleTransaction *transaction in queue) {
                  transaction.status = FTransactionCompleted;
                  [events addObjectsFromArray:
                              [self.serverSyncTree
                                  ackUserWriteWithWriteId:
                                      [transaction.currentWriteId integerValue]
                                                   revert:NO
                                                  persist:NO
                                                    clock:self.serverClock]];
                  if (transaction.onComplete) {
                      // We never unset the output snapshot, and given that this
                      // transaction is complete, it should be set
                      id<FNode> node =
                          transaction.currentOutputSnapshotResolved;
                      FIndexedNode *indexedNode =
                          [FIndexedNode indexedNodeWithNode:node];
                      FIRDatabaseReference *ref = [[FIRDatabaseReference alloc]
                          initWithRepo:self
                                  path:transaction.path];
                      FIRDataSnapshot *snapshot =
                          [[FIRDataSnapshot alloc] initWithRef:ref
                                                   indexedNode:indexedNode];
                      fbt_void_void cb = ^{
                        transaction.onComplete(nil, YES, snapshot);
                      };
                      [callbacks addObject:[cb copy]];
                  }
                  transaction.unwatcher();
              }

              // Now remove the completed transactions.
              [self
                  pruneCompletedTransactionsBelowNode:[self.transactionQueueTree
                                                          subTree:path]];
              // There may be pending transactions that we can now send.
              [self sendAllReadyTransactions];

              // Finally, trigger onComplete callbacks
              [self.eventRaiser raiseCallbacks:callbacks];
          } else {
              // transactions are no longer sent. Update their status
              // appropriately.
              if ([status
                      isEqualToString:kFWPResponseForActionStatusDataStale]) {
                  for (FTupleTransaction *transaction in queue) {
                      if (transaction.status == FTransactionSentNeedsAbort) {
                          transaction.status = FTransactionNeedsAbort;
                      } else {
                          transaction.status = FTransactionRun;
                      }
                  }
              } else {
                  FFWarn(@"I-RDB038023",
                         @"runTransactionBlock: at %@ failed: %@", path,
                         status);
                  for (FTupleTransaction *transaction in queue) {
                      transaction.status = FTransactionNeedsAbort;
                      [transaction setAbortStatus:status reason:errorReason];
                  }
              }
          }

          [self rerunTransactionsForPath:path];
          [self.eventRaiser raiseEvents:events];
        }];
}

/**
 * Finds all transactions dependent on the data at changed Path and reruns them.
 *
 * Should be called any time cached data changes.
 *
 * Return the highest path that was affected by rerunning transactions. This is
 * the path at which events need to be raised for.
 */
- (FPath *)rerunTransactionsForPath:(FPath *)changedPath {
    // For the common case that there are no transactions going on, skip all
    // this!
    if ([self.transactionQueueTree isEmpty]) {
        return changedPath;
    } else {
        FTree *rootMostTransactionNode =
            [self getAncestorTransactionNodeForPath:changedPath];
        FPath *path = rootMostTransactionNode.path;

        NSArray *queue =
            [self buildTransactionQueueAtNode:rootMostTransactionNode];
        [self rerunTransactionQueue:queue atPath:path];

        return path;
    }
}

/**
 * Does all the work of rerunning transactions (as well as cleans up aborted
 * transactions and whatnot).
 */
- (void)rerunTransactionQueue:(NSArray *)queue atPath:(FPath *)path {
    if (queue.count == 0) {
        return; // nothing to do
    }

    // Queue up the callbacks and fire them after cleaning up all of our
    // transaction state, since the callback could trigger more transactions or
    // sets.
    NSMutableArray *events = [[NSMutableArray alloc] init];
    NSMutableArray *callbacks = [[NSMutableArray alloc] init];

    // Ignore, by default, all of the sets in this queue, since we're re-running
    // all of them. However, we want to include the results of new sets
    // triggered as part of this re-run, so we don't want to ignore a range,
    // just these specific sets.
    NSMutableArray *writeIdsToExclude = [[NSMutableArray alloc] init];
    for (FTupleTransaction *transaction in queue) {
        [writeIdsToExclude addObject:transaction.currentWriteId];
    }

    for (FTupleTransaction *transaction in queue) {
        FPath *relativePath __unused =
            [FPath relativePathFrom:path to:transaction.path];
        BOOL abortTransaction = NO;
        NSAssert(relativePath != nil, @"[FRepo rerunTransactionsQueue:] "
                                      @"relativePath should not be null.");

        if (transaction.status == FTransactionNeedsAbort) {
            abortTransaction = YES;
            if (![transaction.abortStatus
                    isEqualToString:kFErrorWriteCanceled]) {
                NSArray *ackEvents = [self.serverSyncTree
                    ackUserWriteWithWriteId:[transaction.currentWriteId
                                                    integerValue]
                                     revert:YES
                                    persist:NO
                                      clock:self.serverClock];
                [events addObjectsFromArray:ackEvents];
            }
        } else if (transaction.status == FTransactionRun) {
            if (transaction.retryCount >= kFTransactionMaxRetries) {
                abortTransaction = YES;
                [transaction setAbortStatus:kFTransactionTooManyRetries
                                     reason:nil];
                [events
                    addObjectsFromArray:
                        [self.serverSyncTree
                            ackUserWriteWithWriteId:[transaction.currentWriteId
                                                            integerValue]
                                             revert:YES
                                            persist:NO
                                              clock:self.serverClock]];
            } else {
                // This code reruns a transaction
                id<FNode> currentNode =
                    [self latestStateAtPath:transaction.path
                            excludeWriteIds:writeIdsToExclude];
                transaction.currentInputSnapshot = currentNode;
                FIRMutableData *mutableCurrent =
                    [[FIRMutableData alloc] initWithNode:currentNode];
                FIRTransactionResult *result =
                    transaction.update(mutableCurrent);
                if (result.isSuccess) {
                    NSNumber *oldWriteId = transaction.currentWriteId;
                    NSDictionary *serverValues =
                        [FServerValues generateServerValues:self.serverClock];

                    id<FNode> newVal = [result.update nodeValue];
                    id<FNode> newValResolved = [FServerValues
                        resolveDeferredValueSnapshot:newVal
                                        withExisting:transaction
                                                         .currentInputSnapshot
                                        serverValues:serverValues];

                    transaction.currentOutputSnapshotRaw = newVal;
                    transaction.currentOutputSnapshotResolved = newValResolved;

                    transaction.currentWriteId =
                        [NSNumber numberWithInteger:[self nextWriteId]];
                    // Mutates writeIdsToExclude in place
                    [writeIdsToExclude removeObject:oldWriteId];
                    [events
                        addObjectsFromArray:
                            [self.serverSyncTree
                                applyUserOverwriteAtPath:transaction.path
                                                 newData:
                                                     transaction
                                                         .currentOutputSnapshotResolved
                                                 writeId:
                                                     [transaction.currentWriteId
                                                             integerValue]
                                               isVisible:transaction
                                                             .applyLocally]];
                    [events addObjectsFromArray:
                                [self.serverSyncTree
                                    ackUserWriteWithWriteId:[oldWriteId
                                                                integerValue]
                                                     revert:YES
                                                    persist:NO
                                                      clock:self.serverClock]];
                } else {
                    abortTransaction = YES;
                    // The user aborted the transaction. JS treats ths as a
                    // "nodata" abort, but it's not an error, so we don't send
                    // them an error.
                    [transaction setAbortStatus:nil reason:nil];
                    [events
                        addObjectsFromArray:
                            [self.serverSyncTree
                                ackUserWriteWithWriteId:
                                    [transaction.currentWriteId integerValue]
                                                 revert:YES
                                                persist:NO
                                                  clock:self.serverClock]];
                }
            }
        }

        [self.eventRaiser raiseEvents:events];
        events = nil;

        if (abortTransaction) {
            // Abort
            transaction.status = FTransactionCompleted;
            transaction.unwatcher();
            if (transaction.onComplete) {
                FIRDatabaseReference *ref = [[FIRDatabaseReference alloc]
                    initWithRepo:self
                            path:transaction.path];
                FIndexedNode *lastInput = [FIndexedNode
                    indexedNodeWithNode:transaction.currentInputSnapshot];
                FIRDataSnapshot *snap =
                    [[FIRDataSnapshot alloc] initWithRef:ref
                                             indexedNode:lastInput];
                fbt_void_void cb = ^{
                  // Unlike JS, no need to check for "nodata" because ObjC has
                  // abortError = nil
                  transaction.onComplete(transaction.abortError, NO, snap);
                };
                [callbacks addObject:[cb copy]];
            }
        }
    }

    // Note: unlike current js client, we don't need to preserve priority. Users
    // can set priority via FIRMutableData

    // Clean up completed transactions.
    [self pruneCompletedTransactionsBelowNode:self.transactionQueueTree];

    // Now fire callbacks, now that we're in a good, known state.
    [self.eventRaiser raiseCallbacks:callbacks];

    // Try to send the transaction result to the server
    [self sendAllReadyTransactions];
}

- (FTree *)getAncestorTransactionNodeForPath:(FPath *)path {
    FTree *transactionNode = self.transactionQueueTree;

    while (![path isEmpty] && [transactionNode getValue] == nil) {
        NSString *front = [path getFront];
        transactionNode =
            [transactionNode subTree:[[FPath alloc] initWith:front]];
        path = [path popFront];
    }

    return transactionNode;
}

- (NSMutableArray *)buildTransactionQueueAtNode:(FTree *)node {
    NSMutableArray *queue = [[NSMutableArray alloc] init];
    [self aggregateTransactionQueuesForNode:node andQueue:queue];

    [queue sortUsingComparator:^NSComparisonResult(FTupleTransaction *obj1,
                                                   FTupleTransaction *obj2) {
      return [obj1.order compare:obj2.order];
    }];

    return queue;
}

- (void)aggregateTransactionQueuesForNode:(FTree *)node
                                 andQueue:(NSMutableArray *)queue {
    NSArray *nodeQueue = [node getValue];
    [queue addObjectsFromArray:nodeQueue];

    [node forEachChild:^(FTree *child) {
      [self aggregateTransactionQueuesForNode:child andQueue:queue];
    }];
}

/**
 * Remove COMPLETED transactions at or below this node in the
 * transactionQueueTree
 */
- (void)pruneCompletedTransactionsBelowNode:(FTree *)node {
    NSMutableArray *queue = [node getValue];
    if (queue != nil) {
        int i = 0;
        // remove all of the completed transactions from the queue
        while (i < queue.count) {
            FTupleTransaction *transaction = [queue objectAtIndex:i];
            if (transaction.status == FTransactionCompleted) {
                [queue removeObjectAtIndex:i];
            } else {
                i++;
            }
        }
        if (queue.count > 0) {
            [node setValue:queue];
        } else {
            [node setValue:nil];
        }
    }

    [node forEachChildMutationSafe:^(FTree *child) {
      [self pruneCompletedTransactionsBelowNode:child];
    }];
}

/**
 *  Aborts all transactions on ancestors or descendants of the specified path.
 * Called when doing a setValue: or updateChildValues: since we consider them
 * incompatible with transactions
 *
 *  @param path path for which we want to abort related transactions.
 */
- (FPath *)abortTransactionsAtPath:(FPath *)path error:(NSString *)error {
    // For the common case that there are no transactions going on, skip all
    // this!
    if ([self.transactionQueueTree isEmpty]) {
        return path;
    } else {
        FPath *affectedPath =
            [self getAncestorTransactionNodeForPath:path].path;

        FTree *transactionNode = [self.transactionQueueTree subTree:path];
        [transactionNode forEachAncestor:^BOOL(FTree *ancestor) {
          [self abortTransactionsAtNode:ancestor error:error];
          return NO;
        }];

        [self abortTransactionsAtNode:transactionNode error:error];

        [transactionNode forEachDescendant:^(FTree *child) {
          [self abortTransactionsAtNode:child error:error];
        }];

        return affectedPath;
    }
}

/**
 * Abort transactions stored in this transactions queue node.
 *
 * @param node Node to abort transactions for.
 */
- (void)abortTransactionsAtNode:(FTree *)node error:(NSString *)error {
    NSMutableArray *queue = [node getValue];
    if (queue != nil) {

        // Queue up the callbacks and fire them after cleaning up all of our
        // transaction state, since can be immediately aborted and removed.
        NSMutableArray *callbacks = [[NSMutableArray alloc] init];

        // Go through queue. Any already-sent transactions must be marked for
        // abort, while the unsent ones can be immediately aborted and removed
        NSMutableArray *events = [[NSMutableArray alloc] init];
        int lastSent = -1;
        // Note: all of the sent transactions will be at the front of the queue,
        // so safe to increment lastSent
        for (FTupleTransaction *transaction in queue) {
            if (transaction.status == FTransactionSentNeedsAbort) {
                // No-op. already marked.
            } else if (transaction.status == FTransactionSent) {
                // Mark this transaction for abort when it returns
                lastSent++;
                transaction.status = FTransactionSentNeedsAbort;
                [transaction setAbortStatus:error reason:nil];
            } else {
                // we can abort this immediately
                transaction.unwatcher();
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
            }
        }
        if (lastSent == -1) {
            // We're not waiting for any sent transactions. We can clear the
            // queue.
            [node setValue:nil];
        } else {
            // Remove the transactions we aborted
            NSRange theRange;
            theRange.location = lastSent + 1;
            theRange.length = queue.count - theRange.location;
            [queue removeObjectsInRange:theRange];
        }

        // Now fire the callbacks
        [self.eventRaiser raiseEvents:events];
        [self.eventRaiser raiseCallbacks:callbacks];
    }
}

@end
