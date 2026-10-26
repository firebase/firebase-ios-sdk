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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_APPLE_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_APPLE_H_

#include "Firestore/core/src/remote/grpc_tls_credentials_provider.h"

#if defined(__APPLE__)

#import <CoreFoundation/CoreFoundation.h>

#include <memory>
#include <string>

#include "Firestore/core/src/util/warnings.h"
#include "absl/strings/string_view.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {

/**
 * Evaluates a PEM-encoded X.509 peer certificate chain for `target_name` using
 * Apple's `Security.framework` (`SecPolicyCreateSSL` +
 * `SecTrustEvaluateWithError`).
 *
 * If `anchor_certs` (an array of `SecCertificateRef`s) is non-null, trust
 * evaluation is restricted exclusively to those anchor certificates via
 * `SecTrustSetAnchorCertificates` and `SecTrustSetAnchorCertificatesOnly(true)`
 * (intended for deterministic unit and loopback tests). When `anchor_certs` is
 * null, standard Apple OS, MDM, and `com.apple.trustd.valid` OTA trust settings
 * apply.
 */
grpc::Status VerifyAppleTlsCertificateChain(absl::string_view pem_chain,
                                            absl::string_view target_name,
                                            CFArrayRef anchor_certs = nullptr);

/**
 * Creates gRPC `TlsCredentials` backed by Apple's `Security.framework`
 * certificate verifier. Passing a non-null `anchor_certs` array restricts trust
 * evaluation exclusively to those custom anchors (for testing).
 */
std::shared_ptr<grpc::ChannelCredentials> CreateAppleTlsCredentials(
    CFArrayRef anchor_certs = nullptr);

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(__APPLE__)

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_APPLE_H_
