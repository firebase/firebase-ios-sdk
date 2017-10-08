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

#import "FSTFirestoreClient.h"

#import "FSTAssert.h"
#import "FSTClasses.h"
#import "FSTCredentialsProvider.h"
#import "FSTDatabaseInfo.h"
#import "FSTDatastore.h"
#import "FSTDispatchQueue.h"
#import "FSTEagerGarbageCollector.h"
#import "FSTEventManager.h"
#import "FSTLevelDB.h"
#import "FSTLocalSerializer.h"
#import "FSTLocalStore.h"
#import "FSTLogger.h"
#import "FSTMemoryPersistence.h"
#import "FSTNoOpGarbageCollector.h"
#import "FSTRemoteStore.h"
#import "FSTSerializerBeta.h"
#import "FSTSyncEngine.h"
#import "FSTTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTFirestoreClient ()
- (instancetype)initWithDatabaseInfo:(FSTDatabaseInfo *)databaseInfo
                      usePersistence:(BOOL)usePersistence
                 credentialsProvider:(id<FSTCredentialsProvider>)credentialsProvider
                   userDispatchQueue:(FSTDispatchQueue *)userDispatchQueue
                 workerDispatchQueue:(FSTDispatchQueue *)queue NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) FSTDatabaseInfo *databaseInfo;
@property(nonatomic, strong, readonly) FSTEventManager *eventManager;
@property(nonatomic, strong, readonly) id<FSTPersistence> persistence;
@property(nonatomic, strong, readonly) FSTSyncEngine *syncEngine;
@property(nonatomic, strong, readonly) FSTRemoteStore *remoteStore;
@property(nonatomic, strong, readonly) FSTLocalStore *localStore;

/**
 * Dispatch queue responsible for all of our internal processing. When we get incoming work from
 * the user (via public API) or the network (incoming GRPC messages), we should always dispatch
 * onto this queue. This ensures our internal data structures are never accessed from multiple
 * threads simultaneously.
 */
@property(nonatomic, strong, readonly) FSTDispatchQueue *workerDispatchQueue;

@property(nonatomic, strong, readonly) id<FSTCredentialsProvider> credentialsProvider;

@end

@implementation FSTFirestoreClient

+ (instancetype)clientWithDatabaseInfo:(FSTDatabaseInfo *)databaseInfo
                        usePersistence:(BOOL)usePersistence
                   credentialsProvider:(id<FSTCredentialsProvider>)credentialsProvider
                     userDispatchQueue:(FSTDispatchQueue *)userDispatchQueue
                   workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue {
  return [[FSTFirestoreClient alloc] initWithDatabaseInfo:databaseInfo
                                           usePersistence:usePersistence
                                      credentialsProvider:credentialsProvider
                                        userDispatchQueue:userDispatchQueue
                                      workerDispatchQueue:workerDispatchQueue];
}

- (instancetype)initWithDatabaseInfo:(FSTDatabaseInfo *)databaseInfo
                      usePersistence:(BOOL)usePersistence
                 credentialsProvider:(id<FSTCredentialsProvider>)credentialsProvider
                   userDispatchQueue:(FSTDispatchQueue *)userDispatchQueue
                 workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue {
  if (self = [super init]) {
    _databaseInfo = databaseInfo;
    _credentialsProvider = credentialsProvider;
    _userDispatchQueue = userDispatchQueue;
    _workerDispatchQueue = workerDispatchQueue;

    dispatch_semaphore_t initialUserAvailable = dispatch_semaphore_create(0);
    __block FSTUser *initialUser;
    FSTWeakify(self);
    _credentialsProvider.userChangeListener = ^(FSTUser *user) {
      FSTStrongify(self);
      if (self) {
        if (!initialUser) {
          initialUser = user;
          dispatch_semaphore_signal(initialUserAvailable);
        } else {
          [workerDispatchQueue dispatchAsync:^{
            [self userDidChange:user];
          }];
        }
      }
    };

    // Defer initialization until we get the current user from the userChangeListener. This is
    // guaranteed to be synchronously dispatched onto our worker queue, so we will be initialized
    // before any subsequently queued work runs.
    [_workerDispatchQueue dispatchAsync:^{
      dispatch_semaphore_wait(initialUserAvailable, DISPATCH_TIME_FOREVER);

      [self initializeWithUser:initialUser usePersistence:usePersistence];
    }];
  }
  return self;
}

- (void)initializeWithUser:(FSTUser *)user usePersistence:(BOOL)usePersistence {
  // Do all of our initialization on our own dispatch queue.
  [self.workerDispatchQueue verifyIsCurrentQueue];

  // Note: The initialization work must all be synchronous (we can't dispatch more work) since
  // external write/listen operations could get queued to run before that subsequent work
  // completes.
  id<FSTGarbageCollector> garbageCollector;
  if (usePersistence) {
    // TODO(http://b/33384523): For now we just disable garbage collection when persistence is
    // enabled.
    garbageCollector = [[FSTNoOpGarbageCollector alloc] init];

    NSString *dir = [FSTLevelDB storageDirectoryForDatabaseInfo:self.databaseInfo
                                             documentsDirectory:[FSTLevelDB documentsDirectory]];

    FSTSerializerBeta *remoteSerializer =
        [[FSTSerializerBeta alloc] initWithDatabaseID:self.databaseInfo.databaseID];
    FSTLocalSerializer *serializer =
        [[FSTLocalSerializer alloc] initWithRemoteSerializer:remoteSerializer];

    _persistence = [[FSTLevelDB alloc] initWithDirectory:dir serializer:serializer];
  } else {
    garbageCollector = [[FSTEagerGarbageCollector alloc] init];
    _persistence = [FSTMemoryPersistence persistence];
  }

  NSError *error;
  if (![_persistence start:&error]) {
    // If local storage fails to start then just throw up our hands: the error is unrecoverable.
    // There's nothing an end-user can do and nearly all failures indicate the developer is doing
    // something grossly wrong so we should stop them cold in their tracks with a failure they
    // can't ignore.
    [NSException raise:NSInternalInconsistencyException format:@"Failed to open DB: %@", error];
  }

  _localStore = [[FSTLocalStore alloc] initWithPersistence:_persistence
                                          garbageCollector:garbageCollector
                                               initialUser:user];

  FSTDatastore *datastore = [FSTDatastore datastoreWithDatabase:self.databaseInfo
                                            workerDispatchQueue:self.workerDispatchQueue
                                                    credentials:self.credentialsProvider];

  _remoteStore = [FSTRemoteStore remoteStoreWithLocalStore:_localStore datastore:datastore];

  _syncEngine = [[FSTSyncEngine alloc] initWithLocalStore:_localStore
                                              remoteStore:_remoteStore
                                              initialUser:user];

  _eventManager = [FSTEventManager eventManagerWithSyncEngine:_syncEngine];

  // Setup wiring for remote store.
  _remoteStore.syncEngine = _syncEngine;

  _remoteStore.onlineStateDelegate = _eventManager;

  // NOTE: RemoteStore depends on LocalStore (for persisting stream tokens, refilling mutation
  // queue, etc.) so must be started after LocalStore.
  [_localStore start];
  [_remoteStore start];
}

- (void)userDidChange:(FSTUser *)user {
  [self.workerDispatchQueue verifyIsCurrentQueue];

  FSTLog(@"User Changed: %@", user);
  [self.syncEngine userDidChange:user];
}

- (void)disableNetworkWithCompletion:(nullable FSTVoidErrorBlock)completion {
  [self.workerDispatchQueue dispatchAsync:^{
    [self.remoteStore disableNetwork];
    if (completion) {
      [self.userDispatchQueue dispatchAsync:^{
        completion(nil);
      }];
    }
  }];
}

- (void)enableNetworkWithCompletion:(nullable FSTVoidErrorBlock)completion {
  [self.workerDispatchQueue dispatchAsync:^{
    [self.remoteStore enableNetwork];
    if (completion) {
      [self.userDispatchQueue dispatchAsync:^{
        completion(nil);
      }];
    }
  }];
}

- (void)shutdownWithCompletion:(nullable FSTVoidErrorBlock)completion {
  [self.workerDispatchQueue dispatchAsync:^{
    self.credentialsProvider.userChangeListener = nil;

    [self.remoteStore shutdown];
    [self.localStore shutdown];
    [self.persistence shutdown];
    if (completion) {
      [self.userDispatchQueue dispatchAsync:^{
        completion(nil);
      }];
    }
  }];
}

- (FSTQueryListener *)listenToQuery:(FSTQuery *)query
                            options:(FSTListenOptions *)options
                viewSnapshotHandler:(FSTViewSnapshotHandler)viewSnapshotHandler {
  FSTQueryListener *listener = [[FSTQueryListener alloc] initWithQuery:query
                                                               options:options
                                                   viewSnapshotHandler:viewSnapshotHandler];

  [self.workerDispatchQueue dispatchAsync:^{
    [self.eventManager addListener:listener];
  }];

  return listener;
}

- (void)removeListener:(FSTQueryListener *)listener {
  [self.workerDispatchQueue dispatchAsync:^{
    [self.eventManager removeListener:listener];
  }];
}

- (void)writeMutations:(NSArray<FSTMutation *> *)mutations
            completion:(nullable FSTVoidErrorBlock)completion {
  [self.workerDispatchQueue dispatchAsync:^{
    if (mutations.count == 0) {
      [self.userDispatchQueue dispatchAsync:^{
        completion(nil);
      }];
    } else {
      [self.syncEngine writeMutations:mutations
                           completion:^(NSError *error) {
                             // Dispatch the result back onto the user dispatch queue.
                             if (completion) {
                               [self.userDispatchQueue dispatchAsync:^{
                                 completion(error);
                               }];
                             }
                           }];
    }
  }];
};

- (void)transactionWithRetries:(int)retries
                   updateBlock:(FSTTransactionBlock)updateBlock
                    completion:(FSTVoidIDErrorBlock)completion {
  [self.workerDispatchQueue dispatchAsync:^{
    [self.syncEngine transactionWithRetries:retries
                        workerDispatchQueue:self.workerDispatchQueue
                                updateBlock:updateBlock
                                 completion:^(id _Nullable result, NSError *_Nullable error) {
                                   // Dispatch the result back onto the user dispatch queue.
                                   if (completion) {
                                     [self.userDispatchQueue dispatchAsync:^{
                                       completion(result, error);
                                     }];
                                   }
                                 }];

  }];
}

- (FSTDatabaseID *)databaseID {
  return self.databaseInfo.databaseID;
}

@end

NS_ASSUME_NONNULL_END
