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

#import "FIRFirestore.h"

#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIRLogger.h>
#import <FirebaseCore/FIROptions.h>

#include <memory>
#include <string>
#include <utility>

#import "FIRFirestoreSettings.h"
#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRTransaction+Internal.h"
#import "Firestore/Source/API/FIRWriteBatch+Internal.h"
#import "Firestore/Source/API/FSTFirestoreComponent.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/firebase_credentials_provider_apple.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::FirebaseCredentialsProvider;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::ResourcePath;
using util::AsyncQueue;
using util::Executor;
using util::ExecutorLibdispatch;

NS_ASSUME_NONNULL_BEGIN

extern "C" NSString *const FIRFirestoreErrorDomain = @"FIRFirestoreErrorDomain";

#pragma mark - FIRFirestore

@interface FIRFirestore () {
  /** The actual owned DatabaseId instance is allocated in FIRFirestore. */
  DatabaseId _databaseID;
  std::unique_ptr<CredentialsProvider> _credentialsProvider;
}

@property(nonatomic, strong) NSString *persistenceKey;

// Note that `client` is updated after initialization, but marking this readwrite would generate an
// incorrect setter (since we make the assignment to `client` inside an `@synchronized` block.
@property(nonatomic, strong, readonly) FSTFirestoreClient *client;
@property(nonatomic, strong, readonly) FSTUserDataConverter *dataConverter;

@end

@implementation FIRFirestore {
  // Ownership will be transferred to `FSTFirestoreClient` as soon as the client is created.
  std::unique_ptr<AsyncQueue> _workerQueue;

  // All guarded by @synchronized(self)
  FIRFirestoreSettings *_settings;
  FSTFirestoreClient *_client;
}

- (AsyncQueue *)workerQueue {
  return [_client workerQueue];
}

+ (NSMutableDictionary<NSString *, FIRFirestore *> *)instances {
  static dispatch_once_t token = 0;
  static NSMutableDictionary<NSString *, FIRFirestore *> *instances;
  dispatch_once(&token, ^{
    instances = [NSMutableDictionary dictionary];
  });
  return instances;
}

+ (void)initialize {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserverForName:kFIRAppDeleteNotification
                      object:nil
                       queue:nil
                  usingBlock:^(NSNotification *_Nonnull note) {
                    NSString *appName = note.userInfo[kFIRAppNameKey];
                    if (appName == nil) return;

                    NSMutableDictionary *instances = [self instances];
                    @synchronized(instances) {
                      // Since the key for instances isn't just the app name, iterate over all the
                      // keys to get the one(s) we have to delete. There could be multiple in case
                      // the user calls firestoreForApp:database:.
                      NSMutableArray *keysToDelete = [[NSMutableArray alloc] init];
                      NSString *keyPrefix = [NSString stringWithFormat:@"%@|", appName];
                      for (NSString *key in instances.allKeys) {
                        if ([key hasPrefix:keyPrefix]) {
                          [keysToDelete addObject:key];
                        }
                      }

                      // Loop through the keys found and delete them from the stored instances.
                      for (NSString *key in keysToDelete) {
                        [instances removeObjectForKey:key];
                      }
                    }
                  }];
}

+ (instancetype)firestore {
  FIRApp *app = [FIRApp defaultApp];
  if (!app) {
    FSTThrowInvalidUsage(@"FIRAppNotConfiguredException",
                         @"Failed to get FirebaseApp instance. Please call FirebaseApp.configure() "
                         @"before using Firestore");
  }
  return [self firestoreForApp:app database:util::WrapNSString(DatabaseId::kDefault)];
}

+ (instancetype)firestoreForApp:(FIRApp *)app {
  return [self firestoreForApp:app database:util::WrapNSString(DatabaseId::kDefault)];
}

// TODO(b/62410906): make this public
+ (instancetype)firestoreForApp:(FIRApp *)app database:(NSString *)database {
  if (!app) {
    FSTThrowInvalidArgument(@"FirebaseApp instance may not be nil. Use FirebaseApp.app() if you'd "
                             "like to use the default FirebaseApp instance.");
  }
  if (!database) {
    FSTThrowInvalidArgument(@"database identifier may not be nil. Use '%s' if you want the default "
                             "database",
                            DatabaseId::kDefault);
  }

  id<FSTFirestoreMultiDBProvider> provider =
      FIR_COMPONENT(FSTFirestoreMultiDBProvider, app.container);
  return [provider firestoreForDatabase:database];
}

- (instancetype)initWithProjectID:(std::string)projectID
                         database:(std::string)database
                   persistenceKey:(NSString *)persistenceKey
              credentialsProvider:(std::unique_ptr<CredentialsProvider>)credentialsProvider
                      workerQueue:(std::unique_ptr<AsyncQueue>)workerQueue
                      firebaseApp:(FIRApp *)app {
  if (self = [super init]) {
    _databaseID = DatabaseId{std::move(projectID), std::move(database)};
    FSTPreConverterBlock block = ^id _Nullable(id _Nullable input) {
      if ([input isKindOfClass:[FIRDocumentReference class]]) {
        FIRDocumentReference *documentReference = (FIRDocumentReference *)input;
        return [[FSTDocumentKeyReference alloc] initWithKey:documentReference.key
                                                 databaseID:documentReference.firestore.databaseID];
      } else {
        return input;
      }
    };
    _dataConverter = [[FSTUserDataConverter alloc] initWithDatabaseID:&_databaseID
                                                         preConverter:block];
    _persistenceKey = persistenceKey;
    _credentialsProvider = std::move(credentialsProvider);
    _workerQueue = std::move(workerQueue);
    _app = app;
    _settings = [[FIRFirestoreSettings alloc] init];
  }
  return self;
}

- (FIRFirestoreSettings *)settings {
  @synchronized(self) {
    // Disallow mutation of our internal settings
    return [_settings copy];
  }
}

- (void)setSettings:(FIRFirestoreSettings *)settings {
  @synchronized(self) {
    // As a special exception, don't throw if the same settings are passed repeatedly. This should
    // make it more friendly to create a Firestore instance.
    if (_client && ![_settings isEqual:settings]) {
      FSTThrowInvalidUsage(@"FIRIllegalStateException",
                           @"Firestore instance has already been started and its settings can no "
                            "longer be changed. You can only set settings before calling any "
                            "other methods on a Firestore instance.");
    }
    _settings = [settings copy];
  }
}

/**
 * Ensures that the FirestoreClient is configured and returns it.
 */
- (FSTFirestoreClient *)client {
  [self ensureClientConfigured];
  return _client;
}

- (void)ensureClientConfigured {
  @synchronized(self) {
    if (!_client) {
      // These values are validated elsewhere; this is just double-checking:
      HARD_ASSERT(_settings.host, "FirestoreSettings.host cannot be nil.");
      HARD_ASSERT(_settings.dispatchQueue, "FirestoreSettings.dispatchQueue cannot be nil.");

      const DatabaseInfo database_info(*self.databaseID, util::MakeString(_persistenceKey),
                                       util::MakeString(_settings.host), _settings.sslEnabled);

      std::unique_ptr<Executor> userExecutor =
          absl::make_unique<ExecutorLibdispatch>(_settings.dispatchQueue);

      HARD_ASSERT(_workerQueue, "Expected non-null _workerQueue");
      _client = [FSTFirestoreClient clientWithDatabaseInfo:database_info
                                                  settings:_settings
                                       credentialsProvider:_credentialsProvider.get()
                                              userExecutor:std::move(userExecutor)
                                               workerQueue:std::move(_workerQueue)];
    }
  }
}

- (FIRCollectionReference *)collectionWithPath:(NSString *)collectionPath {
  if (!collectionPath) {
    FSTThrowInvalidArgument(@"Collection path cannot be nil.");
  }
  if ([collectionPath containsString:@"//"]) {
    FSTThrowInvalidArgument(@"Invalid path (%@). Paths must not contain // in them.",
                            collectionPath);
  }

  [self ensureClientConfigured];
  const ResourcePath path = ResourcePath::FromString(util::MakeString(collectionPath));
  return [FIRCollectionReference referenceWithPath:path firestore:self];
}

- (FIRDocumentReference *)documentWithPath:(NSString *)documentPath {
  if (!documentPath) {
    FSTThrowInvalidArgument(@"Document path cannot be nil.");
  }
  if ([documentPath containsString:@"//"]) {
    FSTThrowInvalidArgument(@"Invalid path (%@). Paths must not contain // in them.", documentPath);
  }

  [self ensureClientConfigured];
  const ResourcePath path = ResourcePath::FromString(util::MakeString(documentPath));
  return [FIRDocumentReference referenceWithPath:path firestore:self];
}

- (void)runTransactionWithBlock:(id _Nullable (^)(FIRTransaction *, NSError **))updateBlock
                  dispatchQueue:(dispatch_queue_t)queue
                     completion:
                         (void (^)(id _Nullable result, NSError *_Nullable error))completion {
  // We wrap the function they provide in order to use internal implementation classes for
  // FSTTransaction, and to run the user callback block on the proper queue.
  if (!updateBlock) {
    FSTThrowInvalidArgument(@"Transaction block cannot be nil.");
  } else if (!completion) {
    FSTThrowInvalidArgument(@"Transaction completion block cannot be nil.");
  }

  FSTTransactionBlock wrappedUpdate =
      ^(FSTTransaction *internalTransaction,
        void (^internalCompletion)(id _Nullable, NSError *_Nullable)) {
        FIRTransaction *transaction =
            [FIRTransaction transactionWithFSTTransaction:internalTransaction firestore:self];
        dispatch_async(queue, ^{
          NSError *_Nullable error = nil;
          id _Nullable result = updateBlock(transaction, &error);
          if (error) {
            // Force the result to be nil in the case of an error, in case the user set both.
            result = nil;
          }
          internalCompletion(result, error);
        });
      };
  [self.client transactionWithRetries:5 updateBlock:wrappedUpdate completion:completion];
}

- (FIRWriteBatch *)batch {
  [self ensureClientConfigured];

  return [FIRWriteBatch writeBatchWithFirestore:self];
}

- (void)runTransactionWithBlock:(id _Nullable (^)(FIRTransaction *, NSError **error))updateBlock
                     completion:
                         (void (^)(id _Nullable result, NSError *_Nullable error))completion {
  static dispatch_queue_t transactionDispatchQueue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    transactionDispatchQueue = dispatch_queue_create("com.google.firebase.firestore.transaction",
                                                     DISPATCH_QUEUE_CONCURRENT);
  });
  [self runTransactionWithBlock:updateBlock
                  dispatchQueue:transactionDispatchQueue
                     completion:completion];
}

- (void)shutdownWithCompletion:(nullable void (^)(NSError *_Nullable error))completion {
  if (!_client) {
    if (completion) {
      // We should be dispatching the callback on the user dispatch queue but if the client is nil
      // here that queue was never created.
      completion(nil);
    }
  } else {
    [_client shutdownWithCompletion:completion];
  }
}

+ (BOOL)isLoggingEnabled {
  return FIRIsLoggableLevel(FIRLoggerLevelDebug, NO);
}

+ (void)enableLogging:(BOOL)logging {
  FIRSetLoggerLevel(logging ? FIRLoggerLevelDebug : FIRLoggerLevelNotice);
}

- (void)enableNetworkWithCompletion:(nullable void (^)(NSError *_Nullable error))completion {
  [self ensureClientConfigured];
  [self.client enableNetworkWithCompletion:completion];
}

- (void)disableNetworkWithCompletion:(nullable void (^)(NSError *_Nullable))completion {
  [self ensureClientConfigured];
  [self.client disableNetworkWithCompletion:completion];
}

- (const DatabaseId *)databaseID {
  return &_databaseID;
}

@end

NS_ASSUME_NONNULL_END
