/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_FIRESTORE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_FIRESTORE_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <memory>
#include <mutex>  // NOLINT(build/c++11)
#include <string>
#include <utility>
#include "dispatch/dispatch.h"

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRApp;
@class FIRCollectionReference;
@class FIRFirestore;
@class FIRFirestoreSettings;
@class FIRQuery;
@class FIRTransaction;
@class FIRWriteBatch;
@class FSTFirestoreClient;

namespace firebase {
namespace firestore {
namespace api {

class DocumentReference;

class Firestore {
 public:
  using TransactionBlock = id _Nullable (^)(FIRTransaction*, NSError** error);
  using ErrorCompletion = void (^)(NSError* _Nullable error);
  using ResultOrErrorCompletion = void (^)(id _Nullable result,
                                           NSError* _Nullable error);

  Firestore() = default;

  Firestore(std::string project_id,
            std::string database,
            std::string persistence_key,
            std::unique_ptr<auth::CredentialsProvider> credentials_provider,
            std::unique_ptr<util::AsyncQueue> worker_queue,
            void* extension);

  const model::DatabaseId& database_id() const {
    return database_id_;
  }

  const std::string& persistence_key() const {
    return persistence_key_;
  }

  FSTFirestoreClient* client() {
    return client_;
  }

  util::AsyncQueue* worker_queue();

  void* extension() {
    return extension_;
  }

  FIRFirestoreSettings* settings() const;
  void set_settings(FIRFirestoreSettings* settings);

  FIRCollectionReference* GetCollection(absl::string_view collection_path);
  DocumentReference GetDocument(absl::string_view document_path);
  FIRWriteBatch* GetBatch();
  FIRQuery* GetCollectionGroup(NSString* collection_id);

  void RunTransaction(TransactionBlock update_block,
                      dispatch_queue_t queue,
                      ResultOrErrorCompletion completion);

  void Shutdown(ErrorCompletion completion);

  void EnableNetwork(ErrorCompletion completion);
  void DisableNetwork(ErrorCompletion completion);

 private:
  void EnsureClientConfigured();

  model::DatabaseId database_id_;
  std::unique_ptr<auth::CredentialsProvider> credentials_provider_;
  std::string persistence_key_;
  FSTFirestoreClient* client_ = nil;

  // Ownership will be transferred to `FSTFirestoreClient` as soon as the
  // client is created.
  std::unique_ptr<util::AsyncQueue> worker_queue_;

  void* extension_ = nullptr;

  FIRFirestoreSettings* settings_ = nil;

  mutable std::mutex mutex_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_FIRESTORE_H_
