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

// <wincrypt.h> (included above) defines macros that collide with OpenSSL and
// BoringSSL type names. This file uses only the OpenSSL meanings.
#undef X509_NAME
#undef X509_EXTENSIONS
#undef PKCS7_ISSUER_AND_SERIAL
#undef PKCS7_SIGNER_INFO
#undef OCSP_REQUEST
#undef OCSP_RESPONSE

#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/obj_mac.h>
#include <openssl/pem.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#include <ws2tcpip.h>  // NOLINT(build/include_order)

#include <atomic>
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

/**
 * A minimal HTTP/1.0 server on 127.0.0.1 that answers every request with the
 * same body and counts the requests, standing in for an AIA `caIssuers` URL.
 */
class CountingHttpServer {
 public:
  explicit CountingHttpServer(std::string body) : body_(std::move(body)) {
    WSADATA wsa_data;
    if (WSAStartup(MAKEWORD(2, 2), &wsa_data) != 0) {
      ADD_FAILURE() << "WSAStartup failed";
      return;
    }
    wsa_started_ = true;

    listener_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (listener_ == INVALID_SOCKET) {
      ADD_FAILURE() << "socket failed: " << WSAGetLastError();
      return;
    }
    sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = 0;
    int addr_len = sizeof(addr);
    if (bind(listener_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) !=
            0 ||
        listen(listener_, SOMAXCONN) != 0 ||
        getsockname(listener_, reinterpret_cast<sockaddr*>(&addr), &addr_len) !=
            0) {
      ADD_FAILURE() << "bind/listen failed: " << WSAGetLastError();
      return;
    }
    port_ = ntohs(addr.sin_port);
    thread_ = std::thread([this] { ServeLoop(); });
  }

  ~CountingHttpServer() {
    stopping_ = true;
    if (listener_ != INVALID_SOCKET) {
      closesocket(listener_);  // Unblocks accept().
    }
    if (thread_.joinable()) {
      thread_.join();
    }
    if (wsa_started_) {
      WSACleanup();
    }
  }

  CountingHttpServer(const CountingHttpServer&) = delete;
  CountingHttpServer& operator=(const CountingHttpServer&) = delete;

  bool started() const {
    return port_ != 0;
  }

  /** A URL on this server that no other test uses. */
  std::string url() const {
    return "http://127.0.0.1:" + std::to_string(port_) + "/issuer.cer";
  }

  int request_count() const {
    return request_count_;
  }

 private:
  void ServeLoop() {
    while (!stopping_) {
      SOCKET client = accept(listener_, nullptr, nullptr);
      if (client == INVALID_SOCKET) {
        return;
      }
      ++request_count_;
      char buffer[4096];
      recv(client, buffer, sizeof(buffer), 0);
      std::string response =
          "HTTP/1.0 200 OK\r\nContent-Type: application/pkix-cert\r\n"
          "Content-Length: " +
          std::to_string(body_.size()) + "\r\nConnection: close\r\n\r\n" +
          body_;
      send(client, response.data(), static_cast<int>(response.size()), 0);
      shutdown(client, SD_SEND);
      closesocket(client);
    }
  }

  std::string body_;
  bool wsa_started_ = false;
  SOCKET listener_ = INVALID_SOCKET;
  int port_ = 0;
  std::atomic<bool> stopping_{false};
  std::atomic<int> request_count_{0};
  std::thread thread_;
};

/**
 * Returns `cert` re-signed by `issuer` with an AIA `caIssuers` URL, as PEM.
 * The subject, key, and SANs are unchanged.
 */
std::string ReissueWithCaIssuersUrl(const TestCertificate& cert,
                                    const TestCertificate& issuer,
                                    const std::string& url) {
  std::unique_ptr<X509, decltype(&X509_free)> copy(X509_dup(cert.x509()),
                                                   X509_free);
  if (!copy) {
    ADD_FAILURE() << "X509_dup failed";
    return "";
  }
  X509V3_CTX ctx;
  X509V3_set_ctx(&ctx, issuer.x509(), copy.get(), nullptr, nullptr, 0);
  std::string value = "caIssuers;URI:" + url;
  X509_EXTENSION* ext =
      X509V3_EXT_nconf_nid(nullptr, &ctx, NID_info_access, value.c_str());
  if (ext == nullptr || !X509_add_ext(copy.get(), ext, -1)) {
    X509_EXTENSION_free(ext);
    ADD_FAILURE() << "Adding the AIA extension failed";
    return "";
  }
  X509_EXTENSION_free(ext);
  if (X509_sign(copy.get(), issuer.key(), EVP_sha256()) <= 0) {
    ADD_FAILURE() << "X509_sign failed";
    return "";
  }

  std::unique_ptr<BIO, decltype(&BIO_free)> bio(BIO_new(BIO_s_mem()), BIO_free);
  if (!bio || !PEM_write_bio_X509(bio.get(), copy.get())) {
    ADD_FAILURE() << "PEM_write_bio_X509 failed";
    return "";
  }
  char* data = nullptr;
  long size = BIO_get_mem_data(bio.get(), &data);  // NOLINT(runtime/int)
  return std::string(data, static_cast<size_t>(size));
}

/** Decodes the first PEM certificate in `pem` into a CryptoAPI context. */
PCCERT_CONTEXT CreateCertContextFromPem(const std::string& pem) {
  DWORD der_size = 0;
  if (!CryptStringToBinaryA(pem.c_str(), static_cast<DWORD>(pem.size()),
                            CRYPT_STRING_BASE64HEADER, nullptr, &der_size,
                            nullptr, nullptr)) {
    return nullptr;
  }
  std::string der(der_size, '\0');
  if (!CryptStringToBinaryA(pem.c_str(), static_cast<DWORD>(pem.size()),
                            CRYPT_STRING_BASE64HEADER,
                            reinterpret_cast<BYTE*>(&der[0]), &der_size,
                            nullptr, nullptr)) {
    return nullptr;
  }
  return CertCreateCertificateContext(
      kCertEncoding, reinterpret_cast<const BYTE*>(der.data()), der_size);
}

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

TEST_F(GrpcTlsCredentialsProviderWindowsTest,
       DoesNotFetchMissingIntermediatesViaAia) {
  // The server sends only the leaf, whose AIA extension points at a local
  // server that would hand out the missing intermediate. The verifier must not
  // contact it on behalf of an unauthenticated peer.
  CountingHttpServer aia_server(pki_.intermediate.cert_der());
  ASSERT_TRUE(aia_server.started());
  std::string leaf_pem =
      ReissueWithCaIssuersUrl(pki_.leaf, pki_.intermediate, aia_server.url());
  ASSERT_FALSE(leaf_pem.empty());

  grpc::Status status = VerifyWindowsTlsCertificateChain(
      leaf_pem, kHost, ExclusiveRootConfig({&pki_.root}));
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_EQ(aia_server.request_count(), 0);

  // Control: the same setup with AIA retrieval left on (a separate server,
  // URL, leaf, and engine, so nothing is cached) does fetch the intermediate,
  // so the assertions above aren't vacuous.
  CountingHttpServer control_server(pki_.intermediate.cert_der());
  ASSERT_TRUE(control_server.started());
  std::string control_leaf_pem = ReissueWithCaIssuersUrl(
      pki_.leaf, pki_.intermediate, control_server.url());
  WindowsTrustConfig control_trust = ExclusiveRootConfig({&pki_.root});
  PCCERT_CONTEXT control_leaf = CreateCertContextFromPem(control_leaf_pem);
  ASSERT_NE(control_leaf, nullptr);
  CERT_CHAIN_PARA chain_para = {};
  chain_para.cbSize = sizeof(chain_para);
  PCCERT_CHAIN_CONTEXT chain = nullptr;
  ASSERT_TRUE(CertGetCertificateChain(
      static_cast<HCERTCHAINENGINE>(control_trust.chain_engine.get()),
      control_leaf, nullptr, nullptr, &chain_para, /*dwFlags=*/0, nullptr,
      &chain));
  EXPECT_EQ(chain->TrustStatus.dwErrorStatus,
            static_cast<DWORD>(CERT_TRUST_NO_ERROR));
  EXPECT_GT(control_server.request_count(), 0);
  CertFreeCertificateChain(chain);
  CertFreeCertificateContext(control_leaf);
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
