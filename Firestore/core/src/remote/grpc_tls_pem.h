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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_PEM_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_PEM_H_

#include <string>
#include <vector>

#include "Firestore/core/src/util/statusor.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace remote {

/**
 * Splits a PEM-encoded certificate chain, as gRPC passes it to certificate
 * verifiers, into DER-encoded certificates, in order.
 *
 * Fails closed: returns an `InvalidArgument` status describing the problem
 * unless `pem` consists of one or more `CERTIFICATE` blocks separated only by
 * ASCII whitespace, each with a non-empty, valid base64 payload. Stray, nested,
 * or unclosed markers and any other text are rejected.
 */
util::StatusOr<std::vector<std::string>> SplitPemCertificates(
    absl::string_view pem);

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_PEM_H_
