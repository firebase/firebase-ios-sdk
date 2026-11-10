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

#include "Firestore/core/src/remote/grpc_tls_target_host.h"

#include <string>
#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using Kind = TlsTargetHost::Kind;

void ExpectHost(absl::string_view target, absl::string_view host, Kind kind) {
  absl::optional<TlsTargetHost> parsed = ParseTlsTargetHost(target);
  ASSERT_TRUE(parsed.has_value()) << "target: " << target;
  EXPECT_EQ(parsed->host, host) << "target: " << target;
  EXPECT_EQ(parsed->kind, kind) << "target: " << target;
}

TEST(GrpcTlsTargetHostTest, DnsNames) {
  ExpectHost("firestore.googleapis.com", "firestore.googleapis.com",
             Kind::kDns);
  ExpectHost("firestore.googleapis.com:443", "firestore.googleapis.com",
             Kind::kDns);
  ExpectHost("localhost", "localhost", Kind::kDns);
  ExpectHost("localhost:8080", "localhost", Kind::kDns);
  ExpectHost("Mixed-Case.Example_host.test:1", "Mixed-Case.Example_host.test",
             Kind::kDns);
  ExpectHost("a:65535", "a", Kind::kDns);
}

TEST(GrpcTlsTargetHostTest, Ipv4Literals) {
  ExpectHost("127.0.0.1", "127.0.0.1", Kind::kIpv4);
  ExpectHost("127.0.0.1:50051", "127.0.0.1", Kind::kIpv4);
  ExpectHost("0.0.0.0", "0.0.0.0", Kind::kIpv4);
  ExpectHost("255.255.255.255:1", "255.255.255.255", Kind::kIpv4);
}

TEST(GrpcTlsTargetHostTest, Ipv6Literals) {
  ExpectHost("::1", "::1", Kind::kIpv6);
  ExpectHost("[::1]", "::1", Kind::kIpv6);
  ExpectHost("[::1]:443", "::1", Kind::kIpv6);
  ExpectHost("2001:db8::1", "2001:db8::1", Kind::kIpv6);
  ExpectHost("[2001:db8::1]:8443", "2001:db8::1", Kind::kIpv6);
  ExpectHost("[2001:0db8:0000:0000:0000:0000:0000:0001]",
             "2001:0db8:0000:0000:0000:0000:0000:0001", Kind::kIpv6);
  ExpectHost("[::ffff:127.0.0.1]:443", "::ffff:127.0.0.1", Kind::kIpv6);
  ExpectHost("[::ffff:7f00:1]:443", "::ffff:7f00:1", Kind::kIpv6);
  ExpectHost("1::", "1::", Kind::kIpv6);
  ExpectHost("::", "::", Kind::kIpv6);
  ExpectHost("1:2:3:4:5:6:7:8", "1:2:3:4:5:6:7:8", Kind::kIpv6);
  ExpectHost("1:2:3:4:5:6:1.2.3.4", "1:2:3:4:5:6:1.2.3.4", Kind::kIpv6);
}

TEST(GrpcTlsTargetHostTest, Ipv6ZoneIdsAreStripped) {
  ExpectHost("fe80::1%en0", "fe80::1", Kind::kIpv6);
  ExpectHost("[fe80::1%en0]:443", "fe80::1", Kind::kIpv6);
  ExpectHost("[fe80::1%25eth0]", "fe80::1", Kind::kIpv6);
}

TEST(GrpcTlsTargetHostTest, RejectsMalformedTargets) {
  const std::vector<std::string> malformed = {
      "",
      ":443",
      "host:",
      "host:notaport",
      "host:65536",
      "host:123456",
      "host:-1",
      "host:+1",
      "https://firestore.googleapis.com",
      "dns:///firestore.googleapis.com",
      "unix:/tmp/grpc.sock",
      "user@host",
      "host/path",
      "host?query",
      "host#fragment",
      "a,b",
      "*.example.com",
      "foo:bar:baz",
      "firestore.googleapis.com\n",
      " firestore.googleapis.com",
      "fire store",
      "fire\tstore",
      std::string("firestore.googleapis.com\0evil", 29),
      "f\xc3\xbcr.example",
      "[example.com]:443",
      "[127.0.0.1]",
      "[::1",
      "::1]",
      "[]",
      "[]:443",
      "[::1]:",
      "[::1]:notaport",
      "[::1]junk",
      "[[::1]]",
      "[fe80::1%]:443",
      "fe80::1%",
      "%en0",
      "[%en0]",
      "1.2.3",
      "1.2.3.4.5",
      "256.0.0.1",
      "1.2.3.04",
      "1..2.3",
      "1.2.3.",
      ":::",
      "1:::2",
      "1::2::3",
      "1:2:3:4:5:6:7:8:9",
      "1:2:3:4:5:6:7",
      "12345::1",
      "g::1",
      "1:2:3:4:5:6:7:1.2.3.4",
      "::1.2.3",
      "::1.2.3.4:5",
  };
  for (const std::string& target : malformed) {
    absl::optional<TlsTargetHost> parsed = ParseTlsTargetHost(target);
    EXPECT_FALSE(parsed.has_value())
        << "target: '" << target << "' parsed as '"
        << parsed.value_or(TlsTargetHost{}).host << "'";
  }
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
