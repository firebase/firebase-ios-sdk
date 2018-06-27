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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_DATASTORE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_DATASTORE_H_

#include <memory>

#include <grpc/grpc.h>
#include <grpcpp/completion_queue.h>
#include <grpcpp/generic/generic_stub.h>
#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor.h"

#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace remote {

class Datastore {
 public:
  Datastore();
  ~Datastore();

  Datastore(const Datastore& other) = delete;
  Datastore(Datastore&& other) = delete;

  Datastore& operator=(const Datastore& other) = delete;
  Datastore& operator=(Datastore&& other) = delete;
};

class GrpcQueue {
  public:
    void Shutdown() {
      //FIREBASE_ASSERT_MESSAGE(!is_shutting_down_, "GrpcQueue cannot be shut down twice");
      is_shutting_down_ = true;
      impl_.Shutdown();
    }

    bool Next(void** tag, bool* ok) {
      return impl_.Next(tag, ok);
    }

    grpc::CompletionQueue* get_impl() { return &impl_; }

  private:
  grpc::CompletionQueue impl_;
  bool is_shutting_down_ = false;
};

class DatastoreImpl {
 public:
  DatastoreImpl(util::AsyncQueue* firestore_queue,
                const core::DatabaseInfo& database_info);

  // database_info_->database_id()

  static FirestoreErrorCode FromGrpcErrorCode(grpc::StatusCode grpc_error);
  std::unique_ptr<grpc::ClientContext> CreateContext(const absl::string_view token);
  std::unique_ptr<grpc::GenericClientAsyncReaderWriter> CreateGrpcCall(
      grpc::ClientContext* context, const absl::string_view path);

  // TODO
  void Shutdown();
  // DatastoreImpl::~DatastoreImpl() {
  //   grpc_queue_.Shutdown();
  //   dedicated_executor_->ExecuteBlocking([] {});
  // }

 private:
  void PollGrpcQueue();
  static std::unique_ptr<util::internal::Executor> CreateExecutor();

  grpc::GenericStub CreateStub() const;

  util::AsyncQueue* firestore_queue_;
  const core::DatabaseInfo* database_info_;

  std::unique_ptr<util::internal::Executor> dedicated_executor_;
  grpc::GenericStub stub_;
  grpc::CompletionQueue grpc_queue_;
  // GrpcQueue grpc_queue_;
};

    extern std::string pemRootCertsPath;

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_DATASTORE_H_
