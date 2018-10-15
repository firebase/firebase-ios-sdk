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

#include <algorithm>
#include <fstream>
#include <sstream>
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
using util::Status;
using util::StringFormat;

namespace {

const char* const kXGoogAPIClientHeader = "x-goog-api-client";
const char* const kGoogleCloudResourcePrefix = "google-cloud-resource-prefix";

std::string MakeString(absl::string_view view) {
  return view.data() ? std::string{view.data(), view.size()} : std::string{};
}

}  // namespace

GrpcConnection::TestCredentials* GrpcConnection::test_credentials_ = nullptr;

GrpcConnection::GrpcConnection(const DatabaseInfo& database_info,
                               util::AsyncQueue* worker_queue,
                               grpc::CompletionQueue* grpc_queue,
                               ConnectivityMonitor* connectivity_monitor)
    : database_info_{&database_info},
      worker_queue_{NOT_NULL(worker_queue)},
      grpc_queue_{NOT_NULL(grpc_queue)},
      connectivity_monitor_{NOT_NULL(connectivity_monitor)} {
  RegisterConnectivityMonitor();
}

void GrpcConnection::Shutdown() {
  // Fast finish any pending calls. This will not trigger the observers.
  // Calls may unregister themselves on finish, so make a protective copy.
  auto active_calls = active_calls_;
  for (GrpcCall* call : active_calls) {
    call->FinishImmediately();
  }
}

std::unique_ptr<grpc::ClientContext> GrpcConnection::CreateContext(
    const Token& credential) const {
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
                   reinterpret_cast<const char*>(FIRFirestoreVersionString)));

  // This header is used to improve routing and project isolation by the
  // backend.
  const DatabaseId& db_id = database_info_->database_id();
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
    grpc_channel_ = CreateChannel();
    grpc_stub_ = absl::make_unique<grpc::GenericStub>(grpc_channel_);
  }
}

std::shared_ptr<grpc::Channel> GrpcConnection::CreateChannel() const {
  if (!test_credentials_) {
    return grpc::CreateChannel(
        database_info_->host(),
        grpc::SslCredentials(grpc::SslCredentialsOptions()));
  }

  if (test_credentials_->use_insecure_channel) {
    return grpc::CreateChannel(database_info_->host(),
                               grpc::InsecureChannelCredentials());
  }

  std::ifstream cert_file{test_credentials_->certificate_path};
  HARD_ASSERT(cert_file.good(),
              StringFormat("Unable to open root certificates at file path %s",
                           test_credentials_->certificate_path)
                  .c_str());
  std::stringstream cert_buffer;
  cert_buffer << cert_file.rdbuf();
  grpc::SslCredentialsOptions options;
  options.pem_root_certs = cert_buffer.str();

  grpc::ChannelArguments args;
  args.SetSslTargetNameOverride(test_credentials_->target_name);
  return grpc::CreateCustomChannel(database_info_->host(),
                                   grpc::SslCredentials(options), args);
}

std::unique_ptr<GrpcStream> GrpcConnection::CreateStream(
    absl::string_view rpc_name,
    const Token& token,
    GrpcStreamObserver* observer) {
  EnsureActiveStub();

  auto context = CreateContext(token);
  auto call =
      grpc_stub_->PrepareCall(context.get(), MakeString(rpc_name), grpc_queue_);
  return absl::make_unique<GrpcStream>(std::move(context), std::move(call),
                                       worker_queue_, this, observer);
}

std::unique_ptr<GrpcUnaryCall> GrpcConnection::CreateUnaryCall(
    absl::string_view rpc_name,
    const Token& token,
    const grpc::ByteBuffer& message) {
  EnsureActiveStub();

  auto context = CreateContext(token);
  auto call = grpc_stub_->PrepareUnaryCall(context.get(), MakeString(rpc_name),
                                           message, grpc_queue_);
  return absl::make_unique<GrpcUnaryCall>(std::move(context), std::move(call),
                                          worker_queue_, this, message);
}

std::unique_ptr<GrpcStreamingReader> GrpcConnection::CreateStreamingReader(
    absl::string_view rpc_name,
    const Token& token,
    const grpc::ByteBuffer& message) {
  EnsureActiveStub();

  auto context = CreateContext(token);
  auto call =
      grpc_stub_->PrepareCall(context.get(), MakeString(rpc_name), grpc_queue_);
  return absl::make_unique<GrpcStreamingReader>(
      std::move(context), std::move(call), worker_queue_, this, message);
}

void GrpcConnection::RegisterConnectivityMonitor() {
  connectivity_monitor_->AddCallback(
      [this](ConnectivityMonitor::NetworkStatus /*ignored*/) {
        // Calls may unregister themselves on finish, so make a protective copy.
        auto calls = active_calls_;
        for (GrpcCall* call : calls) {
          // This will trigger the observers.
          call->FinishAndNotify(Status{FirestoreErrorCode::Unavailable,
                                       "Network connectivity changed"});
        }
      });
}

void GrpcConnection::Register(GrpcCall* call) {
  active_calls_.push_back(call);
}

void GrpcConnection::Unregister(GrpcCall* call) {
  auto found = std::find(active_calls_.begin(), active_calls_.end(), call);
  HARD_ASSERT(found != active_calls_.end(), "Missing a gRPC call");
  active_calls_.erase(found);
}

/*static*/ void GrpcConnection::UseTestCertificate(
    absl::string_view certificate_path, absl::string_view target_name) {
  HARD_ASSERT(!certificate_path.empty(), "Empty path to test certificate");
  HARD_ASSERT(!target_name.empty(), "Empty SSL target name");

  if (!test_credentials_) {
    // Deliberately never deleted.
    test_credentials_ = new TestCredentials{};
  }

  test_credentials_->certificate_path =
      std::string{certificate_path.data(), certificate_path.size()};
  test_credentials_->target_name =
      std::string{target_name.data(), target_name.size()};
  // TODO(varconst): hostname if necessary.
}

/*static*/ void GrpcConnection::UseInsecureChannel() {
  if (!test_credentials_) {
    // Deliberately never deleted.
    test_credentials_ = new TestCredentials{};
  }

  test_credentials_->use_insecure_channel = true;
  // TODO(varconst): hostname if necessary.
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
