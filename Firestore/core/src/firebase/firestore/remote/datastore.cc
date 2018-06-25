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

#include "Firestore/core/src/firebase/firestore/remote/datastore.h"

#include <grpcpp/security/credentials.h>

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"

namespace firebase {
namespace firestore {
namespace remote {

Datastore::Datastore() {
}

Datastore::~Datastore() {
}

DatastoreImpl::DatastoreImpl(util::AsyncQueue* firestore_queue) :
  dedicated_executor_{DatastoreImpl::CreateExecutor()},
  stub_{CreateStub()},
  firestore_queue_{firestore_queue}
{
  dedicated_executor_->Execute([this] {
    PollGrpcQueue();
  });
}

std::unique_ptr<grpc::GenericClientAsyncReaderWriter> DatastoreImpl::CreateGrpcCall(
    grpc::ClientContext* context, const absl::string_view path) {
  return stub_.PrepareCall(context, path.data(), &grpc_queue_);
}

void DatastoreImpl::PollGrpcQueue() {
  FIREBASE_ASSERT_MESSAGE(dedicated_executor_->IsCurrentExecutor(), "TODO");

  void* tag = nullptr;
  bool ok = false;
  while (grpc_queue_.Next(&tag, &ok)) {
    auto* operation = static_cast<StreamOperation*>(tag);
    firestore_queue_->Enqueue([operation, ok] {
      operation->Finalize(ok);
      delete operation;
    });
  }
}

std::unique_ptr<util::internal::Executor> DatastoreImpl::CreateExecutor() {
  const auto queue = dispatch_queue_create(
      "com.google.firebase.firestore.datastore", DISPATCH_QUEUE_SERIAL);
  return absl::make_unique<util::internal::ExecutorLibdispatch>(queue);
}

grpc::GenericStub DatastoreImpl::CreateStub() const {
  if (pemRootCertsPath) {
    grpc::SslCredentialsOptions options;
    std::fstream file{pemRootCertsPath};
    std::stringstream buffer;
    buffer << file.rdbuf();
    const std::string cert = buffer.str();
    options.pem_root_certs = cert;

    grpc::ChannelArguments args;
    args.SetSslTargetNameOverride("test_cert_2");
    // args.SetSslTargetNameOverride("test_cert_4");
    return grpc::GenericStub{grpc::CreateCustomChannel(
        database_info_->host(), grpc::SslCredentials(options), args)};
  }
  return grpc::GenericStub{
      grpc::CreateChannel(database_info_->host(),
                          grpc::SslCredentials(grpc::SslCredentialsOptions()))};
}

const char* pemRootCertsPath = nullptr;

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
