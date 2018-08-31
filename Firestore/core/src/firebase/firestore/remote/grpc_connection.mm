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

#include "Firestore/core/src/firebase/firestore/remote/grpc_connection.h"

#include <string>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "absl/memory/memory.h"
#include "grpcpp/create_channel.h"

#import "Firestore/Source/API/FIRFirestoreVersion.h"

namespace firebase {
namespace firestore {
namespace remote {

using core::DatabaseInfo;
using model::DatabaseId;
using util::StringFormat;

namespace {

std::string MakeString(absl::string_view view) {
  return view.data() ? std::string{view.data(), view.size()} : std::string{};
}

const char *const kXGoogAPIClientHeader = "x-goog-api-client";
const char *const kGoogleCloudResourcePrefix = "google-cloud-resource-prefix";

}  // namespace

GrpcConnection::GrpcConnection(util::AsyncQueue *firestore_queue,
                               const DatabaseInfo &database_info,
                               grpc::CompletionQueue *grpc_queue)
    : firestore_queue_{firestore_queue},
      database_info_{&database_info},
      grpc_queue_{grpc_queue},
      grpc_channel_{CreateGrpcChannel()},
      grpc_stub_{grpc_channel_} {
}

std::shared_ptr<grpc::Channel> GrpcConnection::CreateGrpcChannel() const {
  return grpc::CreateChannel(
      database_info_->host(),
      grpc::SslCredentials(grpc::SslCredentialsOptions()));
}

void GrpcConnection::EnsureValidGrpcStub() {
  // TODO(varconst): find out in which cases a gRPC channel might shut down.
  // This might be overkill.
  if (!grpc_channel_ ||
      grpc_channel_->GetState(false) == GRPC_CHANNEL_SHUTDOWN) {
    grpc_channel_ = CreateGrpcChannel();
    grpc_stub_ = grpc::GenericStub{grpc_channel_};
  }
}

std::unique_ptr<GrpcStream> GrpcConnection::OpenGrpcStream(
    absl::string_view token,
    absl::string_view path,
    GrpcStreamObserver *observer) {
  EnsureValidGrpcStub();

  auto context = CreateGrpcContext(token);
  auto reader_writer = CreateGrpcReaderWriter(context.get(), path);
  return absl::make_unique<GrpcStream>(
      std::move(context), std::move(reader_writer), observer, firestore_queue_);
}

std::unique_ptr<grpc::ClientContext> GrpcConnection::CreateGrpcContext(
    absl::string_view token) const {
  auto context = absl::make_unique<grpc::ClientContext>();
  if (token.data()) {
    context->set_credentials(
        grpc::AccessTokenCredentials(std::string{token.data(), token.size()}));
  }

  // TODO(dimond): This should ideally also include the grpc version, however,
  // gRPC defines the version as a macro, so it would be hardcoded based on
  // version we have at compile time of the Firestore library, rather than the
  // version available at runtime/at compile time by the user of the library.
  //
  // TODO(varconst): this should be configurable (e.g., "gl-cpp" or similar for
  // C++ SDK, etc.).
  context->AddMetadata(
      kXGoogAPIClientHeader,
      StringFormat("gl-objc/ fire/%s grpc/",
                   reinterpret_cast<const char *>(FIRFirestoreVersionString)));

  // This header is used to improve routing and project isolation by the
  // backend.
  const DatabaseId &db_id = database_info_->database_id();
  context->AddMetadata(kGoogleCloudResourcePrefix,
                       StringFormat("projects/%s/databases/%s",
                                    db_id.project_id(), db_id.database_id()));
  return context;
}

std::unique_ptr<grpc::GenericClientAsyncReaderWriter>
GrpcConnection::CreateGrpcReaderWriter(grpc::ClientContext *context,
                                       absl::string_view path) {
  return grpc_stub_.PrepareCall(context, MakeString(path), grpc_queue_);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
