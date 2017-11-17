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
#import <FirebaseCore/FIRLogger.h>
#import <FirebaseCore/FIROptions.h>

#import "FIRFirestoreSettings.h"
#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRTransaction+Internal.h"
#import "Firestore/Source/API/FIRWriteBatch+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"

#import "Firestore/Source/Auth/FSTCredentialsProvider.h"
#import "Firestore/Source/Core/FSTDatabaseInfo.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Model/FSTDatabaseID.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"
#import "Firestore/Source/Util/FSTLogger.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const FIRFirestoreErrorDomain = @"FIRFirestoreErrorDomain";

@interface FIRFirestore ()

@property(nonatomic, strong) FSTDatabaseID *databaseID;
@property(nonatomic, strong) NSString *persistenceKey;
@property(nonatomic, strong) id<FSTCredentialsProvider> credentialsProvider;
@property(nonatomic, strong) FSTDispatchQueue *workerDispatchQueue;

@property(nonatomic, strong) FSTFirestoreClient *client;
@property(nonatomic, strong, readonly) FSTUserDataConverter *dataConverter;

@end

@implementation FIRFirestore {
  FIRFirestoreSettings *_settings;
}

+ (NSMutableDictionary<NSString *, FIRFirestore *> *)instances {
  static dispatch_once_t token = 0;
  static NSMutableDictionary<NSString *, FIRFirestore *> *instances;
  dispatch_once(&token, ^{
    instances = [NSMutableDictionary dictionary];
  });
  return instances;
}

+ (instancetype)firestore {
  FIRApp *app = [FIRApp defaultApp];
  if (!app) {
    FSTThrowInvalidUsage(@"FIRAppNotConfiguredException",
                         @"Failed to get FirebaseApp instance. Please call FirebaseApp.configure() "
                         @"before using Firestore");
  }
  return [self firestoreForApp:app database:kDefaultDatabaseID];
}

+ (instancetype)firestoreForApp:(FIRApp *)app {
  return [self firestoreForApp:app database:kDefaultDatabaseID];
}

// TODO(b/62410906): make this public
+ (instancetype)firestoreForApp:(FIRApp *)app database:(NSString *)database {
  if (!app) {
    FSTThrowInvalidArgument(
        @"FirebaseApp instance may not be nil. Use FirebaseApp.app() if you'd "
         "like to use the default FirebaseApp instance.");
  }
  if (!database) {
    FSTThrowInvalidArgument(
        @"database identifier may not be nil. Use '%@' if you want the default "
         "database",
        kDefaultDatabaseID);
  }
  NSString *key = [NSString stringWithFormat:@"%@|%@", app.name, database];

  NSMutableDictionary<NSString *, FIRFirestore *> *instances = self.instances;
  @synchronized(instances) {
    FIRFirestore *firestore = instances[key];
    if (!firestore) {
      NSString *projectID = app.options.projectID;
      FSTAssert(projectID, @"FirebaseOptions.projectID cannot be nil.");

      FSTDispatchQueue *workerDispatchQueue = [FSTDispatchQueue
          queueWith:dispatch_queue_create("com.google.firebase.firestore", DISPATCH_QUEUE_SERIAL)];

      id<FSTCredentialsProvider> credentialsProvider;
      credentialsProvider = [[FSTFirebaseCredentialsProvider alloc] initWithApp:app];

      NSString *persistenceKey = app.name;

      firestore = [[FIRFirestore alloc] initWithProjectID:projectID
                                                 database:database
                                           persistenceKey:persistenceKey
                                      credentialsProvider:credentialsProvider
                                      workerDispatchQueue:workerDispatchQueue
                                              firebaseApp:app];
      instances[key] = firestore;
    }

    return firestore;
  }
}

- (instancetype)initWithProjectID:(NSString *)projectID
                         database:(NSString *)database
                   persistenceKey:(NSString *)persistenceKey
              credentialsProvider:(id<FSTCredentialsProvider>)credentialsProvider
              workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                      firebaseApp:(FIRApp *)app {
  if (self = [super init]) {
    _databaseID = [FSTDatabaseID databaseIDWithProject:projectID database:database];
    FSTPreConverterBlock block = ^id _Nullable(id _Nullable input) {
      if ([input isKindOfClass:[FIRDocumentReference class]]) {
        FIRDocumentReference *documentReference = (FIRDocumentReference *)input;
        return [[FSTDocumentKeyReference alloc] initWithKey:documentReference.key
                                                 databaseID:documentReference.firestore.databaseID];
      } else {
        return input;
      }
    };
    _dataConverter =
        [[FSTUserDataConverter alloc] initWithDatabaseID:_databaseID preConverter:block];
    _persistenceKey = persistenceKey;
    _credentialsProvider = credentialsProvider;
    _workerDispatchQueue = workerDispatchQueue;
    _app = app;
    _settings = [[FIRFirestoreSettings alloc] init];
  }
  return self;
}

- (FIRFirestoreSettings *)settings {
  // Disallow mutation of our internal settings
  return [_settings copy];
}

- (void)setSettings:(FIRFirestoreSettings *)settings {
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

/**
 * Ensures that the FirestoreClient is configured.
 * @return self
 */
- (instancetype)firestoreWithConfiguredClient {
  if (!_client) {
    // These values are validated elsewhere; this is just double-checking:
    FSTAssert(_settings.host, @"FirestoreSettings.host cannot be nil.");
    FSTAssert(_settings.dispatchQueue, @"FirestoreSettings.dispatchQueue cannot be nil.");

    FSTDatabaseInfo *databaseInfo =
        [FSTDatabaseInfo databaseInfoWithDatabaseID:_databaseID
                                     persistenceKey:_persistenceKey
                                               host:_settings.host
                                         sslEnabled:_settings.sslEnabled];

    FSTDispatchQueue *userDispatchQueue = [FSTDispatchQueue queueWith:_settings.dispatchQueue];

    _client = [FSTFirestoreClient clientWithDatabaseInfo:databaseInfo
                                          usePersistence:_settings.persistenceEnabled
                                     credentialsProvider:_credentialsProvider
                                       userDispatchQueue:userDispatchQueue
                                     workerDispatchQueue:_workerDispatchQueue];
  }
  return self;
}

- (FIRCollectionReference *)collectionWithPath:(NSString *)collectionPath {
  if (!collectionPath) {
    FSTThrowInvalidArgument(@"Collection path cannot be nil.");
  }
  FSTResourcePath *path = [FSTResourcePath pathWithString:collectionPath];
  return
      [FIRCollectionReference referenceWithPath:path firestore:self.firestoreWithConfiguredClient];
}

- (FIRDocumentReference *)documentWithPath:(NSString *)documentPath {
  if (!documentPath) {
    FSTThrowInvalidArgument(@"Document path cannot be nil.");
  }
  FSTResourcePath *path = [FSTResourcePath pathWithString:documentPath];
  return [FIRDocumentReference referenceWithPath:path firestore:self.firestoreWithConfiguredClient];
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
  [self firestoreWithConfiguredClient];
  [self.client transactionWithRetries:5 updateBlock:wrappedUpdate completion:completion];
}

- (FIRWriteBatch *)batch {
  return [FIRWriteBatch writeBatchWithFirestore:[self firestoreWithConfiguredClient]];
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
  if (!self.client) {
    completion(nil);
    return;
  }
  return [self.client shutdownWithCompletion:completion];
}

+ (BOOL)isLoggingEnabled {
  return FIRIsLoggableLevel(FIRLoggerLevelDebug, NO);
}

+ (void)enableLogging:(BOOL)logging {
  FIRSetLoggerLevel(logging ? FIRLoggerLevelDebug : FIRLoggerLevelNotice);
}

@end

NS_ASSUME_NONNULL_END
