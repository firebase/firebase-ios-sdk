/*
 * Copyright 2018 Google
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

#import "Firestore/Source/API/FSTFirestoreComponent.h"

#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>

#include <memory>
#include <string>
#include <utility>

#import "FirebaseAuth/Interop/Public/FirebaseAuthInterop/FIRAuthInterop.h"
#import "FirebaseCore/Extension/FIRAppInternal.h"
#import "FirebaseCore/Extension/FIRComponent.h"
#import "FirebaseCore/Extension/FIRComponentContainer.h"
#import "FirebaseCore/Extension/FIRComponentType.h"
#import "FirebaseCore/Extension/FIRLibrary.h"
#import "FirebaseCore/Extension/FIROptionsInternal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"

#include "Firestore/core/include/firebase/firestore/firestore_version.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/credentials/credentials_provider.h"
#include "Firestore/core/src/credentials/firebase_app_check_credentials_provider_apple.h"
#include "Firestore/core/src/credentials/firebase_auth_credentials_provider_apple.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/src/remote/firebase_metadata_provider_apple.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/exception.h"
#include "Firestore/core/src/util/executor.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/memory/memory.h"

using firebase::firestore::credentials::FirebaseAppCheckCredentialsProvider;
using firebase::firestore::credentials::FirebaseAuthCredentialsProvider;
using firebase::firestore::remote::FirebaseMetadataProviderApple;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::Executor;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::ThrowInvalidArgument;

NS_ASSUME_NONNULL_BEGIN

@interface FSTFirestoreComponent () <FIRComponentLifecycleMaintainer, FIRLibrary>
@end

@implementation FSTFirestoreComponent

// Explicitly @synthesize because instances is part of the FSTInstanceProvider protocol.
@synthesize instances = _instances;

#pragma mark - Initialization

- (instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    _instances = [[NSMutableDictionary alloc] init];

    HARD_ASSERT(app, "Cannot initialize Firestore with a nil FIRApp.");
    _app = app;
  }
  return self;
}

- (NSString *)keyForDatabase:(NSString *)database {
  return [NSString stringWithFormat:@"%@|%@", self.app.name, database];
}

#pragma mark - FSTInstanceProvider Conformance

- (FIRFirestore *)firestoreForDatabase:(NSString *)database {
  if (!database) {
    ThrowInvalidArgument("Database identifier may not be nil.");
  }

  NSString *projectID = self.app.options.projectID;
  if (!projectID) {
    ThrowInvalidArgument("FIROptions.projectID must be set to a valid project ID.");
  }

  NSString *key = [self keyForDatabase:database];

  // Get the component from the container.
  @synchronized(self.instances) {
    FIRFirestore *firestore = _instances[key];
    if (!firestore) {
      std::string queue_name{"com.google.firebase.firestore"};
      if (!self.app.isDefaultApp) {
        absl::StrAppend(&queue_name, ".", MakeString(self.app.name));
      }

      auto executor = Executor::CreateSerial(queue_name.c_str());
      auto workerQueue = AsyncQueue::Create(std::move(executor));

      id<FIRAuthInterop> auth = FIR_COMPONENT(FIRAuthInterop, self.app.container);
      id<FIRAppCheckInterop> app_check = FIR_COMPONENT(FIRAppCheckInterop, self.app.container);
      auto authCredentialsProvider =
          std::make_shared<FirebaseAuthCredentialsProvider>(self.app, auth);
      auto appCheckCredentialsProvider =
          std::make_shared<FirebaseAppCheckCredentialsProvider>(self.app, app_check);

      auto firebaseMetadataProvider = absl::make_unique<FirebaseMetadataProviderApple>(self.app);

      model::DatabaseId databaseID{MakeString(projectID), MakeString(database)};
      std::string persistenceKey = MakeString(self.app.name);
      firestore = [[FIRFirestore alloc] initWithDatabaseID:std::move(databaseID)
                                            persistenceKey:std::move(persistenceKey)
                                   authCredentialsProvider:std::move(authCredentialsProvider)
                               appCheckCredentialsProvider:std::move(appCheckCredentialsProvider)
                                               workerQueue:std::move(workerQueue)
                                  firebaseMetadataProvider:std::move(firebaseMetadataProvider)
                                               firebaseApp:self.app
                                          instanceRegistry:self];
      _instances[key] = firestore;
    }
    return firestore;
  }
}

- (void)removeInstanceWithDatabase:(NSString *)database {
  @synchronized(_instances) {
    NSString *key = [self keyForDatabase:database];
    [_instances removeObjectForKey:key];
  }
}

#pragma mark - FIRComponentLifecycleMaintainer

- (void)appWillBeDeleted:(__unused FIRApp *)app {
  NSDictionary<NSString *, FIRFirestore *> *instances;
  @synchronized(_instances) {
    instances = [_instances copy];
    [_instances removeAllObjects];
  }
  for (NSString *key in instances) {
    [instances[key] terminateInternalWithCompletion:nil];
  }
}

#pragma mark - Object Lifecycle

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self withName:@"fire-fst"];
}

#pragma mark - Interoperability

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponent *firestoreProvider = [FIRComponent
      componentWithProtocol:@protocol(FSTFirestoreMultiDBProvider)
        instantiationTiming:FIRInstantiationTimingLazy
              creationBlock:^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
                FSTFirestoreComponent *multiDBComponent =
                    [[FSTFirestoreComponent alloc] initWithApp:container.app];
                *isCacheable = YES;
                return multiDBComponent;
              }];
  return @[ firestoreProvider ];
}

@end

/// This function forces the linker to include `FSTFirestoreComponent`. See `+[FIRFirestore
/// notCalled]`.
void FSTIncludeFSTFirestoreComponent(void) {
}

NS_ASSUME_NONNULL_END
