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

#include "Firestore/core/src/firebase/firestore/remote/datastore.h"

#include <algorithm>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/strings/match.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace {

absl::string_view ToStringView(grpc::string_ref grpc_str) {
  return {grpc_str.begin(), grpc_str.size()};
}

std::string ToString(grpc::string_ref grpc_str) {
  return {grpc_str.begin(), grpc_str.end()};
}

}  // namespace
util::Status Datastore::ConvertStatus(grpc::Status from) {
  if (from.ok()) {
    return {};
  }

  grpc::StatusCode error_code = from.error_code();
  HARD_ASSERT(
      error_code >= grpc::CANCELLED && error_code <= grpc::UNAUTHENTICATED,
      "Unknown gRPC error code: %s", error_code);

  return {static_cast<FirestoreErrorCode>(error_code), from.error_message()};
}

GrpcStream::MetadataT Datastore::ExtractWhitelistedHeaders(
    const GrpcStream::MetadataT &headers) {
  std::string whitelist[] = {"date", "x-google-backends",
                             "x-google-netmon-label", "x-google-service",
                             "x-google-gfe-request-trace"};

  GrpcStream::MetadataT whitelisted_headers;
  for (const auto &kv : headers) {
    auto found = std::find_if(std::begin(whitelist), std::end(whitelist),
                              [&](const std::string& str) {
                                return str.size() == kv.first.size() &&
                                       absl::StartsWithIgnoreCase(
                                           str, ToStringView(kv.first));
                              });
    if (found != std::end(whitelist)) {
      whitelisted_headers.emplace(kv.first, kv.second);
    }
  }

  return whitelisted_headers;
}

std::string Datastore::GetWhitelistedHeadersAsString(
    const GrpcStream::MetadataT &headers) {
  auto whitelisted_headers = ExtractWhitelistedHeaders(headers);

  std::string result;
  for (const auto &kv : whitelisted_headers) {
    result += ToString(kv.first);
    result += ": ";
    result += ToString(kv.second);
    result += "\n";
  }
  return result;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
