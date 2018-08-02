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

#include <fstream>
#include <sstream>

#include <grpcpp/create_channel.h>
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

#include <chrono>
#include <iostream>
#include <thread>

namespace firebase {
namespace firestore {
namespace remote {

namespace util = firebase::firestore::util;
using auth::CredentialsProvider;
using auth::Token;
using core::DatabaseInfo;
using model::DatabaseId;
using model::DocumentKey;

const char *const kXGoogAPIClientHeader = "x-goog-api-client";
const char *const kGoogleCloudResourcePrefix = "google-cloud-resource-prefix";

Datastore::Datastore(util::AsyncQueue *firestore_queue,
                             const core::DatabaseInfo &database_info)
    : firestore_queue_{firestore_queue},
      database_info_{&database_info},
      dedicated_executor_{Datastore::CreateExecutor()},
      grpc_stub_{CreateGrpcStub()} {
  std::cout << "\nOBC " << this << " datastore created\n\n";
  dedicated_executor_->Execute([this] { PollGrpcQueue(); });
}

void Datastore::Shutdown() {
  std::cout << "\nOBC " << this << " datastore start SHUTdown\n\n";
  grpc_queue_.Shutdown();
  // Drain the executor.
  dedicated_executor_->ExecuteBlocking([] {});
  std::cout << "\nOBC " << this << " datastore end SHUTdown\n\n";
}

FirestoreErrorCode Datastore::FromGrpcErrorCode(grpc::StatusCode grpc_error) {
  FIREBASE_ASSERT_MESSAGE(grpc_error >= grpc::CANCELLED && grpc_error <= grpc::UNAUTHENTICATED,
                          "Unknown GRPC error code: %s", grpc_error);
  return static_cast<FirestoreErrorCode>(grpc_error);
}

std::unique_ptr<grpc::GenericClientAsyncReaderWriter> Datastore::CreateGrpcCall(
    grpc::ClientContext *context, const absl::string_view path) {
  return grpc_stub_.PrepareCall(context, path.data(), &grpc_queue_);
}

void Datastore::PollGrpcQueue() {
  FIREBASE_ASSERT_MESSAGE(dedicated_executor_->IsCurrentExecutor(), "TODO");

  void *tag = nullptr;
  bool ok = false;
  while (grpc_queue_.Next(&tag, &ok)) {
    std::cout << "\nOBC " << this << " got tag\n\n";
    auto* operation = static_cast<GrpcStreamOperation*>(tag);
    firestore_queue_->Enqueue([operation, ok] {
      operation->Finalize(ok);
      delete operation;
    });
  }
}

std::unique_ptr<util::internal::Executor> Datastore::CreateExecutor() {
  const auto queue =
      dispatch_queue_create("com.google.firebase.firestore.datastore", DISPATCH_QUEUE_SERIAL);
  return absl::make_unique<util::internal::ExecutorLibdispatch>(queue);
}

grpc::GenericStub Datastore::CreateGrpcStub() const {
  if (!pemRootCertsPath.empty()) {
    grpc::SslCredentialsOptions options;
    std::fstream file{pemRootCertsPath};
    std::stringstream buffer;
    buffer << file.rdbuf();
    const std::string cert = buffer.str();
    options.pem_root_certs = cert;

    grpc::ChannelArguments args;
    args.SetSslTargetNameOverride("test_cert_2");
    return grpc::GenericStub{
        grpc::CreateCustomChannel(database_info_->host(), grpc::SslCredentials(options), args)};
  }
  return grpc::GenericStub{grpc::CreateChannel(
      database_info_->host(), grpc::SslCredentials(grpc::SslCredentialsOptions()))};
}

std::unique_ptr<grpc::ClientContext> Datastore::CreateContext(const absl::string_view token) {
  auto context = absl::make_unique<grpc::ClientContext>();

  if (token.data()) {
    context->set_credentials(grpc::AccessTokenCredentials(token.data()));
  }

  const model::DatabaseId database_id = database_info_->database_id();

  std::string client_header{"gl-objc/ fire/"};
  for (auto cur = FIRFirestoreVersionString; *cur != '\0'; ++cur) {
    client_header += *cur;
  }
  client_header += " grpc/";
  context->AddMetadata(kXGoogAPIClientHeader, client_header);
  // This header is used to improve routing and project isolation by the backend.
  const std::string resource_prefix = std::string{"projects/"} + database_id.project_id() +
                                      "/databases/" + database_id.database_id();
  context->AddMetadata(kGoogleCloudResourcePrefix, resource_prefix);
  return context;
}

std::string pemRootCertsPath;

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
