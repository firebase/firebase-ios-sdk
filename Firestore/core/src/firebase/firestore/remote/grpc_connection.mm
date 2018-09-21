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
#include <utility>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "absl/memory/memory.h"
#include "grpcpp/create_channel.h"

#import "Firestore/Source/API/FIRFirestoreVersion.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::Token;
using core::DatabaseInfo;
using model::DatabaseId;
using util::StringFormat;

namespace {

const char *const kXGoogAPIClientHeader = "x-goog-api-client";
const char *const kGoogleCloudResourcePrefix = "google-cloud-resource-prefix";

std::string MakeString(absl::string_view view) {
  return view.data() ? std::string{view.data(), view.size()} : std::string{};
}

}  // namespace

GrpcConnection::GrpcConnection(
    const DatabaseInfo &database_info,
    util::AsyncQueue *worker_queue,
    grpc::CompletionQueue *grpc_queue,
    std::unique_ptr<ConnectivityMonitor> connectivity_monitor)
    : database_info_{&database_info},
      worker_queue_{worker_queue},
      grpc_queue_{grpc_queue},
      connectivity_monitor_{std::move(connectivity_monitor)} {
  RegisterConnectivityMonitor();
}

std::unique_ptr<grpc::ClientContext> GrpcConnection::CreateContext(
    const Token &credential) const {
  absl::string_view token = credential.user().is_authenticated()
                                ? credential.token()
                                : absl::string_view{};

  auto context = absl::make_unique<grpc::ClientContext>();
  if (token.data()) {
    context->set_credentials(grpc::AccessTokenCredentials(MakeString(token)));
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

void GrpcConnection::EnsureActiveStub() {
  // TODO(varconst): find out in which cases a gRPC channel might shut down.
  // This might be overkill.
  if (!grpc_channel_ || grpc_channel_->GetState(/*try_to_connect=*/false) ==
                            GRPC_CHANNEL_SHUTDOWN) {
    LOG_DEBUG("Creating Firestore stub.");
    grpc_channel_ = grpc::CreateChannel(
        database_info_->host(),
        grpc::SslCredentials(grpc::SslCredentialsOptions()));
    grpc_stub_ = absl::make_unique<grpc::GenericStub>(grpc_channel_);
  }
}

std::unique_ptr<GrpcStream> GrpcConnection::CreateStream(
    absl::string_view rpc_name,
    const Token &token,
    GrpcStreamObserver *observer) {
  LOG_DEBUG("Creating gRPC stream");

  EnsureActiveStub();

  auto context = CreateContext(token);
  auto call =
      grpc_stub_->PrepareCall(context.get(), MakeString(rpc_name), grpc_queue_);
  return absl::make_unique<GrpcStream>(std::move(context), std::move(call),
                                       observer, worker_queue_);
}

std::unique_ptr<GrpcStreamingReader> GrpcConnection::CreateStreamingReader(
    absl::string_view rpc_name,
    const Token &token,
    const grpc::ByteBuffer &message) {
  LOG_DEBUG("Creating gRPC streaming reader");

  EnsureActiveStub();

  auto context = CreateContext(token);
  auto call =
      grpc_stub_->PrepareCall(context.get(), MakeString(rpc_name), grpc_queue_);
  return absl::make_unique<GrpcStreamingReader>(
      std::move(context), std::move(call), worker_queue_, message);
}

void GrpcConnection::RegisterConnectivityMonitor() {
  connectivity_monitor_->AddCallback(
      [this](ConnectivityMonitor::NetworkStatus /*ignored*/) {
        // TODO(varconst): implement
      });
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
