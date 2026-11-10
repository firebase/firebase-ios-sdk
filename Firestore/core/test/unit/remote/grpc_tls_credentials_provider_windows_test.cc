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

#if defined(_WIN32)
// `CERT_CHAIN_ENGINE_CONFIG::hExclusiveRoot` is declared only when targeting
// Windows 7 or later, but the build targets Vista (see compiler_setup.cmake).
// This must come before any header that includes <windows.h>.
#if !defined(_WIN32_WINNT) || _WIN32_WINNT < 0x0601
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0601
#endif
#endif  // defined(_WIN32)

#include "Firestore/core/src/remote/grpc_tls_credentials_provider_windows.h"

#if defined(_WIN32)

#include <chrono>              // NOLINT(build/c++11)
#include <condition_variable>  // NOLINT(build/c++11)
#include <cstring>
#include <future>  // NOLINT(build/c++11)
#include <memory>
#include <mutex>  // NOLINT(build/c++11)
#include <string>
#include <thread>  // NOLINT(build/c++11)
#include <utility>
#include <vector>

#include "Firestore/core/src/remote/grpc_tls_async_verification.h"
#include "Firestore/core/src/util/warnings.h"
#include "Firestore/core/test/unit/remote/tls_loopback_server.h"
#include "Firestore/core/test/unit/remote/tls_test_pki.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpc/credentials.h"
#include "grpcpp/security/tls_certificate_verifier.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using ::testing::HasSubstr;
using tls_testing::CreateLoopbackChannel;
using tls_testing::CreateTestPki;
using tls_testing::PemChain;
using tls_testing::PerformUnaryEcho;
using tls_testing::TestCertificate;
using tls_testing::TestPki;
using tls_testing::TlsLoopbackServer;

constexpr const char* kHost = "loopback.firestore.test";
constexpr auto kTimeout = std::chrono::seconds(30);

constexpr DWORD kCertEncoding = X509_ASN_ENCODING | PKCS_7_ASN_ENCODING;

/**
 * Creates a certificate chain engine that trusts exactly `roots`, so the tests
 * neither depend on nor modify the machine's root store. Returns a config that
 * shares ownership of the engine (and its root store), so evaluations still
 * running after a test body returns keep them alive.
 */
WindowsTrustConfig ExclusiveRootConfig(
    const std::vector<const TestCertificate*>& roots) {
  WindowsTrustConfig config;
  HCERTSTORE store = CertOpenStore(CERT_STORE_PROV_MEMORY, 0, 0,
                                   CERT_STORE_CREATE_NEW_FLAG, nullptr);
  if (store == nullptr) {
    ADD_FAILURE() << "CertOpenStore failed: " << GetLastError();
    return config;
  }
  for (const TestCertificate* root : roots) {
    const std::string& der = root->cert_der();
    if (!CertAddEncodedCertificateToStore(
            store, kCertEncoding, reinterpret_cast<const BYTE*>(der.data()),
            static_cast<DWORD>(der.size()), CERT_STORE_ADD_ALWAYS, nullptr)) {
      ADD_FAILURE() << "CertAddEncodedCertificateToStore failed: "
                    << GetLastError();
    }
  }

  CERT_CHAIN_ENGINE_CONFIG engine_config = {};
  engine_config.cbSize = sizeof(engine_config);
  engine_config.hExclusiveRoot = store;
  HCERTCHAINENGINE engine = nullptr;
  if (!CertCreateCertificateChainEngine(&engine_config, &engine)) {
    ADD_FAILURE() << "CertCreateCertificateChainEngine failed: "
                  << GetLastError();
    CertCloseStore(store, 0);
    return config;
  }
  config.chain_engine =
      std::shared_ptr<void>(engine, [store](void* engine_handle) {
        CertFreeCertificateChainEngine(
            static_cast<HCERTCHAINENGINE>(engine_handle));
        CertCloseStore(store, 0);
      });
  return config;
}

/**
 * Adds a certificate to the current user's `Disallowed` store for the lifetime
 * of this object. Adding to `Disallowed` (unlike `Root`) needs no elevation and
 * shows no UI.
 *
 * Note: this modifies the real per-user store. If the process dies before the
 * destructor runs, the (freshly generated, never reused) test certificate stays
 * in `Disallowed`, which is harmless but should be removed by hand on a
 * developer machine (certmgr.msc > Untrusted Certificates).
 */
class ScopedDisallowedCertificate {
 public:
  explicit ScopedDisallowedCertificate(const TestCertificate& cert) {
    store_ = CertOpenStore(CERT_STORE_PROV_SYSTEM_W, 0, 0,
                           CERT_SYSTEM_STORE_CURRENT_USER, L"Disallowed");
    if (store_ == nullptr) {
      ADD_FAILURE() << "Opening the Disallowed store failed: "
                    << GetLastError();
      return;
    }
    const std::string& der = cert.cert_der();
    if (!CertAddEncodedCertificateToStore(
            store_, kCertEncoding, reinterpret_cast<const BYTE*>(der.data()),
            static_cast<DWORD>(der.size()), CERT_STORE_ADD_REPLACE_EXISTING,
            &added_)) {
      ADD_FAILURE() << "Adding to the Disallowed store failed: "
                    << GetLastError();
      added_ = nullptr;
    }
  }

  ~ScopedDisallowedCertificate() {
    if (added_ != nullptr) {
      // Frees `added_`, even on failure.
      CertDeleteCertificateFromStore(added_);
    }
    if (store_ != nullptr) {
      CertCloseStore(store_, 0);
    }
  }

  ScopedDisallowedCertificate(const ScopedDisallowedCertificate&) = delete;
  ScopedDisallowedCertificate& operator=(const ScopedDisallowedCertificate&) =
      delete;

  bool ok() const {
    return added_ != nullptr;
  }

 private:
  HCERTSTORE store_ = nullptr;
  PCCERT_CONTEXT added_ = nullptr;
};

/** A gRPC verification request backed by strings owned by the test. */
class FakeRequest {
 public:
  FakeRequest(std::string pem_chain, std::string target_name)
      : pem_chain_(std::move(pem_chain)), target_name_(std::move(target_name)) {
    std::memset(&c_request_, 0, sizeof(c_request_));
    c_request_.target_name = target_name_.c_str();
    c_request_.peer_info.peer_cert_full_chain = pem_chain_.c_str();
  }

  FakeRequest(const FakeRequest&) = delete;
  FakeRequest& operator=(const FakeRequest&) = delete;

  grpc::experimental::TlsCustomVerificationCheckRequest* get() {
    return &request_;
  }

 private:
  std::string pem_chain_;
  std::string target_name_;
  grpc_tls_custom_verification_check_request c_request_;
  grpc::experimental::TlsCustomVerificationCheckRequest request_{&c_request_};
};

/**
 * Records the statuses a verification callback receives. Callbacks share
 * ownership of the recorded state, so a late callback (for example, after an
 * assertion fails and the test returns early) never touches freed memory.
 */
class StatusRecorder {
 public:
  TlsVerificationCallback AsCallback() const {
    std::shared_ptr<State> state = state_;
    return [state](grpc::Status status) {
      std::lock_guard<std::mutex> lock(state->mutex);
      state->statuses.push_back(std::move(status));
      state->changed.notify_all();
    };
  }

  /** Waits until at least `count` statuses are recorded. */
  bool WaitForCount(size_t count) const {
    std::unique_lock<std::mutex> lock(state_->mutex);
    return state_->changed.wait_for(
        lock, kTimeout, [&] { return state_->statuses.size() >= count; });
  }

  std::vector<grpc::Status> statuses() const {
    std::lock_guard<std::mutex> lock(state_->mutex);
    return state_->statuses;
  }

 private:
  struct State {
    std::mutex mutex;
    std::condition_variable changed;
    std::vector<grpc::Status> statuses;
  };

  std::shared_ptr<State> state_ = std::make_shared<State>();
};

class GrpcTlsCredentialsProviderWindowsTest : public ::testing::Test {
 protected:
  GrpcTlsCredentialsProviderWindowsTest()
      : pki_(CreateTestPki("windows", {kHost}, {"127.0.0.1"})),
        other_pki_(CreateTestPki("windows-other", {kHost})) {
  }

  TestPki pki_;
  TestPki other_pki_;
};

TEST_F(GrpcTlsCredentialsProviderWindowsTest, AcceptsValidChain) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});

  EXPECT_TRUE(
      VerifyWindowsTlsCertificateChain(pki_.ServerChainPem(), kHost, trust)
          .ok());
  grpc::Status with_port = VerifyWindowsTlsCertificateChain(
      pki_.ServerChainPem(), std::string(kHost) + ":443", trust);
  EXPECT_TRUE(with_port.ok()) << with_port.error_message();
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, MatchesIpAddressTargets) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});

  // The leaf has an iPAddress subjectAltName of 127.0.0.1 only.
  for (const char* target : {"127.0.0.1", "127.0.0.1:443"}) {
    grpc::Status status =
        VerifyWindowsTlsCertificateChain(pki_.ServerChainPem(), target, trust);
    EXPECT_TRUE(status.ok()) << target << ": " << status.error_message();
  }
  for (const char* target : {"10.0.0.1", "10.0.0.1:443", "[::1]:443"}) {
    grpc::Status status =
        VerifyWindowsTlsCertificateChain(pki_.ServerChainPem(), target, trust);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED) << target;
  }
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, AcceptsCrossSignedPath) {
  // Only `cross_root` is trusted, so the chain must be built through
  // `cross_intermediate`, which the server sends instead of `intermediate`.
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.cross_root});

  grpc::Status status = VerifyWindowsTlsCertificateChain(
      PemChain({&pki_.leaf, &pki_.cross_intermediate}), kHost, trust);
  EXPECT_TRUE(status.ok()) << status.error_message();
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, RejectsUntrustedRoot) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&other_pki_.root});

  grpc::Status status =
      VerifyWindowsTlsCertificateChain(pki_.ServerChainPem(), kHost, trust);
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, RejectsMissingIntermediate) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});

  grpc::Status status =
      VerifyWindowsTlsCertificateChain(pki_.leaf.cert_pem(), kHost, trust);
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, RejectsWrongHostname) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});

  grpc::Status status = VerifyWindowsTlsCertificateChain(
      pki_.ServerChainPem(), "other.firestore.test", trust);
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_THAT(status.error_message(), HasSubstr("CERT_E_CN_NO_MATCH"));
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, RejectsExpiredLeaf) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});

  grpc::Status status = VerifyWindowsTlsCertificateChain(
      pki_.ExpiredServerChainPem(), kHost, trust);
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_THAT(status.error_message(), HasSubstr("CERT_E_EXPIRED"));
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, RejectsDisallowedIntermediate) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});
  ASSERT_TRUE(
      VerifyWindowsTlsCertificateChain(pki_.ServerChainPem(), kHost, trust)
          .ok());

  ScopedDisallowedCertificate disallowed(pki_.intermediate);
  ASSERT_TRUE(disallowed.ok());
  // A fresh engine, so nothing cached from the first evaluation is reused.
  WindowsTrustConfig fresh_trust = ExclusiveRootConfig({&pki_.root});

  grpc::Status status = VerifyWindowsTlsCertificateChain(pki_.ServerChainPem(),
                                                         kHost, fresh_trust);
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, RejectsMalformedInput) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});
  const std::string chain = pki_.ServerChainPem();

  for (const std::string& bad_chain :
       {std::string(), std::string("not a certificate"), "junk\n" + chain,
        chain + "-----BEGIN CERTIFICATE-----\nAAAA\n",
        std::string("-----BEGIN CERTIFICATE-----\n!!!!\n"
                    "-----END CERTIFICATE-----\n"),
        std::string("-----BEGIN CERTIFICATE-----\nAAAA\n"
                    "-----END CERTIFICATE-----\n")}) {
    grpc::Status status =
        VerifyWindowsTlsCertificateChain(bad_chain, kHost, trust);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << bad_chain;
  }

  for (const char* bad_target : {"", "[::1", "host:notaport", "a b"}) {
    grpc::Status status =
        VerifyWindowsTlsCertificateChain(chain, bad_target, trust);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << bad_target;
    EXPECT_THAT(status.error_message(), HasSubstr("target host name"));
  }
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, LoopbackHandshakeSucceeds) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});
  TlsLoopbackServer server(pki_.leaf.private_key_pem(), pki_.ServerChainPem());
  ASSERT_TRUE(server.started());

  auto channel =
      CreateLoopbackChannel(server, CreateWindowsTlsCredentials(trust), kHost);
  std::string response;
  grpc::Status status = PerformUnaryEcho(channel, "ping", &response);
  EXPECT_TRUE(status.ok()) << status.error_message();
  EXPECT_EQ(response, "ping");
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, LoopbackRejectsWrongHostname) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});
  TlsLoopbackServer server(pki_.leaf.private_key_pem(), pki_.ServerChainPem());
  ASSERT_TRUE(server.started());

  auto channel = CreateLoopbackChannel(
      server, CreateWindowsTlsCredentials(trust), "other.firestore.test");
  EXPECT_FALSE(PerformUnaryEcho(channel, "ping").ok());
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, LoopbackRejectsUntrustedRoot) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&other_pki_.root});
  TlsLoopbackServer server(pki_.leaf.private_key_pem(), pki_.ServerChainPem());
  ASSERT_TRUE(server.started());

  auto channel =
      CreateLoopbackChannel(server, CreateWindowsTlsCredentials(trust), kHost);
  EXPECT_FALSE(PerformUnaryEcho(channel, "ping").ok());
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, VerifiesAsynchronously) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});
  std::unique_ptr<AsyncTlsVerifier> verifier = CreateWindowsTlsVerifier(trust);

  FakeRequest request(pki_.ServerChainPem(), kHost);
  StatusRecorder recorder;
  grpc::Status sync_status;
  bool sync =
      verifier->Verify(request.get(), recorder.AsCallback(), &sync_status);

  ASSERT_FALSE(sync) << "verification must not run on the calling thread";
  ASSERT_TRUE(recorder.WaitForCount(1));
  std::vector<grpc::Status> statuses = recorder.statuses();
  ASSERT_EQ(statuses.size(), 1u);
  EXPECT_TRUE(statuses[0].ok()) << statuses[0].error_message();
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, CancelMidFlight) {
  std::promise<void> release_evaluation;
  std::shared_future<void> evaluation_released =
      release_evaluation.get_future().share();

  WindowsTrustConfig config = ExclusiveRootConfig({&pki_.root});
  config.before_async_evaluation = [evaluation_released] {
    evaluation_released.wait();
  };
  std::unique_ptr<AsyncTlsVerifier> verifier = CreateWindowsTlsVerifier(config);

  FakeRequest request(pki_.ServerChainPem(), kHost);
  StatusRecorder recorder;
  grpc::Status sync_status;
  bool sync =
      verifier->Verify(request.get(), recorder.AsCallback(), &sync_status);
  ASSERT_FALSE(sync);

  verifier->Cancel(request.get());
  ASSERT_TRUE(recorder.WaitForCount(1));

  // Let the held evaluation finish; its result must be ignored. Destroying the
  // verifier must not wait for it either.
  release_evaluation.set_value();
  verifier.reset();
  std::this_thread::sleep_for(std::chrono::milliseconds(500));

  std::vector<grpc::Status> statuses = recorder.statuses();
  ASSERT_EQ(statuses.size(), 1u);
  EXPECT_EQ(statuses[0].error_code(), grpc::StatusCode::CANCELLED);
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(_WIN32)
