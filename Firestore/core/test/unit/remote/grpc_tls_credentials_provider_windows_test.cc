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

#include "Firestore/core/src/remote/grpc_tls_credentials_provider_windows.h"

#if defined(_WIN32)

#if defined(X509_NAME) || defined(X509_EXTENSIONS) || defined(OCSP_REQUEST)
#error "grpc_tls_credentials_provider_windows.h must not include <wincrypt.h>"
#endif

// `CERT_CHAIN_ENGINE_CONFIG::hExclusiveRoot` in `<wincrypt.h>` is gated on
// Windows 7 (`NTDDI_VERSION >= NTDDI_WIN7`), whereas CMake targets Vista
// (`_WIN32_WINNT=0x600`; see compiler_setup.cmake) and gRPC's
// `port_platform.h` has already included `<windows.h>` / `<sdkddkver.h>`.
#if !defined(_WIN32_WINNT) || _WIN32_WINNT < 0x0601
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0601
#endif
#if !defined(NTDDI_VERSION) || NTDDI_VERSION < 0x06010000
#undef NTDDI_VERSION
#define NTDDI_VERSION 0x06010000
#endif

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <winsock2.h>  // NOLINT(build/include_order)
#include <ws2tcpip.h>  // NOLINT(build/include_order)

#include <windows.h>  // NOLINT(build/include_order)

#include <wincrypt.h>  // NOLINT(build/include_order)
#include <winreg.h>    // NOLINT(build/include_order)

// <wincrypt.h> defines macros that collide with OpenSSL and BoringSSL type
// names. This file uses only the OpenSSL meanings.
#undef X509_NAME
#undef X509_EXTENSIONS
#undef PKCS7_ISSUER_AND_SERIAL
#undef PKCS7_SIGNER_INFO
#undef OCSP_REQUEST
#undef OCSP_RESPONSE

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <future>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "Firestore/core/src/remote/grpc_tls_async_verification.h"
#include "Firestore/core/src/util/warnings.h"
#include "Firestore/core/test/unit/remote/tls_loopback_server.h"
#include "Firestore/core/test/unit/remote/tls_test_pki.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"
#include "openssl/asn1.h"
#include "openssl/bio.h"
#include "openssl/evp.h"
#include "openssl/obj_mac.h"
#include "openssl/objects.h"
#include "openssl/pem.h"
#include "openssl/x509.h"
#include "openssl/x509v3.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpc/credentials.h"
#include "grpcpp/security/tls_certificate_verifier.h"
SUPPRESS_END()

#if defined(_MSC_VER)
#pragma comment(lib, "advapi32")
#pragma comment(lib, "crypt32")
#pragma comment(lib, "ws2_32")
#endif

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using ::testing::HasSubstr;
using tls_testing::CreateLoopbackChannel;
using tls_testing::CreateTestPki;
using tls_testing::IssueTestCertificate;
using tls_testing::PemChain;
using tls_testing::PerformUnaryEcho;
using tls_testing::TestCertificate;
using tls_testing::TestCertOptions;
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

struct LocalAllocDeleter {
  void operator()(void* ptr) const {
    LocalFree(ptr);
  }
};

struct CertContextDeleter {
  void operator()(PCCERT_CONTEXT context) const {
    CertFreeCertificateContext(context);
  }
};

/**
 * Returns `cert` re-signed by `issuer` with Microsoft's Cross-Certificate
 * Distribution Points (`szOID_CROSS_CERT_DIST_POINTS`,
 * `1.3.6.1.4.1.311.10.9.1`) extension pointing at `url`, as PEM.
 */
std::string ReissueWithCrossCertDistPointsUrl(const TestCertificate& cert,
                                              const TestCertificate& issuer,
                                              const std::string& url) {
  std::unique_ptr<X509, decltype(&X509_free)> copy(X509_dup(cert.x509()),
                                                   X509_free);
  if (!copy) {
    ADD_FAILURE() << "X509_dup failed";
    return "";
  }

  std::wstring wide_url(url.begin(), url.end());
  CERT_ALT_NAME_ENTRY entry = {};
  entry.dwAltNameChoice = CERT_ALT_NAME_URL;
  entry.pwszURL = &wide_url[0];

  CERT_ALT_NAME_INFO dist_point = {};
  dist_point.cAltEntry = 1;
  dist_point.rgAltEntry = &entry;

  CROSS_CERT_DIST_POINTS_INFO dist_points_info = {};
  dist_points_info.dwSyncDeltaTime = 1;
  dist_points_info.cDistPoint = 1;
  dist_points_info.rgDistPoint = &dist_point;

  BYTE* encoded = nullptr;
  DWORD encoded_size = 0;
  if (!CryptEncodeObjectEx(kCertEncoding, X509_CROSS_CERT_DIST_POINTS,
                           &dist_points_info, CRYPT_ENCODE_ALLOC_FLAG,
                           /*pEncodePara=*/nullptr, &encoded, &encoded_size)) {
    ADD_FAILURE() << "CryptEncodeObjectEx(X509_CROSS_CERT_DIST_POINTS) failed: "
                  << GetLastError();
    return "";
  }
  std::unique_ptr<BYTE, LocalAllocDeleter> encoded_holder(encoded);

  std::unique_ptr<ASN1_OBJECT, decltype(&ASN1_OBJECT_free)> oid(
      OBJ_txt2obj(szOID_CROSS_CERT_DIST_POINTS, /*dont_search_names=*/1),
      ASN1_OBJECT_free);
  std::unique_ptr<ASN1_OCTET_STRING, decltype(&ASN1_OCTET_STRING_free)> value(
      ASN1_OCTET_STRING_new(), ASN1_OCTET_STRING_free);
  if (!oid || !value ||
      !ASN1_OCTET_STRING_set(value.get(), encoded,
                             static_cast<int>(encoded_size))) {
    ADD_FAILURE() << "Building the CCDP extension value failed";
    return "";
  }
  std::unique_ptr<X509_EXTENSION, decltype(&X509_EXTENSION_free)> ext(
      X509_EXTENSION_create_by_OBJ(nullptr, oid.get(), /*crit=*/0, value.get()),
      X509_EXTENSION_free);
  if (!ext || !X509_add_ext(copy.get(), ext.get(), -1)) {
    ADD_FAILURE() << "Adding the CCDP extension failed";
    return "";
  }
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

/**
 * Returns whether Group Policy disables CryptoAPI AIA URL retrieval
 * machine-wide (`CERT_CHAIN_OPTION_DISABLE_AIA_URL_RETRIEVAL`).
 */
bool IsAiaUrlRetrievalDisabledByGroupPolicy() {
  DWORD options = 0;
  DWORD size = sizeof(options);
  LSTATUS status = RegGetValueW(
      HKEY_LOCAL_MACHINE,
      L"SOFTWARE\\Policies\\Microsoft\\SystemCertificates\\ChainEngine\\Config",
      L"Options", RRF_RT_REG_DWORD, nullptr, &options, &size);
  return status == ERROR_SUCCESS && (options & 0x2u) != 0;
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

  grpc::Status status =
      VerifyWindowsTlsCertificateChain(pki_.ServerChainPem(), kHost, trust);
  EXPECT_TRUE(status.ok()) << status.error_message();
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, MatchesIpAddressTargets) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});

  // The leaf has an iPAddress subjectAltName of 127.0.0.1 only.
  grpc::Status status = VerifyWindowsTlsCertificateChain(pki_.ServerChainPem(),
                                                         "127.0.0.1", trust);
  EXPECT_TRUE(status.ok()) << status.error_message();
  for (const char* target : {"10.0.0.1", "::1"}) {
    grpc::Status mismatch =
        VerifyWindowsTlsCertificateChain(pki_.ServerChainPem(), target, trust);
    EXPECT_EQ(mismatch.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << target;
  }

  // Positive and negative IPv6 `iPAddress` subjectAltName matching, including
  // non-canonical and IPv4-mapped forms.
  TestCertOptions ipv6_opts;
  ipv6_opts.common_name = "ipv6.firestore.test";
  ipv6_opts.ip_sans = {"::1", "::ffff:127.0.0.1"};
  TestCertificate ipv6_leaf =
      IssueTestCertificate(ipv6_opts, &pki_.intermediate);
  std::string ipv6_chain = PemChain({&ipv6_leaf, &pki_.intermediate});

  for (const char* target : {"::1", "0:0:0:0:0:0:0:1", "::ffff:127.0.0.1",
                             "0:0:0:0:0:ffff:7f00:1"}) {
    grpc::Status ipv6_ok =
        VerifyWindowsTlsCertificateChain(ipv6_chain, target, trust);
    EXPECT_TRUE(ipv6_ok.ok()) << target << ": " << ipv6_ok.error_message();
  }
  for (const char* target : {"::2", "127.0.0.1"}) {
    grpc::Status ipv6_mismatch =
        VerifyWindowsTlsCertificateChain(ipv6_chain, target, trust);
    EXPECT_EQ(ipv6_mismatch.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << target;
  }

  // An IP literal in `CN` and `dNSName` (without an `iPAddress` SAN) must not
  // satisfy an IP address target.
  TestCertOptions dns_ip_opts;
  dns_ip_opts.common_name = "127.0.0.1";
  dns_ip_opts.dns_sans = {"127.0.0.1"};
  TestCertificate dns_ip_leaf =
      IssueTestCertificate(dns_ip_opts, &pki_.intermediate);
  grpc::Status dns_ip_status = VerifyWindowsTlsCertificateChain(
      PemChain({&dns_ip_leaf, &pki_.intermediate}), "127.0.0.1", trust);
  EXPECT_EQ(dns_ip_status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_THAT(dns_ip_status.error_message(),
              HasSubstr("no matching IP address subjectAltName"));
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest,
       DoesNotFallBackToSubjectCommonName) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});

  // Leaf with `CN=loopback.firestore.test` and no `subjectAltName` extension at
  // all.
  TestCertOptions cn_only_opts;
  cn_only_opts.common_name = kHost;
  TestCertificate cn_only_leaf =
      IssueTestCertificate(cn_only_opts, &pki_.intermediate);
  ASSERT_EQ(X509_get_ext_by_NID(cn_only_leaf.x509(), NID_subject_alt_name, -1),
            -1);
  std::string cn_only_chain = PemChain({&cn_only_leaf, &pki_.intermediate});

  grpc::Status cn_status =
      VerifyWindowsTlsCertificateChain(cn_only_chain, kHost, trust);
  EXPECT_EQ(cn_status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_THAT(cn_status.error_message(), HasSubstr("CERT_E_CN_NO_MATCH"));

  // End-to-end loopback: gRPC's per-call check would fall back to CN on a
  // SAN-less cert if handshake verification did not reject it.
  TlsLoopbackServer server(cn_only_leaf.private_key_pem(), cn_only_chain);
  ASSERT_TRUE(server.started());
  auto channel =
      CreateLoopbackChannel(server, CreateWindowsTlsCredentials(trust), kHost);
  EXPECT_FALSE(PerformUnaryEcho(channel, "ping").ok());

  // Leaf with `CN=loopback.firestore.test` and an `iPAddress` SAN, but zero
  // `dNSName` SANs (where CryptoAPI's `CERT_CHAIN_POLICY_SSL` also falls back
  // to `CN`).
  TestCertOptions ip_only_opts;
  ip_only_opts.common_name = kHost;
  ip_only_opts.ip_sans = {"127.0.0.1"};
  TestCertificate ip_only_leaf =
      IssueTestCertificate(ip_only_opts, &pki_.intermediate);
  std::string ip_only_chain = PemChain({&ip_only_leaf, &pki_.intermediate});

  ASSERT_TRUE(
      VerifyWindowsTlsCertificateChain(ip_only_chain, "127.0.0.1", trust).ok());
  grpc::Status ip_only_dns_status =
      VerifyWindowsTlsCertificateChain(ip_only_chain, kHost, trust);
  EXPECT_EQ(ip_only_dns_status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_THAT(ip_only_dns_status.error_message(),
              HasSubstr("CERT_E_CN_NO_MATCH"));
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest,
       MatchesWildcardAndRejectsInvalidDnsTargets) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});

  TestCertOptions wild_opts;
  wild_opts.common_name = "*.wild.firestore.test";
  wild_opts.dns_sans = {"*.wild.firestore.test"};
  TestCertificate wild_leaf =
      IssueTestCertificate(wild_opts, &pki_.intermediate);
  std::string wild_chain = PemChain({&wild_leaf, &pki_.intermediate});

  grpc::Status ok_status = VerifyWindowsTlsCertificateChain(
      wild_chain, "sub.wild.firestore.test", trust);
  EXPECT_TRUE(ok_status.ok()) << ok_status.error_message();

  for (const char* bad_target :
       {"*.wild.firestore.test", ".wild.firestore.test", "wild.firestore.test",
        "a.b.wild.firestore.test", ".firestore.test",
        "sub.wild.firestore.test.", "loopback.firestore.test."}) {
    grpc::Status status =
        VerifyWindowsTlsCertificateChain(wild_chain, bad_target, trust);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << bad_target;
  }

  for (const char* bad_target : {".firestore.test", ".loopback.firestore.test",
                                 "loopback.firestore.test."}) {
    grpc::Status status = VerifyWindowsTlsCertificateChain(
        pki_.ServerChainPem(), bad_target, trust);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << bad_target;
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

  if (!IsAiaUrlRetrievalDisabledByGroupPolicy()) {
    // Control: the same setup with AIA retrieval left on (a separate server,
    // URL, leaf, and engine, so nothing is cached) does fetch the intermediate,
    // so the assertions above aren't vacuous. Skipped when Group Policy
    // disables AIA URL retrieval machine-wide.
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
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest,
       DoesNotFetchCrossCertDistPointsUrl) {
  // Unlike RFC 5280 AIA, Microsoft's Cross-Certificate Distribution Points
  // (`szOID_CROSS_CERT_DIST_POINTS`, `1.3.6.1.4.1.311.10.9.1`) is not
  // suppressed by `CERT_CHAIN_DISABLE_AIA` alone. Verify that neither a leaf
  // nor a peer-supplied intermediate carrying CCDP triggers outbound URL
  // retrieval under either a custom `chain_engine` or the default system
  // engine (`chain_engine == nullptr`).
  CountingHttpServer ccdp_server(pki_.cross_intermediate.cert_der());
  ASSERT_TRUE(ccdp_server.started());

  std::string leaf_with_ccdp_pem = ReissueWithCrossCertDistPointsUrl(
      pki_.leaf, pki_.intermediate, ccdp_server.url());
  ASSERT_FALSE(leaf_with_ccdp_pem.empty());

  // Sanity-check that CryptoAPI decodes the `szOID_CROSS_CERT_DIST_POINTS`
  // extension on the issued certificate back to `ccdp_server.url()`.
  std::unique_ptr<const CERT_CONTEXT, CertContextDeleter> parsed_leaf(
      CreateCertContextFromPem(leaf_with_ccdp_pem));
  ASSERT_NE(parsed_leaf, nullptr);
  PCERT_EXTENSION ccdp_ext = CertFindExtension(
      szOID_CROSS_CERT_DIST_POINTS, parsed_leaf->pCertInfo->cExtension,
      parsed_leaf->pCertInfo->rgExtension);
  ASSERT_NE(ccdp_ext, nullptr);
  CROSS_CERT_DIST_POINTS_INFO* decoded = nullptr;
  DWORD decoded_size = 0;
  ASSERT_TRUE(CryptDecodeObjectEx(
      kCertEncoding, X509_CROSS_CERT_DIST_POINTS, ccdp_ext->Value.pbData,
      ccdp_ext->Value.cbData, CRYPT_DECODE_ALLOC_FLAG,
      /*pDecodePara=*/nullptr, &decoded, &decoded_size));
  std::unique_ptr<CROSS_CERT_DIST_POINTS_INFO, LocalAllocDeleter>
      decoded_holder(decoded);
  ASSERT_EQ(decoded->cDistPoint, 1u);
  ASSERT_EQ(decoded->rgDistPoint[0].cAltEntry, 1u);
  ASSERT_EQ(decoded->rgDistPoint[0].rgAltEntry[0].dwAltNameChoice,
            static_cast<DWORD>(CERT_ALT_NAME_URL));
  // `url()` returns a new string each call, so take both iterators from one.
  const std::string url = ccdp_server.url();
  std::wstring expected_wide_url(url.begin(), url.end());
  EXPECT_EQ(std::wstring(decoded->rgDistPoint[0].rgAltEntry[0].pwszURL),
            expected_wide_url);

  for (const WindowsTrustConfig& trust :
       {ExclusiveRootConfig({&pki_.root}), WindowsTrustConfig{}}) {
    grpc::Status status =
        VerifyWindowsTlsCertificateChain(leaf_with_ccdp_pem, kHost, trust);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
    EXPECT_EQ(ccdp_server.request_count(), 0);
  }

  std::string intermediate_with_ccdp_pem = ReissueWithCrossCertDistPointsUrl(
      pki_.intermediate, pki_.root, ccdp_server.url());
  ASSERT_FALSE(intermediate_with_ccdp_pem.empty());
  std::string chain_with_ccdp_intermediate =
      pki_.leaf.cert_pem() + intermediate_with_ccdp_pem;

  for (const WindowsTrustConfig& trust :
       {ExclusiveRootConfig({&pki_.cross_root}), WindowsTrustConfig{}}) {
    grpc::Status status = VerifyWindowsTlsCertificateChain(
        chain_with_ccdp_intermediate, kHost, trust);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
    EXPECT_EQ(ccdp_server.request_count(), 0);
  }
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

  std::string leaf_with_trailing_garbage = pki_.leaf.cert_pem();
  size_t end_pos = leaf_with_trailing_garbage.find("-----END CERTIFICATE-----");
  ASSERT_NE(end_pos, std::string::npos);
  leaf_with_trailing_garbage.insert(end_pos, "TUlJQg==junk\n");

  for (const std::string& bad_chain :
       {std::string(), std::string("not a certificate"), "junk\n" + chain,
        chain + "-----BEGIN CERTIFICATE-----\nAAAA\n",
        std::string("-----BEGIN CERTIFICATE-----\n!!!!\n"
                    "-----END CERTIFICATE-----\n"),
        std::string("-----BEGIN CERTIFICATE-----\nTUlJQg==junk\n"
                    "-----END CERTIFICATE-----\n"),
        std::string("-----BEGIN CERTIFICATE-----\nTUlJQg==\nTUlJQg==\n"
                    "-----END CERTIFICATE-----\n"),
        leaf_with_trailing_garbage + pki_.intermediate.cert_pem(),
        std::string("-----BEGIN CERTIFICATE-----\nAAAA\n"
                    "-----END CERTIFICATE-----\n")}) {
    grpc::Status status =
        VerifyWindowsTlsCertificateChain(bad_chain, kHost, trust);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << bad_chain;
  }

  grpc::Status padding_garbage_status = VerifyWindowsTlsCertificateChain(
      "-----BEGIN CERTIFICATE-----\nTUlJQg==junk\n-----END CERTIFICATE-----\n",
      kHost, trust);
  EXPECT_EQ(padding_garbage_status.error_code(),
            grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_THAT(padding_garbage_status.error_message(),
              HasSubstr("Invalid base64 payload"));

  // gRPC passes a bare host (no port or brackets) as the target name.
  for (const char* bad_target :
       {"", "[::1]", "[::1", "host:443", "fe80::1%1"}) {
    grpc::Status status =
        VerifyWindowsTlsCertificateChain(chain, bad_target, trust);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << bad_target;
    EXPECT_THAT(status.error_message(), HasSubstr("target host name"));
  }

  // The parser's reason is included in the status.
  grpc::Status zone_status =
      VerifyWindowsTlsCertificateChain(chain, "fe80::1%1", trust);
  EXPECT_EQ(zone_status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_THAT(zone_status.error_message(), HasSubstr("zone ID"));
  grpc::Status idn_status =
      VerifyWindowsTlsCertificateChain(chain, "m\xC3\xBCnchen.test", trust);
  EXPECT_EQ(idn_status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_THAT(idn_status.error_message(), HasSubstr("Punycode"));

  // Parsed as a DNS name, so it is rejected by CryptoAPI's name check.
  grpc::Status dns_status =
      VerifyWindowsTlsCertificateChain(chain, "a b", trust);
  EXPECT_EQ(dns_status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
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

TEST_F(GrpcTlsCredentialsProviderWindowsTest, LoopbackMatchesIpv6Target) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&pki_.root});
  TestCertOptions ipv6_opts;
  ipv6_opts.common_name = "ipv6.firestore.test";
  ipv6_opts.ip_sans = {"::1"};
  TestCertificate ipv6_leaf =
      IssueTestCertificate(ipv6_opts, &pki_.intermediate);
  TlsLoopbackServer server(ipv6_leaf.private_key_pem(),
                           PemChain({&ipv6_leaf, &pki_.intermediate}));
  ASSERT_TRUE(server.started());

  auto ok_channel =
      CreateLoopbackChannel(server, CreateWindowsTlsCredentials(trust), "::1");
  std::string response;
  grpc::Status status = PerformUnaryEcho(ok_channel, "ping", &response);
  EXPECT_TRUE(status.ok()) << status.error_message();
  EXPECT_EQ(response, "ping");

  auto bad_channel =
      CreateLoopbackChannel(server, CreateWindowsTlsCredentials(trust), "::2");
  EXPECT_FALSE(PerformUnaryEcho(bad_channel, "ping").ok());
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

TEST_F(GrpcTlsCredentialsProviderWindowsTest,
       LogsWarningOnAsyncVerificationFailure) {
  WindowsTrustConfig trust = ExclusiveRootConfig({&other_pki_.root});
  std::unique_ptr<AsyncTlsVerifier> verifier = CreateWindowsTlsVerifier(trust);

  FakeRequest request(pki_.ServerChainPem(), kHost);
  StatusRecorder recorder;
  grpc::Status sync_status;
  testing::internal::CaptureStdout();
  bool sync =
      verifier->Verify(request.get(), recorder.AsCallback(), &sync_status);
  bool recorded = !sync && recorder.WaitForCount(1);
  std::string logs = testing::internal::GetCapturedStdout();

  ASSERT_FALSE(sync);
  ASSERT_TRUE(recorded);
  std::vector<grpc::Status> statuses = recorder.statuses();
  ASSERT_EQ(statuses.size(), 1u);
  EXPECT_EQ(statuses[0].error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_THAT(logs, HasSubstr("TLS peer certificate verification failed:"));
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest, CancelMidFlight) {
  std::promise<void> entered;
  std::future<void> entered_future = entered.get_future();
  std::promise<void> release;
  std::shared_future<void> release_future = release.get_future().share();
  bool released = false;
  struct ReleaseOnExit {
    std::promise<void>* promise;
    bool* flag;
    ~ReleaseOnExit() {
      if (!*flag) {
        promise->set_value();
      }
    }
  } release_guard{&release, &released};

  auto finished_promise = std::make_shared<std::promise<void>>();
  std::future<void> finished_future = finished_promise->get_future();
  std::shared_ptr<void> finish_token(
      nullptr, [finished_promise](void*) { finished_promise->set_value(); });

  std::unique_ptr<AsyncTlsVerifier> verifier;
  {
    WindowsTrustConfig config = ExclusiveRootConfig({&pki_.root});
    auto entered_once =
        std::make_shared<std::promise<void>>(std::move(entered));
    config.before_async_evaluation = [entered_once, release_future,
                                      finish_token] {
      entered_once->set_value();
      release_future.wait();
    };
    verifier = CreateWindowsTlsVerifier(config);
  }
  finish_token.reset();

  FakeRequest request(pki_.ServerChainPem(), kHost);
  StatusRecorder recorder;
  grpc::Status sync_status;
  bool sync =
      verifier->Verify(request.get(), recorder.AsCallback(), &sync_status);
  ASSERT_FALSE(sync);

  ASSERT_EQ(entered_future.wait_for(kTimeout), std::future_status::ready);

  verifier->Cancel(request.get());
  ASSERT_TRUE(recorder.WaitForCount(1));

  // Destroying the verifier while the evaluation is still held must not block,
  // and when the worker finishes its result must be ignored.
  verifier.reset();
  released = true;
  release.set_value();
  ASSERT_EQ(finished_future.wait_for(kTimeout), std::future_status::ready);

  std::vector<grpc::Status> statuses = recorder.statuses();
  ASSERT_EQ(statuses.size(), 1u);
  EXPECT_EQ(statuses[0].error_code(), grpc::StatusCode::CANCELLED);
}

TEST_F(GrpcTlsCredentialsProviderWindowsTest,
       BoundsConcurrentThreadPoolEvaluations) {
  constexpr size_t kMaxPoolThreads = 4;
  constexpr size_t kTotalRequests = 12;

  struct Gate {
    std::mutex mutex;
    std::condition_variable cv;
    size_t active = 0;
    size_t peak_active = 0;
    size_t entered = 0;
    bool release = false;
  };
  auto gate = std::make_shared<Gate>();

  WindowsTrustConfig config = ExclusiveRootConfig({&pki_.root});
  config.before_async_evaluation = [gate] {
    std::unique_lock<std::mutex> lock(gate->mutex);
    ++gate->active;
    ++gate->entered;
    if (gate->active > gate->peak_active) {
      gate->peak_active = gate->active;
    }
    gate->cv.notify_all();
    gate->cv.wait(lock, [&] { return gate->release; });
    --gate->active;
  };

  std::vector<std::unique_ptr<FakeRequest>> requests;
  requests.reserve(kTotalRequests);
  std::unique_ptr<AsyncTlsVerifier> verifier = CreateWindowsTlsVerifier(config);
  struct ReleaseOnExit {
    std::shared_ptr<Gate> gate;
    ~ReleaseOnExit() {
      std::lock_guard<std::mutex> lock(gate->mutex);
      gate->release = true;
      gate->cv.notify_all();
    }
  } release_guard{gate};

  StatusRecorder recorder;
  for (size_t i = 0; i < kTotalRequests; ++i) {
    requests.push_back(
        std::make_unique<FakeRequest>(pki_.ServerChainPem(), kHost));
    grpc::Status sync_status;
    bool sync = verifier->Verify(requests.back()->get(), recorder.AsCallback(),
                                 &sync_status);
    ASSERT_FALSE(sync);
  }

  {
    std::unique_lock<std::mutex> lock(gate->mutex);
    ASSERT_TRUE(gate->cv.wait_for(
        lock, kTimeout, [&] { return gate->entered >= kMaxPoolThreads; }));
    // With 8 more evaluations queued and all 4 pool threads blocked after
    // CallbackMayRunLong(), wait briefly to confirm no 5th worker starts.
    EXPECT_FALSE(gate->cv.wait_for(lock, std::chrono::milliseconds(100), [&] {
      return gate->entered > kMaxPoolThreads;
    }));
    EXPECT_EQ(gate->active, kMaxPoolThreads);
    EXPECT_EQ(gate->entered, kMaxPoolThreads);
    EXPECT_LE(gate->peak_active, kMaxPoolThreads);

    gate->release = true;
    gate->cv.notify_all();
  }

  ASSERT_TRUE(recorder.WaitForCount(kTotalRequests));
  {
    std::lock_guard<std::mutex> lock(gate->mutex);
    EXPECT_EQ(gate->entered, kTotalRequests);
    EXPECT_EQ(gate->active, 0u);
    EXPECT_LE(gate->peak_active, kMaxPoolThreads);
  }
  std::vector<grpc::Status> statuses = recorder.statuses();
  ASSERT_EQ(statuses.size(), kTotalRequests);
  for (const grpc::Status& status : statuses) {
    EXPECT_TRUE(status.ok()) << status.error_message();
  }
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(_WIN32)
