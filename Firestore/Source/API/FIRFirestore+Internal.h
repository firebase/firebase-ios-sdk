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

#include <memory>

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "absl/strings/string_view.h"

NS_ASSUME_NONNULL_BEGIN

@class FSTDispatchQueue;
@class FSTFirestoreClient;
@class FSTUserDataConverter;

@interface FIRFirestore (/* Init */)

/**
 * Initializes a Firestore object with all the required parameters directly. This exists so that
 * tests can create FIRFirestore objects without needing FIRApp.
 */
- (instancetype)initWithProjectID:(const absl::string_view)projectID
                         database:(const absl::string_view)database
                   persistenceKey:(NSString *)persistenceKey
              credentialsProvider:(std::unique_ptr<firebase::firestore::auth::CredentialsProvider>)
                                      credentialsProvider
              workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                      firebaseApp:(FIRApp *)app;

@end

/** Internal FIRFirestore API we don't want exposed in our public header files. */
@interface FIRFirestore (Internal)

/** Checks to see if logging is is globally enabled for the Firestore client. */
+ (BOOL)isLoggingEnabled;

/**
 * Shutdown this `FIRFirestore`, releasing all resources (abandoning any outstanding writes,
 * removing all listens, closing all network connections, etc.).
 *
 * @param completion A block to execute once everything has shut down.
 */
- (void)shutdownWithCompletion:(nullable void (^)(NSError *_Nullable error))completion
    NS_SWIFT_NAME(shutdown(completion:));

// FIRFirestore ownes the DatabaseId instance.
@property(nonatomic, assign, readonly) const firebase::firestore::model::DatabaseId *databaseID;
@property(nonatomic, strong, readonly) FSTFirestoreClient *client;
@property(nonatomic, strong, readonly) FSTUserDataConverter *dataConverter;

@end

NS_ASSUME_NONNULL_END
