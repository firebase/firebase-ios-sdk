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
 * to `Security.framework` (`SecTrustEvaluateWithError`) so that apps inherit
 * Apple's system root store, enterprise MDM roots, and background Over-The-Air
 * (`com.apple.trustd.valid`) CA revocations.
 *
 * On non-Apple platforms, credentials are backed by the embedded `roots.pem`
 * certificate bundle via `LoadGrpcRootCertificate()`.
 */
std::shared_ptr<grpc::ChannelCredentials> CreateDefaultTlsCredentials();

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_H_
