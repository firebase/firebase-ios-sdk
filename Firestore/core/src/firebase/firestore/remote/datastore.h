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

class DatastoreImpl {
 public:
  explicit DatastoreImpl(util::AsyncQueue* firestore_queue);
  std::unique_ptr<grpc::GenericClientAsyncReaderWriter> CreateGrpcCall(grpc::ClientContext* context,
      const absl::string_view path);

// TODO
// DatastoreImpl::~DatastoreImpl() {
//   grpc_queue_.Shutdown();
//   dedicated_executor_->ExecuteBlocking([] {});
// }

 private:
  void PollGrpcQueue();
  static std::unique_ptr<util::internal::Executor> CreateExecutor();

  grpc::GenericStub CreateStub() const;

  std::unique_ptr<util::internal::Executor> dedicated_executor_;
  grpc::GenericStub stub_;
  grpc::CompletionQueue grpc_queue_;

  util::AsyncQueue* firestore_queue_;
};

const char* pemRootCertsPath = nullptr;

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_DATASTORE_H_
