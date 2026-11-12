/*
 * Copyright 2026 Google LLC
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

// Smoke tests that perform real TLS handshakes with the production Firestore
// endpoint (firestore.googleapis.com:443) through the same credentials
// provider and channel construction that the SDK uses in production.
//
// Unlike the loopback tests (tls_loopback_server.h, tls_test_pki.h), these
// tests exercise the platform's real trust store against Google's real
// certificate chain. They need outbound network access, so they skip unless
// the environment variable FIRESTORE_TLS_PROD_SMOKE is set to "1". CI jobs
// that set it get hard failures, never skips, if the network is unreachable.
//
// No credentials are used: the RPCs are unauthenticated and are expected to be
// rejected by the backend. Any rejection by the backend (as opposed to
// UNAVAILABLE, which is how gRPC reports a failed TLS handshake) proves that
// the handshake succeeded.

#include <cstdlib>

#include <chrono>
#include <future>
#include <iostream>
#include <memory>
#include <string>
#include <thread>
#include <utility>

#include "Firestore/core/src/core/database_info.h"
#include "Firestore/core/src/credentials/auth_token.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/remote/connectivity_monitor.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/src/remote/firebase_metadata_provider_noop.h"
#include "Firestore/core/src/remote/grpc_completion.h"
#include "Firestore/core/src/remote/grpc_connection.h"
#include "Firestore/core/src/remote/grpc_tls_credentials_provider.h"
#include "Firestore/core/src/remote/grpc_unary_call.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/warnings.h"
#include "Firestore/core/test/unit/remote/create_noop_connectivity_monitor.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/strings/ascii.h"
#include "absl/strings/match.h"
#include "absl/types/optional.h"
#include "gtest/gtest.h"

#if !defined(__APPLE__) && !defined(_WIN32)
#include "Firestore/core/src/remote/grpc_tls_credentials_provider_linux.h"
#endif

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/security/credentials.h"
#include "grpcpp/support/byte_buffer.h"
#include "grpcpp/support/channel_arguments.h"
#include "grpcpp/support/slice.h"
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using core::DatabaseInfo;
using credentials::AuthToken;
using model::DatabaseId;
using util::AsyncQueue;
using util::Status;
using util::StatusOr;

constexpr const char* kProdHost = "firestore.googleapis.com";
constexpr const char* kCommitRpc = "/google.firestore.v1.Firestore/Commit";

// A project ID that does not exist. The backend rejects requests for it, which
// is fine: the tests only care whether the TLS handshake succeeded.
constexpr const char* kDummyProjectId =
    "firestore-tls-prod-smoke-no-such-project";

// A name that no publicly-trusted certificate can cover: `.invalid` is
// reserved by RFC 2606.
constexpr const char* kMismatchedTargetName =
    "firestore-tls-prod-smoke.invalid";

constexpr const char* kEnableEnvVar = "FIRESTORE_TLS_PROD_SMOKE";

constexpr auto kRpcTimeout = std::chrono::seconds(60);

absl::optional<std::string> GetEnv(const char* name) {
#if defined(_WIN32)
  // The required buffer size (not the length of the value).
  size_t value_size = 0;
  errno_t result = getenv_s(&value_size, nullptr, 0, name);
  if (result || value_size == 0) return absl::nullopt;

  std::string value(value_size, '\0');
  result = getenv_s(&value_size, &value[0], value_size, name);
  if (result) return absl::nullopt;

  value.resize(value_size - 1);
  return value;
#else
  const char* value = getenv(name);
  if (!value) return absl::nullopt;
  return std::string{value};
#endif  // defined(_WIN32)
}

bool ProdSmokeEnabled() {
  absl::optional<std::string> value = GetEnv(kEnableEnvVar);
  return value.has_value() && *value == "1";
}

#define SKIP_UNLESS_PROD_SMOKE_ENABLED()                                       \
  do {                                                                         \
    if (!ProdSmokeEnabled()) {                                                 \
      GTEST_SKIP() << "Production TLS smoke test skipped: set "                \
                   << kEnableEnvVar                                            \
                   << "=1 to run it (requires network access to " << kProdHost \
                   << ":443).";                                                \
    }                                                                          \
  } while (0)

void Log(const std::string& message) {
  std::cout << "[ prod-tls ] " << message << std::endl;
}

/**
 * Returns whether `message` looks like it describes a TLS or certificate
 * failure, as opposed to a rejection by the Firestore backend.
 */
bool LooksLikeTlsFailure(const std::string& message) {
  std::string lower = absl::AsciiStrToLower(message);
  for (const char* needle :
       {"handshake", "ssl", "tls", "certificate", "x509", "peer name",
        "failed to connect", "unavailable", "connections to all backends"}) {
    if (absl::StrContains(lower, needle)) return true;
  }
  return false;
}

/**
 * Returns whether a status returned for an RPC to the production endpoint
 * proves that the TLS handshake succeeded: the backend answered, so the
 * request was sent over an established TLS connection.
 */
bool BackendAnswered(Error code, const std::string& message) {
  switch (code) {
    // How gRPC reports connection and TLS handshake failures.
    case Error::kErrorUnavailable:
    // No answer at all.
    case Error::kErrorDeadlineExceeded:
    case Error::kErrorCancelled:
    // gRPC uses these for some transport-level failures.
    case Error::kErrorUnknown:
    case Error::kErrorInternal:
      return false;
    default:
      return !LooksLikeTlsFailure(message);
  }
}

/**
 * Returns a serialized empty request message. (A default-constructed
 * `grpc::ByteBuffer` is not a valid message: gRPC cancels a call that tries to
 * send one.) The backend rejects it with INVALID_ARGUMENT.
 */
grpc::ByteBuffer EmptyRequest() {
  grpc::Slice empty;
  return grpc::ByteBuffer{&empty, 1};
}

/**
 * Makes one unary `Commit` call to `kProdHost` on a channel built from
 * `credentials`, optionally overriding the TLS target name (used for SNI and
 * for certificate hostname verification). Uses a private completion queue and
 * blocks until the call finishes.
 */
grpc::Status DirectCommitCall(
    const std::shared_ptr<grpc::ChannelCredentials>& credentials,
    absl::optional<std::string> target_name_override = absl::nullopt) {
  grpc::ChannelArguments args;
  if (target_name_override) {
    args.SetSslTargetNameOverride(*target_name_override);
  }
  std::shared_ptr<grpc::Channel> channel =
      grpc::CreateCustomChannel(kProdHost, credentials, args);
  grpc::GenericStub stub{channel};

  grpc::CompletionQueue queue;
  grpc::ClientContext context;
  context.set_deadline(std::chrono::system_clock::now() + kRpcTimeout);
  std::string resource =
      std::string("projects/") + kDummyProjectId + "/databases/(default)";
  context.AddMetadata("google-cloud-resource-prefix", resource);
  context.AddMetadata("x-goog-request-params", resource);

  grpc::ByteBuffer request = EmptyRequest();
  grpc::ByteBuffer response;
  grpc::Status status;
  std::unique_ptr<grpc::GenericClientAsyncResponseReader> call =
      stub.PrepareUnaryCall(&context, kCommitRpc, request, &queue);
  call->StartCall();
  int finish_tag = 0;
  call->Finish(&response, &status, &finish_tag);

  void* tag = nullptr;
  bool ok = false;
  EXPECT_TRUE(queue.Next(&tag, &ok));
  EXPECT_EQ(tag, &finish_tag);

  queue.Shutdown();
  while (queue.Next(&tag, &ok)) {
  }
  return status;
}

std::string Describe(const grpc::Status& status) {
  return "gRPC status " + std::to_string(status.error_code()) + ": " +
         status.error_message();
}

std::string Describe(const Status& status) {
  return "status " + std::to_string(static_cast<int>(status.code())) + ": " +
         status.error_message();
}

/**
 * Expects a direct call with `CreateDefaultTlsCredentials()` to be answered by
 * the backend, proving that the endpoint is reachable and the TLS handshake
 * succeeds with the platform trust store.
 */
void ExpectDefaultCredentialsReachProduction() {
  grpc::Status status = DirectCommitCall(CreateDefaultTlsCredentials());
  Log(std::string("Direct Commit to ") + kProdHost + " -> " + Describe(status));
  EXPECT_TRUE(BackendAnswered(static_cast<Error>(status.error_code()),
                              status.error_message()))
      << "Expected the backend to reject the unauthenticated request (which "
         "proves the TLS handshake succeeded), but got "
      << Describe(status);
}

/**
 * Hosts a `GrpcConnection` to the production endpoint, wired up the way
 * `Datastore` does it: a worker `AsyncQueue`, a gRPC completion queue polled
 * on a dedicated thread, and production channel creation
 * (`GrpcConnection::CreateChannel` -> `CreateDefaultTlsCredentials`).
 */
class ProdConnection {
 public:
  ProdConnection()
      : worker_queue_{testutil::AsyncQueueForTesting()},
        database_info_{DatabaseId{kDummyProjectId}, "prod-tls-smoke", kProdHost,
                       /*ssl_enabled=*/true},
        connectivity_monitor_{CreateNoOpConnectivityMonitor()},
        metadata_provider_{CreateFirebaseMetadataProviderNoOp()},
        connection_{database_info_, worker_queue_, &grpc_queue_,
                    connectivity_monitor_.get(), metadata_provider_.get()} {
    polling_thread_ = std::thread([this] {
      void* tag = nullptr;
      bool ok = false;
      while (grpc_queue_.Next(&tag, &ok)) {
        static_cast<GrpcCompletion*>(tag)->Complete(ok);
      }
    });
  }

  ~ProdConnection() {
    // Same order as `Datastore::Shutdown`.
    worker_queue_->EnqueueBlocking([this] {
      connection_.Shutdown();
      call_.reset();
    });
    grpc_queue_.Shutdown();
    polling_thread_.join();
    worker_queue_->EnqueueBlocking([] {});
  }

  /**
   * Makes one unauthenticated unary `Commit` call through
   * `GrpcConnection::CreateUnaryCall`. Returns `nullopt` if the call did not
   * finish in time.
   */
  absl::optional<Status> CommitCall() {
    auto done = std::make_shared<std::promise<Status>>();
    std::future<Status> result = done->get_future();

    worker_queue_->EnqueueBlocking([&] {
      call_ =
          connection_.CreateUnaryCall(kCommitRpc, AuthToken::Unauthenticated(),
                                      /*app_check_token=*/"", EmptyRequest());
      call_->Start([done](const StatusOr<grpc::ByteBuffer>& response) {
        done->set_value(response.status());
      });
    });

    if (result.wait_for(kRpcTimeout) != std::future_status::ready) {
      // Cancels the call without invoking its callback.
      worker_queue_->EnqueueBlocking([this] { connection_.Shutdown(); });
      return absl::nullopt;
    }
    return result.get();
  }

 private:
  std::shared_ptr<AsyncQueue> worker_queue_;
  DatabaseInfo database_info_;
  std::unique_ptr<ConnectivityMonitor> connectivity_monitor_;
  std::unique_ptr<FirebaseMetadataProvider> metadata_provider_;
  grpc::CompletionQueue grpc_queue_;
  GrpcConnection connection_;
  std::unique_ptr<GrpcUnaryCall> call_;
  std::thread polling_thread_;
};

}  // namespace

// (a) The production code path, end to end: `GrpcConnection` creates the
// channel with `CreateDefaultTlsCredentials()` and the system trust store, and
// the backend answers an unauthenticated RPC.
TEST(GrpcTlsProdSmokeTest, GrpcConnectionHandshakesWithProduction) {
  SKIP_UNLESS_PROD_SMOKE_ENABLED();

  ProdConnection connection;
  absl::optional<Status> status = connection.CommitCall();
  ASSERT_TRUE(status.has_value())
      << "RPC to " << kProdHost << " did not finish within "
      << kRpcTimeout.count() << "s";

  Log(std::string("GrpcConnection Commit to ") + kProdHost + " -> " +
      Describe(*status));
  EXPECT_TRUE(BackendAnswered(status->code(), status->error_message()))
      << "Expected the backend to reject the unauthenticated request (which "
         "proves the TLS handshake succeeded), but got "
      << Describe(*status);
}

// (a) The same check through the platform credentials directly. This is the
// positive half of the controls below, which differ from it in one input only.
TEST(GrpcTlsProdSmokeTest, DefaultCredentialsHandshakeWithProduction) {
  SKIP_UNLESS_PROD_SMOKE_ENABLED();

  ExpectDefaultCredentialsReachProduction();
}

// (b) Negative control: the same endpoint, credentials and RPC, but verified
// against a target name that Google's certificate cannot cover. The handshake
// must fail, which shows that the positive tests above prove real certificate
// verification rather than a permissive verifier.
TEST(GrpcTlsProdSmokeTest, DefaultCredentialsRejectHostnameMismatch) {
  SKIP_UNLESS_PROD_SMOKE_ENABLED();

  // UNAVAILABLE also means "network unreachable", so first show that the
  // endpoint is reachable and the only thing that differs is the target name.
  ExpectDefaultCredentialsReachProduction();
  if (HasFailure()) return;

  grpc::Status status =
      DirectCommitCall(CreateDefaultTlsCredentials(), kMismatchedTargetName);
  Log(std::string("Direct Commit to ") + kProdHost + " as " +
      kMismatchedTargetName + " -> " + Describe(status));
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAVAILABLE)
      << "Expected the TLS handshake to fail, but got " << Describe(status);
}

// (c) Where the trust anchors come from.
TEST(GrpcTlsProdSmokeTest, ReportsTrustSource) {
  SKIP_UNLESS_PROD_SMOKE_ENABLED();

#if defined(__APPLE__)
  Log("Trust source: Security.framework (Apple system trust store)");
#elif defined(_WIN32)
  Log("Trust source: Windows (see grpc_tls_credentials_provider.h)");
#else
  LinuxTrustStore store = LoadLinuxTrustStore();
  Log("Trust source: " + store.anchor_source + " (" +
      std::to_string(store.anchor_count) + " anchors)");
  EXPECT_TRUE(store.has_anchors());
  EXPECT_FALSE(store.anchor_source.empty());
#endif
}

#if !defined(__APPLE__) && !defined(_WIN32)

// (c) No bundled-certificate fallback: with no system trust anchors, the Linux
// provider must fail the handshake with production instead of silently
// falling back to an embedded root bundle (which would make it succeed).
TEST(GrpcTlsProdSmokeTest, LinuxWithoutSystemAnchorsDoesNotFallBackToBundle) {
  SKIP_UNLESS_PROD_SMOKE_ENABLED();

  LinuxTrustConfig config;
  config.ca_path = "/nonexistent/firestore-tls-prod-smoke/no-roots.pem";
  ASSERT_FALSE(LoadLinuxTrustStore(config).has_anchors());

  // As above: show the endpoint is reachable with the system trust store.
  ExpectDefaultCredentialsReachProduction();
  if (HasFailure()) return;

  grpc::Status status = DirectCommitCall(CreateLinuxTlsCredentials(config));
  Log(std::string("Direct Commit to ") + kProdHost +
      " with no trust anchors -> " + Describe(status));
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAVAILABLE)
      << "Expected the TLS handshake to fail without trust anchors, but got "
      << Describe(status);
}

#endif  // !defined(__APPLE__) && !defined(_WIN32)

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
