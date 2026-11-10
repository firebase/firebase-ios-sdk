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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_H_

#include <memory>

#include "Firestore/core/src/util/warnings.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/security/credentials.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {

/**
 * Creates the default TLS `grpc::ChannelCredentials` for the current platform.
 *
 * On Apple platforms, certificate chain and hostname verification are delegated
 * to `Security.framework` so that apps inherit Apple's system root store,
 * enterprise MDM roots, and background Over-The-Air (`com.apple.trustd.valid`)
 * CA revocations. Evaluation is asynchronous (`SecTrustEvaluateAsyncWithError`
 * on a private dispatch queue, via `AsyncTlsVerifier`), so IPC to `trustd`
 * never blocks gRPC threads.
 *
 * On Linux and other non-Apple, non-Windows platforms, certificate chains are
 * validated against the system CA store (`SSL_CERT_FILE`/`SSL_CERT_DIR` or the
 * distro bundle), certificates on the distro distrust lists are rejected, and
 * the hostname is checked against the leaf's subjectAltNames. See
 * `grpc_tls_credentials_provider_linux.h`.
 *
 * On Windows, certificate chain, trust, and hostname verification are
 * delegated to CryptoAPI (`CertGetCertificateChain` and
 * `CertVerifyCertificateChainPolicy`), so apps honor the Windows certificate
 * stores, including enterprise roots, automatic root updates, and the
 * `Disallowed` store. Evaluation runs on the Windows thread pool (via
 * `AsyncTlsVerifier`), so it never blocks gRPC threads. See
 * `grpc_tls_credentials_provider_windows.h`.
 */
std::shared_ptr<grpc::ChannelCredentials> CreateDefaultTlsCredentials();

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_H_
