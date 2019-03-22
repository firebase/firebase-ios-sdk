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

#import "FIRFirestore.h"

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FSTFirestoreComponent.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/api/firestore.h"
#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/delayed_constructor.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::api::DocumentReference;
using firebase::firestore::api::Firestore;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::DelayedConstructor;

NS_ASSUME_NONNULL_BEGIN

extern "C" NSString *const FIRFirestoreErrorDomain = @"FIRFirestoreErrorDomain";

#pragma mark - FIRFirestore

@interface FIRFirestore ()

@property(nonatomic, strong, readonly) FSTUserDataConverter *dataConverter;

@end

@implementation FIRFirestore {
  DelayedConstructor<Firestore> _firestore;
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
                   persistenceKey:(std::string)persistenceKey
              credentialsProvider:(std::unique_ptr<CredentialsProvider>)credentialsProvider
                      workerQueue:(std::unique_ptr<AsyncQueue>)workerQueue
                      firebaseApp:(FIRApp *)app {
  if (self = [super init]) {
    _firestore.Init(std::move(projectID), std::move(database), std::move(persistenceKey),
                    std::move(credentialsProvider), std::move(workerQueue), (__bridge void *)self);

    _app = app;

    FSTPreConverterBlock block = ^id _Nullable(id _Nullable input) {
      if ([input isKindOfClass:[FIRDocumentReference class]]) {
        FIRDocumentReference *documentReference = (FIRDocumentReference *)input;
        return [[FSTDocumentKeyReference alloc] initWithKey:documentReference.key
                                                 databaseID:documentReference.firestore.databaseID];
      } else {
        return input;
      }
    };

    _dataConverter = [[FSTUserDataConverter alloc] initWithDatabaseID:&_firestore->database_id()
                                                         preConverter:block];
  }
  return self;
}

- (FIRFirestoreSettings *)settings {
  return _firestore->settings();
}

- (void)setSettings:(FIRFirestoreSettings *)settings {
  _firestore->set_settings(settings);
}

/**
 * Ensures that the FirestoreClient is configured and returns it.
 */
- (FSTFirestoreClient *)client {
  return _firestore->client();
}

- (FIRCollectionReference *)collectionWithPath:(NSString *)collectionPath {
  if (!collectionPath) {
    FSTThrowInvalidArgument(@"Collection path cannot be nil.");
  }
  if ([collectionPath containsString:@"//"]) {
    FSTThrowInvalidArgument(@"Invalid path (%@). Paths must not contain // in them.",
                            collectionPath);
  }

  return _firestore->GetCollection(util::MakeString(collectionPath));
}

- (FIRDocumentReference *)documentWithPath:(NSString *)documentPath {
  if (!documentPath) {
    FSTThrowInvalidArgument(@"Document path cannot be nil.");
  }
  if ([documentPath containsString:@"//"]) {
    FSTThrowInvalidArgument(@"Invalid path (%@). Paths must not contain // in them.", documentPath);
  }

  DocumentReference documentReference = _firestore->GetDocument(util::MakeString(documentPath));
  return [[FIRDocumentReference alloc] initWithReference:std::move(documentReference)];
}

- (FIRWriteBatch *)batch {
  return _firestore->GetBatch();
}

- (void)runTransactionWithBlock:(id _Nullable (^)(FIRTransaction *, NSError **))updateBlock
                  dispatchQueue:(dispatch_queue_t)queue
                     completion:
                         (void (^)(id _Nullable result, NSError *_Nullable error))completion {
  // We wrap the function they provide in order to use internal implementation classes for
  // transaction, and to run the user callback block on the proper queue.
  if (!updateBlock) {
    FSTThrowInvalidArgument(@"Transaction block cannot be nil.");
  } else if (!completion) {
    FSTThrowInvalidArgument(@"Transaction completion block cannot be nil.");
  }

  _firestore->RunTransaction(updateBlock, queue, completion);
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

+ (void)enableLogging:(BOOL)logging {
  FIRSetLoggerLevel(logging ? FIRLoggerLevelDebug : FIRLoggerLevelNotice);
}

- (void)enableNetworkWithCompletion:(nullable void (^)(NSError *_Nullable error))completion {
  _firestore->EnableNetwork(completion);
}

- (void)disableNetworkWithCompletion:(nullable void (^)(NSError *_Nullable))completion {
  _firestore->DisableNetwork(completion);
}

@end

@implementation FIRFirestore (Internal)

- (Firestore *)wrapped {
  return _firestore.get();
}

- (AsyncQueue *)workerQueue {
  return _firestore->worker_queue();
}

- (const DatabaseId *)databaseID {
  return &_firestore->database_id();
}

+ (BOOL)isLoggingEnabled {
  return FIRIsLoggableLevel(FIRLoggerLevelDebug, NO);
}

+ (FIRFirestore *)recoverFromFirestore:(Firestore *)firestore {
  return (__bridge FIRFirestore *)firestore->extension();
}

- (FIRQuery *)collectionGroupWithID:(NSString *)collectionID {
  if (!collectionID) {
    FSTThrowInvalidArgument(@"Collection ID cannot be nil.");
  }
  if ([collectionID containsString:@"/"]) {
    FSTThrowInvalidArgument(
        @"Invalid collection ID (%@). Collection IDs must not contain / in them.", collectionID);
  }

  return _firestore->GetCollectionGroup(collectionID);
}

- (void)shutdownWithCompletion:(nullable void (^)(NSError *_Nullable error))completion {
  _firestore->Shutdown(completion);
}

@end

NS_ASSUME_NONNULL_END
