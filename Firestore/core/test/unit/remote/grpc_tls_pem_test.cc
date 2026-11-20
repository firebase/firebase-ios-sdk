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

#include <string>
#include <vector>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

const char kBegin[] = "-----BEGIN CERTIFICATE-----\n";
const char kEnd[] = "-----END CERTIFICATE-----\n";

// Wraps `base64` in one CERTIFICATE block.
std::string Block(const std::string& base64) {
  return kBegin + base64 + "\n" + kEnd;
}

void ExpectDer(const std::string& pem, const std::vector<std::string>& der) {
  util::StatusOr<std::vector<std::string>> result = SplitPemCertificates(pem);
  ASSERT_TRUE(result.ok()) << result.status().error_message();
  EXPECT_EQ(result.ValueOrDie(), der);
}

void ExpectError(const std::string& pem, const std::string& message) {
  util::StatusOr<std::vector<std::string>> result = SplitPemCertificates(pem);
  ASSERT_FALSE(result.ok()) << "pem: " << pem;
  EXPECT_EQ(result.status().code(), Error::kErrorInvalidArgument);
  EXPECT_EQ(result.status().error_message(), message) << "pem: " << pem;
}

TEST(GrpcTlsPemTest, SplitsBlocksIntoDer) {
  // "TUlJQg==" and "AAEC/w==" are base64 for "MIIB" and {0, 1, 2, 0xff}.
  const std::string second("\x00\x01\x02\xff", 4);
  ExpectDer(Block("TUlJQg=="), {"MIIB"});
  ExpectDer(Block("TUlJQg==") + Block("AAEC/w=="), {"MIIB", second});
}

TEST(GrpcTlsPemTest, AllowsAsciiWhitespace) {
  ExpectDer(" \t\r\n" + Block("TUlJQg==") + "\n\n", {"MIIB"});
  ExpectDer(Block("TUlJ\nQg=="), {"MIIB"});
  ExpectDer(Block("TUlJQg==") + "\r\n" + Block("TUlJQg=="), {"MIIB", "MIIB"});
}

TEST(GrpcTlsPemTest, RejectsMissingCertificates) {
  ExpectError("", "No PEM certificates found in peer chain");
  ExpectError(" \n", "No PEM certificates found in peer chain");
}

TEST(GrpcTlsPemTest, RejectsTextOutsideBlocks) {
  const std::string outside =
      "Unexpected text outside PEM CERTIFICATE block in peer chain";
  ExpectError("not a PEM block at all", outside);
  ExpectError("junk\n" + Block("TUlJQg=="), outside);
  ExpectError(Block("TUlJQg==") + "junk", outside);
  ExpectError(kEnd + Block("TUlJQg=="), outside);
  // Non-ASCII (Unicode) whitespace is not whitespace here.
  ExpectError("\xc2\xa0" + Block("TUlJQg=="), outside);
}

TEST(GrpcTlsPemTest, RejectsUnclosedBlocks) {
  ExpectError(std::string(kBegin) + "TUlJQg==\n",
              "Unclosed PEM CERTIFICATE block in peer chain");
}

TEST(GrpcTlsPemTest, RejectsInvalidPayloads) {
  const std::string invalid = "Invalid base64 payload in PEM CERTIFICATE block";
  ExpectError(std::string(kBegin) + kEnd, invalid);
  ExpectError(Block("!!!!"), invalid);
  ExpectError(Block("TUlJ\xc2\xa0Qg=="), invalid);
  // A nested BEGIN marker is part of the payload, which is not base64.
  ExpectError(std::string(kBegin) + "TUlJQg==\n" + Block("TUlJQg=="), invalid);
}

TEST(GrpcTlsPemTest, ReturnsNoPartialOutputOnFailure) {
  // The first block is valid, the second is not: nothing is returned.
  util::StatusOr<std::vector<std::string>> result =
      SplitPemCertificates(Block("TUlJQg==") + Block("!!!!"));
  EXPECT_FALSE(result.ok());
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
