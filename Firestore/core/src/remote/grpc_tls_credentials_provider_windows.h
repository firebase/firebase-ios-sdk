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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_WINDOWS_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_WINDOWS_H_

#include "Firestore/core/src/remote/grpc_tls_credentials_provider.h"

#if defined(_WIN32)

#include <windows.h>  // NOLINT(build/include_order)

#include <wincrypt.h>  // NOLINT(build/include_order)

#include <functional>
#include <memory>

#include "Firestore/core/src/remote/grpc_tls_async_verification.h"
#include "Firestore/core/src/util/warnings.h"
#include "absl/strings/string_view.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {

/**
 * Options for the Windows CryptoAPI certificate verifier.
 */
struct WindowsTrustConfig {
  /**
   * The certificate chain engine used to build and validate chains.
   *
   * When null (the default), the current user's default engine is used, so
   * trust follows the Windows certificate stores: the system and enterprise
   * (Group Policy) roots, automatic root updates, and the `Disallowed` store.
   *
   * Tests set this to an engine restricted to their own roots (for example,
   * one created with `CERT_CHAIN_ENGINE_CONFIG::hExclusiveRoot`). The engine
   * is not owned and must outlive every verification that uses it, including
   * asynchronous ones that are still running after their gRPC call was
   * cancelled.
   */
  HCERTCHAINENGINE chain_engine = nullptr;

  /**
   * Test hook: if set, runs on the worker thread before each asynchronous
   * evaluation, so tests can hold an evaluation in flight.
   */
  std::function<void()> before_async_evaluation;
};

/**
 * Verifies a PEM-encoded X.509 peer certificate chain (leaf first) for the
 * host in `target_name` using Windows CryptoAPI.
 *
 * The leaf is checked with `CertGetCertificateChain`, using the remaining
 * certificates as untrusted intermediates, and then with
 * `CertVerifyCertificateChainPolicy(CERT_CHAIN_POLICY_SSL)` for a server
 * named by the host in `target_name` (`host`, `host:port`, or `[ipv6]:port`).
 * This covers path building, expiry, the server-auth EKU, explicit distrust,
 * and hostname matching. Returns `UNAUTHENTICATED` with a description on any
 * failure.
 *
 * This call can block: CryptoAPI may fetch missing intermediates (AIA) or
 * root updates over the network. Never call it on a gRPC thread.
 */
grpc::Status VerifyWindowsTlsCertificateChain(
    absl::string_view pem_chain,
    absl::string_view target_name,
    const WindowsTrustConfig& config = {});

/**
 * Creates gRPC `TlsCredentials` that verify servers with Windows CryptoAPI.
 *
 * Verification runs asynchronously on the Windows thread pool so that it
 * never blocks gRPC's threads.
 */
std::shared_ptr<grpc::ChannelCredentials> CreateWindowsTlsCredentials(
    const WindowsTrustConfig& config = {});

/**
 * Creates the `AsyncTlsVerifier` used by `CreateWindowsTlsCredentials()`:
 * evaluations and cancellation deliveries run on the Windows thread pool.
 * Exposed for tests.
 */
std::unique_ptr<AsyncTlsVerifier> CreateWindowsTlsVerifier(
    const WindowsTrustConfig& config = {});

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(_WIN32)

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_WINDOWS_H_
