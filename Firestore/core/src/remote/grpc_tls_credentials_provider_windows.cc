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

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <thread>  // NOLINT(build/c++11)
#include <utility>
#include <vector>

#include "Firestore/core/src/remote/grpc_tls_async_verification.h"
#include "Firestore/core/src/remote/grpc_tls_target_host.h"
#include "Firestore/core/src/util/warnings.h"
#include "absl/strings/escaping.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/str_format.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/security/tls_certificate_verifier.h"
#include "grpcpp/security/tls_credentials_options.h"
SUPPRESS_END()

// For consumers that build Firestore without CMake. The CMake build links
// crypt32 explicitly.
#if defined(_MSC_VER)
#pragma comment(lib, "crypt32")
#endif

namespace firebase {
namespace firestore {
namespace remote {
namespace {

constexpr DWORD kCertEncoding = X509_ASN_ENCODING | PKCS_7_ASN_ENCODING;

grpc::Status Unauthenticated(std::string message) {
  return grpc::Status(grpc::StatusCode::UNAUTHENTICATED, std::move(message));
}

struct CertContextDeleter {
  void operator()(PCCERT_CONTEXT context) const {
    CertFreeCertificateContext(context);
  }
};
using CertContextPtr = std::unique_ptr<const CERT_CONTEXT, CertContextDeleter>;

struct CertStoreDeleter {
  void operator()(HCERTSTORE store) const {
    CertCloseStore(store, 0);
  }
};
using CertStorePtr = std::unique_ptr<void, CertStoreDeleter>;

struct CertChainDeleter {
  void operator()(PCCERT_CHAIN_CONTEXT chain) const {
    CertFreeCertificateChain(chain);
  }
};
using CertChainPtr =
    std::unique_ptr<const CERT_CHAIN_CONTEXT, CertChainDeleter>;

/**
 * Splits a PEM bundle into DER-encoded certificates. Text outside of
 * `CERTIFICATE` blocks must be whitespace.
 */
grpc::Status DecodePemCertificates(absl::string_view pem,
                                   std::vector<std::string>* out) {
  static constexpr absl::string_view kBegin = "-----BEGIN CERTIFICATE-----";
  static constexpr absl::string_view kEnd = "-----END CERTIFICATE-----";
  static constexpr absl::string_view kWhitespace = " \t\r\n";

  size_t pos = 0;
  while (true) {
    pos = pem.find_first_not_of(kWhitespace, pos);
    if (pos == absl::string_view::npos) {
      break;
    }
    if (pem.substr(pos, kBegin.size()) != kBegin) {
      return Unauthenticated(
          "Unexpected text outside PEM CERTIFICATE block in peer chain");
    }
    size_t body_start = pos + kBegin.size();
    size_t body_end = pem.find(kEnd, body_start);
    if (body_end == absl::string_view::npos) {
      return Unauthenticated("Unclosed PEM CERTIFICATE block in peer chain");
    }
    absl::string_view body = pem.substr(body_start, body_end - body_start);
    if (body.find("-----") != absl::string_view::npos) {
      return Unauthenticated("Nested or malformed PEM block in peer chain");
    }

    // `CRYPT_STRING_BASE64` ignores the line breaks and other whitespace that
    // PEM bodies contain.
    DWORD der_size = 0;
    if (body.empty() ||
        !CryptStringToBinaryA(body.data(), static_cast<DWORD>(body.size()),
                              CRYPT_STRING_BASE64, nullptr, &der_size, nullptr,
                              nullptr) ||
        der_size == 0) {
      return Unauthenticated("Invalid base64 payload in PEM CERTIFICATE block");
    }
    std::string der(der_size, '\0');
    if (!CryptStringToBinaryA(
            body.data(), static_cast<DWORD>(body.size()), CRYPT_STRING_BASE64,
            reinterpret_cast<BYTE*>(&der[0]), &der_size, nullptr, nullptr)) {
      return Unauthenticated("Invalid base64 payload in PEM CERTIFICATE block");
    }
    der.resize(der_size);
    out->push_back(std::move(der));

    pos = body_end + kEnd.size();
  }

  if (out->empty()) {
    return Unauthenticated("No PEM certificates found in peer chain");
  }
  return grpc::Status::OK;
}

/** Converts UTF-8 to UTF-16. Returns false if `utf8` is not valid UTF-8. */
bool Utf8ToWide(absl::string_view utf8, std::wstring* out) {
  if (utf8.empty()) {
    out->clear();
    return true;
  }
  int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                                 static_cast<int>(utf8.size()), nullptr, 0);
  if (size <= 0) {
    return false;
  }
  out->assign(static_cast<size_t>(size), L'\0');
  return MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                             static_cast<int>(utf8.size()), &(*out)[0],
                             size) == size;
}

std::string DescribeChainPolicyError(DWORD error) {
  const char* name = nullptr;
  switch (static_cast<HRESULT>(error)) {
    case CERT_E_UNTRUSTEDROOT:
      name = "CERT_E_UNTRUSTEDROOT: the chain ends in an untrusted root";
      break;
    case CERT_E_CHAINING:
      name = "CERT_E_CHAINING: no chain to a trusted root could be built";
      break;
    case CERT_E_EXPIRED:
      name = "CERT_E_EXPIRED: a certificate is expired or not yet valid";
      break;
    case CERT_E_CN_NO_MATCH:
      name = "CERT_E_CN_NO_MATCH: the certificate does not match the host";
      break;
    case CERT_E_WRONG_USAGE:
      name = "CERT_E_WRONG_USAGE: the certificate is not valid for server auth";
      break;
    case CERT_E_REVOKED:
    case CRYPT_E_REVOKED:
      name = "certificate revoked";
      break;
    case TRUST_E_EXPLICIT_DISTRUST:
      name =
          "TRUST_E_EXPLICIT_DISTRUST: a certificate is explicitly distrusted";
      break;
    case TRUST_E_CERT_SIGNATURE:
      name = "TRUST_E_CERT_SIGNATURE: a certificate signature is invalid";
      break;
    case TRUST_E_BASIC_CONSTRAINTS:
      name = "TRUST_E_BASIC_CONSTRAINTS: basic constraints are violated";
      break;
    default:
      break;
  }
  return absl::StrFormat("0x%08X%s%s", error, name ? " " : "",
                         name ? name : "");
}

VOID CALLBACK RunThreadPoolTask(PTP_CALLBACK_INSTANCE instance, PVOID context) {
  std::unique_ptr<std::function<void()>> task(
      static_cast<std::function<void()>*>(context));
  // Chain building may fetch intermediates or root updates over the network.
  CallbackMayRunLong(instance);
  (*task)();
}

/**
 * Runs `*task` on the Windows thread pool. Returns false, leaving `*task`
 * untouched, if it could not be scheduled.
 */
bool TrySubmitToThreadPool(std::function<void()>* task) {
  auto heap_task = std::make_unique<std::function<void()>>(std::move(*task));
  if (TrySubmitThreadpoolCallback(RunThreadPoolTask, heap_task.get(),
                                  /*pcbe=*/nullptr)) {
    heap_task.release();  // Now owned by `RunThreadPoolTask`.
    return true;
  }
  *task = std::move(*heap_task);
  return false;
}

/**
 * An `AsyncTlsVerifier::Scheduler` backed by the Windows thread pool, with a
 * new thread as a fallback since the task must run.
 */
void ScheduleOnThreadPool(std::function<void()> task) {
  if (!TrySubmitToThreadPool(&task)) {
    std::thread(std::move(task)).detach();
  }
}

/**
 * An `AsyncTlsVerifier::Evaluator` that runs `VerifyWindowsTlsCertificateChain`
 * on the Windows thread pool.
 */
void EvaluateOnThreadPool(const WindowsTrustConfig& config,
                          TlsVerificationInput input,
                          TlsVerificationCallback completion) {
  auto shared_completion =
      std::make_shared<TlsVerificationCallback>(std::move(completion));
  std::function<void()> task = [config, input = std::move(input),
                                shared_completion] {
    if (config.before_async_evaluation) {
      config.before_async_evaluation();
    }
    (*shared_completion)(VerifyWindowsTlsCertificateChain(
        input.pem_chain, input.target_name, config));
  };
  if (TrySubmitToThreadPool(&task)) {
    return;
  }
  // `AsyncTlsVerifier` reports an inline completion synchronously.
  (*shared_completion)(grpc::Status(
      grpc::StatusCode::UNAVAILABLE,
      absl::StrCat("Failed to schedule TLS certificate verification: "
                   "TrySubmitThreadpoolCallback failed with error ",
                   GetLastError())));
}

AsyncTlsVerifier::Evaluator MakeThreadPoolEvaluator(
    const WindowsTrustConfig& config) {
  return
      [config](TlsVerificationInput input, TlsVerificationCallback completion) {
        EvaluateOnThreadPool(config, std::move(input), std::move(completion));
      };
}

}  // namespace

grpc::Status VerifyWindowsTlsCertificateChain(
    absl::string_view pem_chain,
    absl::string_view target_name,
    const WindowsTrustConfig& config) {
  absl::optional<TlsTargetHost> target = ParseTlsTargetHost(target_name);
  std::wstring server_name;
  if (!target.has_value() || target->host.empty() ||
      !Utf8ToWide(target->host, &server_name)) {
    return Unauthenticated(
        absl::StrCat("Invalid or empty TLS target host name: '",
                     absl::CHexEscape(target_name), "'"));
  }

  std::vector<std::string> ders;
  grpc::Status parse_status = DecodePemCertificates(pem_chain, &ders);
  if (!parse_status.ok()) {
    return parse_status;
  }

  CertContextPtr leaf(CertCreateCertificateContext(
      kCertEncoding, reinterpret_cast<const BYTE*>(ders[0].data()),
      static_cast<DWORD>(ders[0].size())));
  if (!leaf) {
    return Unauthenticated(
        absl::StrCat("Failed to parse the leaf certificate in peer chain: "
                     "error ",
                     GetLastError()));
  }

  // Everything after the leaf is an untrusted intermediate candidate. A root
  // the peer sends is only trusted if it is also in the engine's root store.
  CertStorePtr intermediates(CertOpenStore(
      CERT_STORE_PROV_MEMORY, 0, 0, CERT_STORE_CREATE_NEW_FLAG, nullptr));
  if (!intermediates) {
    return Unauthenticated(
        absl::StrCat("Failed to create intermediate certificate store: error ",
                     GetLastError()));
  }
  for (size_t i = 1; i < ders.size(); ++i) {
    if (!CertAddEncodedCertificateToStore(
            intermediates.get(), kCertEncoding,
            reinterpret_cast<const BYTE*>(ders[i].data()),
            static_cast<DWORD>(ders[i].size()), CERT_STORE_ADD_ALWAYS,
            nullptr)) {
      return Unauthenticated(
          absl::StrCat("Failed to parse intermediate certificate ", i,
                       " in peer chain: error ", GetLastError()));
    }
  }

  char server_auth_oid[] = szOID_PKIX_KP_SERVER_AUTH;
  LPSTR usages[] = {server_auth_oid};
  CERT_CHAIN_PARA chain_para = {};
  chain_para.cbSize = sizeof(chain_para);
  chain_para.RequestedUsage.dwType = USAGE_MATCH_TYPE_AND;
  chain_para.RequestedUsage.Usage.cUsageIdentifier = 1;
  chain_para.RequestedUsage.Usage.rgpszUsageIdentifier = usages;

  // No revocation flags: like the bundled-roots verification this replaces,
  // and like browsers, don't block on online CRL/OCSP checks. Certificates
  // in the `Disallowed` store and Microsoft's distrust lists are still
  // rejected.
  PCCERT_CHAIN_CONTEXT raw_chain = nullptr;
  if (!CertGetCertificateChain(config.chain_engine, leaf.get(),
                               /*pTime=*/nullptr, intermediates.get(),
                               &chain_para, /*dwFlags=*/0,
                               /*pvReserved=*/nullptr, &raw_chain)) {
    return Unauthenticated(absl::StrCat(
        "CertGetCertificateChain failed with error ", GetLastError()));
  }
  CertChainPtr chain(raw_chain);

  SSL_EXTRA_CERT_CHAIN_POLICY_PARA ssl_para = {};
  ssl_para.cbSize = sizeof(ssl_para);
  ssl_para.dwAuthType = AUTHTYPE_SERVER;
  ssl_para.fdwChecks = 0;
  ssl_para.pwszServerName = &server_name[0];

  CERT_CHAIN_POLICY_PARA policy_para = {};
  policy_para.cbSize = sizeof(policy_para);
  policy_para.pvExtraPolicyPara = &ssl_para;

  CERT_CHAIN_POLICY_STATUS policy_status = {};
  policy_status.cbSize = sizeof(policy_status);

  if (!CertVerifyCertificateChainPolicy(CERT_CHAIN_POLICY_SSL, chain.get(),
                                        &policy_para, &policy_status)) {
    return Unauthenticated(absl::StrCat(
        "CertVerifyCertificateChainPolicy failed with error ", GetLastError()));
  }
  if (policy_status.dwError != ERROR_SUCCESS) {
    return Unauthenticated(absl::StrCat(
        "Windows TLS certificate verification failed for '", target->host,
        "': ", DescribeChainPolicyError(policy_status.dwError)));
  }
  return grpc::Status::OK;
}

std::shared_ptr<grpc::ChannelCredentials> CreateWindowsTlsCredentials(
    const WindowsTrustConfig& config) {
  grpc::experimental::TlsChannelCredentialsOptions options;

  // CryptoAPI owns chain building, trust, and hostname checks, so skip the SSL
  // library's own chain verification (which would need a root bundle). The
  // TLS handshake still proves possession of the server's private key, and
  // gRPC still populates `peer_cert_full_chain()` for the verifier.
  options.set_verify_server_certs(false);

  // A fresh verifier per credentials object, as on Apple platforms: gRPC
  // compares TLS credentials by verifier identity, so this keeps channels
  // from sharing subchannels.
  options.set_certificate_verifier(
      grpc::experimental::ExternalCertificateVerifier::Create<AsyncTlsVerifier>(
          MakeThreadPoolEvaluator(config),
          AsyncTlsVerifier::Scheduler(ScheduleOnThreadPool)));

  return grpc::experimental::TlsCredentials(options);
}

std::unique_ptr<AsyncTlsVerifier> CreateWindowsTlsVerifier(
    const WindowsTrustConfig& config) {
  return std::make_unique<AsyncTlsVerifier>(MakeThreadPoolEvaluator(config),
                                            ScheduleOnThreadPool);
}

std::shared_ptr<grpc::ChannelCredentials> CreateDefaultTlsCredentials() {
  return CreateWindowsTlsCredentials();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(_WIN32)
