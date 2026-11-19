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

#include "Firestore/core/src/remote/grpc_tls_pem.h"

#include <utility>

#include "absl/strings/ascii.h"
#include "absl/strings/escaping.h"
#include "absl/strings/strip.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

constexpr absl::string_view kBeginMarker = "-----BEGIN CERTIFICATE-----";
constexpr absl::string_view kEndMarker = "-----END CERTIFICATE-----";

bool Fail(std::string* error, absl::string_view reason) {
  if (error != nullptr) {
    *error = std::string(reason);
  }
  return false;
}

}  // namespace

bool SplitPemCertificates(absl::string_view pem,
                          std::vector<std::string>* der_certificates,
                          std::string* error) {
  der_certificates->clear();
  while (true) {
    // RFC 7468 allows only ASCII whitespace between blocks;
    // `StripLeadingAsciiWhitespace` does not strip non-ASCII (Unicode) spaces.
    pem = absl::StripLeadingAsciiWhitespace(pem);
    if (pem.empty()) {
      break;
    }
    if (!absl::ConsumePrefix(&pem, kBeginMarker)) {
      return Fail(error,
                  "Unexpected text outside PEM CERTIFICATE block in peer "
                  "chain");
    }
    size_t end = pem.find(kEndMarker);
    if (end == absl::string_view::npos) {
      return Fail(error, "Unclosed PEM CERTIFICATE block in peer chain");
    }
    // `Base64Unescape` skips ASCII whitespace but rejects everything else
    // outside the base64 alphabet, including the `-` of a nested marker.
    std::string der;
    if (!absl::Base64Unescape(pem.substr(0, end), &der) || der.empty()) {
      return Fail(error, "Invalid base64 payload in PEM CERTIFICATE block");
    }
    der_certificates->push_back(std::move(der));
    pem.remove_prefix(end + kEndMarker.size());
  }
  if (der_certificates->empty()) {
    return Fail(error, "No PEM certificates found in peer chain");
  }
  return true;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
