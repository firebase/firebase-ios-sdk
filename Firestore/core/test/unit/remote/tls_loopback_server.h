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

#ifndef FIRESTORE_CORE_TEST_UNIT_REMOTE_TLS_LOOPBACK_SERVER_H_
#define FIRESTORE_CORE_TEST_UNIT_REMOTE_TLS_LOOPBACK_SERVER_H_

// In-process gRPC TLS echo server for TLS credentials tests on non-Apple
// platforms. (The Apple tests have an equivalent in
// grpc_tls_credentials_provider_apple_test.mm.)
#if !defined(__APPLE__)

#include <memory>
#include <mutex>
#include <string>
#include <thread>

#include "Firestore/core/src/util/warnings.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/channel.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/generic/async_generic_service.h"
#include "grpcpp/security/credentials.h"
#include "grpcpp/server.h"
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace tls_testing {

/**
 * An ephemeral 127.0.0.1 gRPC TLS server that echoes the request payload of
 * any unary method. Built on `grpc::AsyncGenericService` so that it needs no
 * generated service code.
 */
class TlsLoopbackServer {
 public:
  /**
   * Starts the server with the given PEM private key and PEM certificate chain
   * (leaf first). Check `started()` before use.
   */
  TlsLoopbackServer(const std::string& private_key_pem,
                    const std::string& cert_chain_pem);
  ~TlsLoopbackServer();

  TlsLoopbackServer(const TlsLoopbackServer&) = delete;
  TlsLoopbackServer& operator=(const TlsLoopbackServer&) = delete;

  bool started() const {
    return server_ != nullptr && port_ > 0;
  }

  int port() const {
    return port_;
  }

  /** "127.0.0.1:<port>", suitable for `grpc::CreateCustomChannel`. */
  std::string target() const;

 private:
  void SpawnCall();
  void ServeLoop();

  int port_ = 0;
  grpc::AsyncGenericService generic_service_;
  std::unique_ptr<grpc::ServerCompletionQueue> cq_;
  std::unique_ptr<grpc::Server> server_;
  std::mutex mu_;
  bool shutting_down_ = false;
  std::thread server_thread_;
};

/**
 * Creates a channel to `server` using `credentials`, with the TLS target name
 * overridden to `tls_target_name` (so certificates can name a DNS host while
 * the connection goes to 127.0.0.1).
 */
std::shared_ptr<grpc::Channel> CreateLoopbackChannel(
    const TlsLoopbackServer& server,
    const std::shared_ptr<grpc::ChannelCredentials>& credentials,
    const std::string& tls_target_name);

/**
 * Performs one unary echo RPC with a 5 second deadline. On success, stores the
 * echoed payload in `out_response` (if non-null).
 */
grpc::Status PerformUnaryEcho(const std::shared_ptr<grpc::Channel>& channel,
                              const std::string& payload,
                              std::string* out_response = nullptr);

}  // namespace tls_testing
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // !defined(__APPLE__)

#endif  // FIRESTORE_CORE_TEST_UNIT_REMOTE_TLS_LOOPBACK_SERVER_H_
