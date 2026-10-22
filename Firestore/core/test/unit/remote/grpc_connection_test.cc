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

#include "Firestore/core/src/remote/grpc_connection.h"

#include <cstddef>
#include <cstdint>

#include <array>
#include <iomanip>
#include <memory>
#include <sstream>
#include <string>
#include <unordered_set>
#include <utility>
#include <vector>

#include "Firestore/core/src/credentials/auth_token.h"
#include "Firestore/core/src/remote/connectivity_monitor.h"
#include "Firestore/core/src/remote/grpc_root_certificate_finder.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/warnings.h"
#include "Firestore/core/test/unit/remote/grpc_stream_tester.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/grpcpp.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {

using core::DatabaseInfo;
using credentials::AuthToken;
using credentials::User;
using util::AsyncQueue;
using util::Status;
using util::StatusOr;

using NetworkStatus = ConnectivityMonitor::NetworkStatus;
using ResponsesT = grpc::ByteBuffer;

namespace {

class FakeConnectivityMonitor : public ConnectivityMonitor {
 public:
  explicit FakeConnectivityMonitor(
      const std::shared_ptr<AsyncQueue>& worker_queue)
      : ConnectivityMonitor{worker_queue} {
    SetInitialStatus(NetworkStatus::Available);
  }

  void set_status(NetworkStatus new_status) {
    MaybeInvokeCallbacks(new_status);
  }
};

bool IsConnectivityChange(const Status& status) {
  return status.code() == Error::kErrorUnavailable;
}

class ConnectivityObserver : public GrpcStreamObserver {
 public:
  void OnStreamStart() override {
  }
  void OnStreamRead(const grpc::ByteBuffer&) override {
  }
  void OnStreamFinish(const util::Status& status) override {
    if (IsConnectivityChange(status)) {
      ++connectivity_change_count_;
    }
  }

  int connectivity_change_count() const {
    return connectivity_change_count_;
  }
  int connectivity_change_count_ = 0;
};

constexpr uint32_t RightRotate(uint32_t value, uint32_t bits) {
  return (value >> bits) | (value << (32u - bits));
}

// Self-contained RFC 6234 SHA-256 implementation so unit tests do not depend on
// BoringSSL/OpenSSL header paths, which differ between CMake (`<openssl/...>`)
// and CocoaPods `gRPC-Core` (`<openssl_grpc/...>`).
std::string Sha256Hex(const std::vector<uint8_t>& data) {
  static constexpr std::array<uint32_t, 64> kRoundConstants = {
      0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u, 0x3956c25bu,
      0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u, 0xd807aa98u, 0x12835b01u,
      0x243185beu, 0x550c7dc3u, 0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u,
      0xc19bf174u, 0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu,
      0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau, 0x983e5152u,
      0xa831c66du, 0xb00327c8u, 0xbf597fc7u, 0xc6e00bf3u, 0xd5a79147u,
      0x06ca6351u, 0x14292967u, 0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu,
      0x53380d13u, 0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
      0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u, 0xd192e819u,
      0xd6990624u, 0xf40e3585u, 0x106aa070u, 0x19a4c116u, 0x1e376c08u,
      0x2748774cu, 0x34b0bcb5u, 0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu,
      0x682e6ff3u, 0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u,
      0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u,
  };

  std::array<uint32_t, 8> state = {
      0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au,
      0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u,
  };

  const uint64_t bit_len = static_cast<uint64_t>(data.size()) * 8u;
  std::vector<uint8_t> padded = data;
  padded.push_back(0x80u);
  while ((padded.size() % 64u) != 56u) {
    padded.push_back(0x00u);
  }
  for (int shift = 56; shift >= 0; shift -= 8) {
    padded.push_back(static_cast<uint8_t>((bit_len >> shift) & 0xffu));
  }

  for (size_t offset = 0; offset < padded.size(); offset += 64u) {
    std::array<uint32_t, 64> w{};
    for (size_t i = 0; i < 16u; ++i) {
      size_t j = offset + i * 4u;
      w[i] = (static_cast<uint32_t>(padded[j]) << 24u) |
             (static_cast<uint32_t>(padded[j + 1u]) << 16u) |
             (static_cast<uint32_t>(padded[j + 2u]) << 8u) |
             static_cast<uint32_t>(padded[j + 3u]);
    }
    for (size_t i = 16u; i < 64u; ++i) {
      uint32_t s0 = RightRotate(w[i - 15u], 7u) ^ RightRotate(w[i - 15u], 18u) ^
                    (w[i - 15u] >> 3u);
      uint32_t s1 = RightRotate(w[i - 2u], 17u) ^ RightRotate(w[i - 2u], 19u) ^
                    (w[i - 2u] >> 10u);
      w[i] = w[i - 16u] + s0 + w[i - 7u] + s1;
    }

    uint32_t a = state[0];
    uint32_t b = state[1];
    uint32_t c = state[2];
    uint32_t d = state[3];
    uint32_t e = state[4];
    uint32_t f = state[5];
    uint32_t g = state[6];
    uint32_t h = state[7];

    for (size_t i = 0; i < 64u; ++i) {
      uint32_t s1 =
          RightRotate(e, 6u) ^ RightRotate(e, 11u) ^ RightRotate(e, 25u);
      uint32_t ch = (e & f) ^ ((~e) & g);
      uint32_t temp1 = h + s1 + ch + kRoundConstants[i] + w[i];
      uint32_t s0 =
          RightRotate(a, 2u) ^ RightRotate(a, 13u) ^ RightRotate(a, 22u);
      uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
      uint32_t temp2 = s0 + maj;

      h = g;
      g = f;
      f = e;
      e = d + temp1;
      d = c;
      c = b;
      b = a;
      a = temp1 + temp2;
    }

    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
    state[5] += f;
    state[6] += g;
    state[7] += h;
  }

  std::ostringstream out;
  out << std::hex << std::setfill('0');
  for (uint32_t word : state) {
    out << std::setw(8) << word;
  }
  return out.str();
}

int Base64DigitValue(char ch) {
  if (ch >= 'A' && ch <= 'Z') {
    return ch - 'A';
  }
  if (ch >= 'a' && ch <= 'z') {
    return ch - 'a' + 26;
  }
  if (ch >= '0' && ch <= '9') {
    return ch - '0' + 52;
  }
  if (ch == '+') {
    return 62;
  }
  if (ch == '/') {
    return 63;
  }
  return -1;
}

bool DecodeBase64PemBody(const std::string& body, std::vector<uint8_t>* out) {
  std::string clean;
  clean.reserve(body.size());
  for (char ch : body) {
    if (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
      continue;
    }
    clean.push_back(ch);
  }
  if (clean.empty() || (clean.size() % 4u) != 0u) {
    return false;
  }

  out->clear();
  out->reserve((clean.size() / 4u) * 3u);
  for (size_t i = 0; i < clean.size(); i += 4u) {
    int v0 = Base64DigitValue(clean[i]);
    int v1 = Base64DigitValue(clean[i + 1u]);
    if (v0 < 0 || v1 < 0) {
      return false;
    }

    bool pad2 = (clean[i + 2u] == '=');
    bool pad3 = (clean[i + 3u] == '=');
    if ((pad2 || pad3) && (i + 4u != clean.size())) {
      return false;
    }
    if (pad2 && !pad3) {
      return false;
    }

    int v2 = pad2 ? 0 : Base64DigitValue(clean[i + 2u]);
    int v3 = pad3 ? 0 : Base64DigitValue(clean[i + 3u]);
    if (v2 < 0 || v3 < 0) {
      return false;
    }

    uint32_t triple = (static_cast<uint32_t>(v0) << 18u) |
                      (static_cast<uint32_t>(v1) << 12u) |
                      (static_cast<uint32_t>(v2) << 6u) |
                      static_cast<uint32_t>(v3);
    out->push_back(static_cast<uint8_t>((triple >> 16u) & 0xffu));
    if (!pad2) {
      out->push_back(static_cast<uint8_t>((triple >> 8u) & 0xffu));
    }
    if (!pad3) {
      out->push_back(static_cast<uint8_t>(triple & 0xffu));
    }
  }
  // Every DER-encoded X.509 certificate starts with ASN.1 SEQUENCE (0x30).
  return !out->empty() && (*out)[0] == 0x30u;
}

struct ParsedPemBundle {
  std::unordered_set<std::string> sha256_fingerprints;
  size_t cert_count = 0;
  size_t decode_failures = 0;
};

ParsedPemBundle ParsePemCertificateFingerprints(const std::string& pem) {
  static constexpr char kBeginMarker[] = "-----BEGIN CERTIFICATE-----";
  static constexpr char kEndMarker[] = "-----END CERTIFICATE-----";
  static constexpr size_t kBeginLen = sizeof(kBeginMarker) - 1u;
  static constexpr size_t kEndLen = sizeof(kEndMarker) - 1u;

  ParsedPemBundle result;
  size_t pos = 0;
  while (true) {
    size_t begin = pem.find(kBeginMarker, pos);
    if (begin == std::string::npos) {
      break;
    }
    size_t body_start = begin + kBeginLen;
    size_t end = pem.find(kEndMarker, body_start);
    if (end == std::string::npos) {
      ++result.decode_failures;
      break;
    }

    std::vector<uint8_t> der;
    if (DecodeBase64PemBody(pem.substr(body_start, end - body_start), &der)) {
      ++result.cert_count;
      result.sha256_fingerprints.insert(Sha256Hex(der));
    } else {
      ++result.decode_failures;
    }
    pos = end + kEndLen;
  }
  return result;
}

}  // namespace

class GrpcConnectionTest : public testing::Test {
 public:
  GrpcConnectionTest()
      : worker_queue{testutil::AsyncQueueForTesting()},
        connectivity_monitor{
            absl::make_unique<FakeConnectivityMonitor>(worker_queue)},
        tester{worker_queue, connectivity_monitor.get()} {
  }

  void SetNetworkStatus(NetworkStatus new_status) {
    worker_queue->EnqueueBlocking(
        [&] { connectivity_monitor->set_status(new_status); });
    // Make sure the callback executes.
    worker_queue->EnqueueBlocking([] {});
  }

  std::shared_ptr<AsyncQueue> worker_queue;
  std::unique_ptr<FakeConnectivityMonitor> connectivity_monitor = nullptr;
  GrpcStreamTester tester;
};

TEST_F(GrpcConnectionTest, GrpcStreamsNoticeChangeInConnectivity) {
  ConnectivityObserver observer;

  std::unique_ptr<GrpcStream> stream = tester.CreateStream(&observer);
  stream->Start();
  EXPECT_EQ(observer.connectivity_change_count(), 0);

  SetNetworkStatus(NetworkStatus::Available);
  // Same status shouldn't trigger a callback.
  EXPECT_EQ(observer.connectivity_change_count(), 0);

  tester.KeepPollingGrpcQueue();
  SetNetworkStatus(NetworkStatus::Unavailable);
  EXPECT_EQ(observer.connectivity_change_count(), 1);
}

TEST_F(GrpcConnectionTest, GrpcStreamingCallsNoticeChangeInConnectivity) {
  int change_count = 0;
  std::unique_ptr<GrpcStreamingReader> streaming_call =
      tester.CreateStreamingReader();
  streaming_call->Start(
      0, [&](const std::vector<ResponsesT>) {},
      [&](const util::Status& st, bool) {
        if (IsConnectivityChange(st)) {
          ++change_count;
        }
      });

  SetNetworkStatus(NetworkStatus::Available);
  // Same status shouldn't trigger a callback.
  EXPECT_EQ(change_count, 0);

  tester.KeepPollingGrpcQueue();
  SetNetworkStatus(NetworkStatus::AvailableViaCellular);
  EXPECT_EQ(change_count, 1);
}

TEST_F(GrpcConnectionTest, GrpcUnaryCallsNoticeChangeInConnectivity) {
  int change_count = 0;
  std::unique_ptr<GrpcUnaryCall> unary_call = tester.CreateUnaryCall();
  unary_call->Start([&](const StatusOr<grpc::ByteBuffer>& result) {
    if (IsConnectivityChange(result.status())) {
      ++change_count;
    }
  });

  SetNetworkStatus(NetworkStatus::Available);
  // Same status shouldn't trigger a callback.
  EXPECT_EQ(change_count, 0);

  tester.KeepPollingGrpcQueue();
  SetNetworkStatus(NetworkStatus::AvailableViaCellular);
  EXPECT_EQ(change_count, 1);
}

TEST_F(GrpcConnectionTest, ConnectivityChangeWithSeveralActiveCalls) {
  int changes_count = 0;

  std::unique_ptr<GrpcStreamingReader> foo = tester.CreateStreamingReader();
  foo->Start(
      0, [&](const std::vector<ResponsesT>) {},
      [&](const util::Status&, bool) {
        ++changes_count;
        foo.reset();
      });

  std::unique_ptr<GrpcStreamingReader> bar = tester.CreateStreamingReader();
  bar->Start(
      0, [&](const std::vector<ResponsesT>) {},
      [&](const util::Status&, bool) {
        ++changes_count;
        bar.reset();
      });

  std::unique_ptr<GrpcStreamingReader> baz = tester.CreateStreamingReader();
  baz->Start(
      0, [&](const std::vector<ResponsesT>) {},
      [&](const util::Status&, bool) {
        ++changes_count;
        baz.reset();
      });

  tester.KeepPollingGrpcQueue();
  // Calls will be unregistering themselves with `GrpcConnection` as it notifies
  // them, make sure nothing breaks.
  EXPECT_NO_THROW(SetNetworkStatus(NetworkStatus::Unavailable));
  EXPECT_EQ(changes_count, 3);
}

TEST_F(GrpcConnectionTest, ShutdownFastFinishesActiveCalls) {
  class NoFinishObserver : public GrpcStreamObserver {
   public:
    void OnStreamStart() override {
    }
    void OnStreamRead(const grpc::ByteBuffer&) override {
    }
    void OnStreamFinish(const util::Status&) override {
      FAIL() << "Observer shouldn't have been invoked";
    }
  };

  NoFinishObserver observer;
  std::unique_ptr<GrpcStream> foo = tester.CreateStream(&observer);
  foo->Start();

  std::unique_ptr<GrpcStreamingReader> bar = tester.CreateStreamingReader();
  bar->Start(
      0, [&](const std::vector<ResponsesT>) {},
      [&](const util::Status&, bool) {
        FAIL() << "Callback shouldn't have been invoked";
      });

  std::unique_ptr<GrpcUnaryCall> baz = tester.CreateUnaryCall();
  baz->Start([](const StatusOr<grpc::ByteBuffer>&) {
    FAIL() << "Callback shouldn't have been invoked";
  });

  tester.KeepPollingGrpcQueue();
  worker_queue->EnqueueBlocking([&] { tester.grpc_connection()->Shutdown(); });

  // Destroying a call will throw if it hasn't been properly shut down.
  EXPECT_NO_THROW(foo.reset());
  EXPECT_NO_THROW(bar.reset());
  EXPECT_NO_THROW(baz.reset());
}

TEST_F(GrpcConnectionTest, EmbeddedRootCertificatesExcludeDistrustedCAs) {
  // Self-verify the SHA-256 helper against the FIPS 180-4 "abc" test vector.
  EXPECT_EQ(Sha256Hex({'a', 'b', 'c'}),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");

  const std::string pem = LoadGrpcRootCertificate();
  ASSERT_FALSE(pem.empty());

  const ParsedPemBundle bundle = ParsePemCertificateFingerprints(pem);
  EXPECT_EQ(bundle.decode_failures, 0u);
  // The Chrome Root Store bundle synced in grpc/grpc#43699 contains 99 roots.
  EXPECT_GE(bundle.cert_count, 90u);
  EXPECT_GE(bundle.sha256_fingerprints.size(), 90u);

  // Distrusted eMudhra (`emSign`) and Comodo cross-signing root CAs:
  // - emSign ECC Root CA - G3
  EXPECT_EQ(bundle.sha256_fingerprints.count(
                "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a8"
                "62cd5c57a36bbe6b"),
            0u);
  // - emSign Root TLS CA - G3
  EXPECT_EQ(bundle.sha256_fingerprints.count(
                "7dd78d5f4f13459a83dff9abbba62edbaf6f2d102bf257fd"
                "712f4d9f2746ed8d"),
            0u);
  // - AAA Certificate Services
  EXPECT_EQ(bundle.sha256_fingerprints.count(
                "d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a294878"
                "2bc83ee0ea699ef4"),
            0u);

  // Required Google Trust Services / GlobalSign roots and preserved
  // uncompromised `emSign Root CA - G1`:
  // - GTS Root R1
  EXPECT_EQ(bundle.sha256_fingerprints.count(
                "d947432abde7b7fa90fc2e6b59101b1280e0e1c7e4e40fa3"
                "c6887fff57a7f4cf"),
            1u);
  // - GTS Root R4
  EXPECT_EQ(bundle.sha256_fingerprints.count(
                "349dfa4058c5e263123b398ae795573c4e1313c83fe68f93"
                "556cd5e8031b3c7d"),
            1u);
  // - GlobalSign Root CA - R3
  EXPECT_EQ(bundle.sha256_fingerprints.count(
                "cbb522d7b7f127ad6a0113865bdf1cd4102e7d0759af635a"
                "7cf4720dc963c53b"),
            1u);
  // - GlobalSign Root CA - R6
  EXPECT_EQ(bundle.sha256_fingerprints.count(
                "2cabeafe37d06ca22aba7391c0033d25982952c453647349"
                "763a3ab5ad6ccf69"),
            1u);
  // - emSign Root CA - G1
  EXPECT_EQ(bundle.sha256_fingerprints.count(
                "40f6af0346a99aa1cd1d555a4e9cce62c7f9634603ee4066"
                "15833dc8c8d00367"),
            1u);

  grpc::SslCredentialsOptions ssl_options;
  ssl_options.pem_root_certs = pem;
  EXPECT_NE(grpc::SslCredentials(ssl_options), nullptr);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
