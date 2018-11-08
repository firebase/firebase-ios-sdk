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

#import <FirebaseAuthInterop/FIRAuthInterop.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIRComponentRegistrant.h>
#import <FirebaseCore/FIRDependency.h>
#import <FirebaseCore/FIROptions.h>

#include <memory>
#include <string>
#include <utility>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"
#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/firebase_credentials_provider_apple.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::FirebaseCredentialsProvider;
using util::AsyncQueue;
using util::ExecutorLibdispatch;

NS_ASSUME_NONNULL_BEGIN

@interface FSTFirestoreComponent () <FIRComponentLifecycleMaintainer, FIRComponentRegistrant>
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

#pragma mark - FSTInstanceProvider Conformance

- (FIRFirestore *)firestoreForDatabase:(NSString *)database {
  if (!database) {
    FSTThrowInvalidArgument(@"database identifier may not be nil.");
  }

  NSString *key = [NSString stringWithFormat:@"%@|%@", self.app.name, database];

  // Get the component from the container.
  @synchronized(self.instances) {
    FIRFirestore *firestore = _instances[key];
    if (!firestore) {
      std::string queue_name{"com.google.firebase.firestore"};
      if (!self.app.isDefaultApp) {
        absl::StrAppend(&queue_name, ".", util::MakeString(self.app.name));
      }

      auto executor = absl::make_unique<ExecutorLibdispatch>(
          dispatch_queue_create(queue_name.c_str(), DISPATCH_QUEUE_SERIAL));
      auto workerQueue = absl::make_unique<AsyncQueue>(std::move(executor));

      id<FIRAuthInterop> auth = FIR_COMPONENT(FIRAuthInterop, self.app.container);
      std::unique_ptr<CredentialsProvider> credentials_provider =
          absl::make_unique<FirebaseCredentialsProvider>(self.app, auth);

      NSString *persistenceKey = self.app.name;
      NSString *projectID = self.app.options.projectID;
      firestore = [[FIRFirestore alloc] initWithProjectID:util::MakeString(projectID)
                                                 database:util::MakeString(database)
                                           persistenceKey:persistenceKey
                                      credentialsProvider:std::move(credentials_provider)
                                              workerQueue:std::move(workerQueue)
                                              firebaseApp:self.app];
      _instances[key] = firestore;
    }

    return firestore;
  }
}

#pragma mark - FIRComponentLifecycleMaintainer

- (void)appWillBeDeleted:(FIRApp *)app {
  // Stop any actions and clean up resources since instances of Firestore associated with this app
  // will be removed. Currently does not do anything.
}

#pragma mark - Object Lifecycle

+ (void)load {
  [FIRComponentContainer registerAsComponentRegistrant:self];
}

#pragma mark - Interoperability

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRDependency *auth =
      [FIRDependency dependencyWithProtocol:@protocol(FIRAuthInterop) isRequired:NO];
  FIRComponent *firestoreProvider = [FIRComponent
      componentWithProtocol:@protocol(FSTFirestoreMultiDBProvider)
        instantiationTiming:FIRInstantiationTimingLazy
               dependencies:@[ auth ]
              creationBlock:^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
                FSTFirestoreComponent *multiDBComponent =
                    [[FSTFirestoreComponent alloc] initWithApp:container.app];
                *isCacheable = YES;
                return multiDBComponent;
              }];
  return @[ firestoreProvider ];
}

@end

NS_ASSUME_NONNULL_END
