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

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif

// <winsock2.h> must precede <windows.h>, which otherwise pulls in the
// conflicting <winsock.h> if WIN32_LEAN_AND_MEAN was not set earlier.
#include <winsock2.h>  // NOLINT(build/include_order)
#include <ws2tcpip.h>  // NOLINT(build/include_order)

#include <windows.h>  // NOLINT(build/include_order)

#include <wincrypt.h>  // NOLINT(build/include_order)

#include <cstdint>
#include <cstring>
#include <exception>
#include <functional>
#include <limits>
#include <memory>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "Firestore/core/src/remote/grpc_tls_async_verification.h"
#include "Firestore/core/src/remote/grpc_tls_pem.h"
#include "Firestore/core/src/remote/grpc_tls_target_host.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/no_destructor.h"
#include "Firestore/core/src/util/statusor.h"
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
#pragma comment(lib, "ws2_32")
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

struct CertAltNameInfoDeleter {
  void operator()(CERT_ALT_NAME_INFO* info) const {
    LocalFree(info);
  }
};
using CertAltNameInfoPtr =
    std::unique_ptr<CERT_ALT_NAME_INFO, CertAltNameInfoDeleter>;

/** Converts UTF-8 to UTF-16. Returns false if `utf8` is not valid UTF-8. */
bool Utf8ToWide(absl::string_view utf8, std::wstring* out) {
  if (utf8.empty()) {
    out->clear();
    return true;
  }
  if (utf8.size() > static_cast<size_t>((std::numeric_limits<int>::max)())) {
    return false;
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

/** Converts an IP address literal to its binary (network order) form. */
bool IpAddressToBytes(const TlsTargetHost& target, std::string* out) {
  if (target.kind == TlsTargetHost::Kind::kIpv4) {
    in_addr addr;
    if (InetPtonA(AF_INET, target.host.c_str(), &addr) != 1) {
      return false;
    }
    out->assign(reinterpret_cast<const char*>(&addr), sizeof(addr));
    return true;
  }
  if (target.kind == TlsTargetHost::Kind::kIpv6) {
    in6_addr addr;
    if (InetPtonA(AF_INET6, target.host.c_str(), &addr) != 1) {
      return false;
    }
    out->assign(reinterpret_cast<const char*>(&addr), sizeof(addr));
    return true;
  }
  return false;
}

/**
 * Decodes `leaf`'s `subjectAltName` (`szOID_SUBJECT_ALT_NAME2`) extension.
 * Sets `*out` to null and returns OK if the certificate has no
 * `subjectAltName` extension.
 */
grpc::Status DecodeSubjectAltName(PCCERT_CONTEXT leaf,
                                  CertAltNameInfoPtr* out) {
  out->reset();
  PCERT_EXTENSION extension =
      CertFindExtension(szOID_SUBJECT_ALT_NAME2, leaf->pCertInfo->cExtension,
                        leaf->pCertInfo->rgExtension);
  if (extension == nullptr) {
    return grpc::Status::OK;
  }
  CERT_ALT_NAME_INFO* raw_names = nullptr;
  DWORD names_size = 0;
  if (!CryptDecodeObjectEx(kCertEncoding, X509_ALTERNATE_NAME,
                           extension->Value.pbData, extension->Value.cbData,
                           CRYPT_DECODE_ALLOC_FLAG,
                           /*pDecodePara=*/nullptr, &raw_names, &names_size)) {
    return Unauthenticated(absl::StrCat(
        "Failed to decode the leaf certificate's subjectAltName: error ",
        GetLastError()));
  }
  out->reset(raw_names);
  return grpc::Status::OK;
}

/**
 * Checks that `leaf` carries at least one `dNSName` `subjectAltName` entry,
 * preventing `CERT_CHAIN_POLICY_SSL` from succeeding via a legacy `Subject`
 * common name fallback (RFC 9525).
 */
grpc::Status VerifyHasDnsSubjectAltName(PCCERT_CONTEXT leaf,
                                        const TlsTargetHost& target) {
  CertAltNameInfoPtr names;
  grpc::Status decode_status = DecodeSubjectAltName(leaf, &names);
  if (!decode_status.ok()) {
    return decode_status;
  }
  if (names != nullptr) {
    for (DWORD i = 0; i < names->cAltEntry; ++i) {
      const CERT_ALT_NAME_ENTRY& entry = names->rgAltEntry[i];
      if (entry.dwAltNameChoice == CERT_ALT_NAME_DNS_NAME &&
          entry.pwszDNSName != nullptr && entry.pwszDNSName[0] != L'\0') {
        return grpc::Status::OK;
      }
    }
  }
  return Unauthenticated(absl::StrCat(
      "Windows TLS certificate verification failed for '",
      absl::CHexEscape(target.host),
      "': CERT_E_CN_NO_MATCH: the certificate has no DNS subjectAltName"));
}

/**
 * Checks that `leaf` has an `iPAddress` subjectAltName equal to the IP address
 * in `target`. As RFC 9525 and browsers require, the subject common name is
 * never consulted.
 */
grpc::Status VerifyIpAddressSubjectAltName(PCCERT_CONTEXT leaf,
                                           const TlsTargetHost& target) {
  std::string expected;
  if (!IpAddressToBytes(target, &expected)) {
    return Unauthenticated(absl::StrCat("Invalid IP address TLS target: '",
                                        absl::CHexEscape(target.host), "'"));
  }

  CertAltNameInfoPtr names;
  grpc::Status decode_status = DecodeSubjectAltName(leaf, &names);
  if (!decode_status.ok()) {
    return decode_status;
  }
  if (names != nullptr) {
    for (DWORD i = 0; i < names->cAltEntry; ++i) {
      const CERT_ALT_NAME_ENTRY& entry = names->rgAltEntry[i];
      if (entry.dwAltNameChoice == CERT_ALT_NAME_IP_ADDRESS &&
          entry.IPAddress.cbData == expected.size() &&
          entry.IPAddress.pbData != nullptr &&
          std::memcmp(entry.IPAddress.pbData, expected.data(),
                      expected.size()) == 0) {
        return grpc::Status::OK;
      }
    }
  }
  return Unauthenticated(absl::StrCat(
      "Windows TLS certificate verification failed for '",
      absl::CHexEscape(target.host),
      "': the certificate has no matching IP address subjectAltName"));
}

bool HasCrossCertDistPoints(PCCERT_CONTEXT cert) {
  return cert != nullptr && cert->pCertInfo != nullptr &&
         CertFindExtension(szOID_CROSS_CERT_DIST_POINTS,
                           cert->pCertInfo->cExtension,
                           cert->pCertInfo->rgExtension) != nullptr;
}

bool ChainHasCrossCertDistPoints(PCCERT_CHAIN_CONTEXT chain) {
  if (chain == nullptr) {
    return false;
  }
  for (DWORD i = 0; i < chain->cChain; ++i) {
    const CERT_SIMPLE_CHAIN* simple = chain->rgpChain[i];
    if (simple == nullptr) {
      continue;
    }
    for (DWORD j = 0; j < simple->cElement; ++j) {
      if (simple->rgpElement[j] != nullptr &&
          HasCrossCertDistPoints(simple->rgpElement[j]->pCertContext)) {
        return true;
      }
    }
  }
  return false;
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

constexpr DWORD kMaxEvalThreadPoolThreads = 4;

/**
 * A private Win32 thread pool bounded to `max_threads` worker threads.
 *
 * Held inside `util::NoDestructor` so the pool outlives any `AsyncTlsVerifier`
 * destroyed while an evaluation is still blocked in CryptoAPI.
 */
class BoundedThreadPool {
 public:
  explicit BoundedThreadPool(DWORD max_threads) {
    pool_ = CreateThreadpool(nullptr);
    if (pool_ == nullptr) {
      LOG_WARN(
          "CreateThreadpool failed with error %s; falling back to default "
          "Windows thread pool",
          GetLastError());
      return;
    }
    SetThreadpoolThreadMaximum(pool_, max_threads);
    if (!SetThreadpoolThreadMinimum(pool_, 1)) {
      LOG_WARN("SetThreadpoolThreadMinimum failed with error %s",
               GetLastError());
    }
    InitializeThreadpoolEnvironment(&env_);
    SetThreadpoolCallbackPool(&env_, pool_);
  }

  ~BoundedThreadPool() {
    if (pool_ != nullptr) {
      DestroyThreadpoolEnvironment(&env_);
      CloseThreadpool(pool_);
    }
  }

  BoundedThreadPool(const BoundedThreadPool&) = delete;
  BoundedThreadPool& operator=(const BoundedThreadPool&) = delete;

  PTP_CALLBACK_ENVIRON callback_environ() {
    return pool_ != nullptr ? &env_ : nullptr;
  }

 private:
  PTP_POOL pool_ = nullptr;
  TP_CALLBACK_ENVIRON env_ = {};
};

PTP_CALLBACK_ENVIRON GetEvalThreadPoolEnviron() {
  static util::NoDestructor<BoundedThreadPool> pool(kMaxEvalThreadPoolThreads);
  return pool->callback_environ();
}

// Separate 1-thread pool for cancellation deliveries so that `Cancel()` never
// queues behind `kMaxEvalThreadPoolThreads` evaluations blocked in CryptoAPI
// (matching `MakeAppleCancellationScheduler` on Apple) while keeping all work
// off the host process's default Win32 thread pool.
PTP_CALLBACK_ENVIRON GetCancelThreadPoolEnviron() {
  static util::NoDestructor<BoundedThreadPool> pool(1);
  return pool->callback_environ();
}

/**
 * Increments the reference count of the DLL/EXE containing `callback_fn` so it
 * cannot be unloaded (`FreeLibrary`) while a thread-pool callback or fallback
 * thread is still executing its code. Returns null if pinning fails.
 */
HMODULE PinModuleForCallback(PTP_WORK_CALLBACK callback_fn) {
  HMODULE module = nullptr;
  if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
                          reinterpret_cast<LPCWSTR>(callback_fn), &module)) {
    return nullptr;
  }
  return module;
}

struct ScheduledTask {
  std::function<void()> task;
  HMODULE module = nullptr;
};

VOID CALLBACK RunThreadPoolTask(PTP_CALLBACK_INSTANCE instance,
                                PVOID context,
                                PTP_WORK work) {
  CloseThreadpoolWork(work);
  std::unique_ptr<ScheduledTask> scheduled(
      static_cast<ScheduledTask*>(context));
  FreeLibraryWhenCallbackReturns(instance, scheduled->module);
  scheduled->task();
}

/**
 * Schedules `*task` on `GetCancelThreadPoolEnviron()`. Returns false, leaving
 * `*task` untouched and releasing any temporary module pin, if scheduling
 * fails.
 */
bool TrySubmitCancelTask(std::function<void()>* task) {
  auto scheduled =
      std::make_unique<ScheduledTask>(ScheduledTask{std::move(*task), nullptr});
  scheduled->module = PinModuleForCallback(&RunThreadPoolTask);
  if (scheduled->module == nullptr) {
    *task = std::move(scheduled->task);
    return false;
  }
  PTP_WORK work = CreateThreadpoolWork(RunThreadPoolTask, scheduled.get(),
                                       GetCancelThreadPoolEnviron());
  if (work != nullptr) {
    scheduled.release();  // Now owned by `RunThreadPoolTask`.
    SubmitThreadpoolWork(work);
    return true;
  }
  FreeLibrary(scheduled->module);
  *task = std::move(scheduled->task);
  return false;
}

/**
 * An `AsyncTlsVerifier::Scheduler` backed by a private Windows thread pool,
 * with a detached thread as a fallback since cancellation delivery must run.
 */
void ScheduleOnThreadPool(std::function<void()> task) {
  if (TrySubmitCancelTask(&task)) {
    return;
  }
  HMODULE module = PinModuleForCallback(&RunThreadPoolTask);
  try {
    std::thread([task = std::move(task), module]() mutable {
      {
        std::function<void()> local_task = std::move(task);
        local_task();
      }
      if (module != nullptr) {
        FreeLibraryAndExitThread(module, 0);
      }
    }).detach();
  } catch (const std::exception& e) {
    if (module != nullptr) {
      FreeLibrary(module);
    }
    LOG_ERROR("Failed to schedule TLS cancellation callback: %s", e.what());
  }
}

struct EvalTask {
  WindowsTrustConfig config;
  TlsVerificationInput input;
  TlsVerificationCallback completion;
  HMODULE module = nullptr;
};

VOID CALLBACK RunEvalTask(PTP_CALLBACK_INSTANCE instance,
                          PVOID context,
                          PTP_WORK work) {
  CloseThreadpoolWork(work);
  std::unique_ptr<EvalTask> task(static_cast<EvalTask*>(context));
  FreeLibraryWhenCallbackReturns(instance, task->module);
  // Chain building may fetch root updates over the network.
  CallbackMayRunLong(instance);
  if (task->config.before_async_evaluation) {
    task->config.before_async_evaluation();
  }
  grpc::Status status = VerifyWindowsTlsCertificateChain(
      task->input.pem_chain, task->input.target_name, task->config);
  if (!status.ok()) {
    LOG_WARN("TLS peer certificate verification failed: %s",
             status.error_message());
  }
  task->completion(std::move(status));
}

/**
 * An `AsyncTlsVerifier::Evaluator` that runs `VerifyWindowsTlsCertificateChain`
 * on the bounded Windows evaluation thread pool.
 */
void EvaluateOnThreadPool(const WindowsTrustConfig& config,
                          TlsVerificationInput input,
                          TlsVerificationCallback completion) {
  auto task = std::make_unique<EvalTask>(
      EvalTask{config, std::move(input), std::move(completion), nullptr});
  task->module = PinModuleForCallback(&RunEvalTask);
  if (task->module == nullptr) {
    DWORD error = GetLastError();
    grpc::Status status(
        grpc::StatusCode::UNAVAILABLE,
        absl::StrCat("Failed to schedule TLS certificate verification: "
                     "GetModuleHandleExW failed with error ",
                     error));
    LOG_WARN("TLS peer certificate verification failed: %s",
             status.error_message());
    task->completion(std::move(status));
    return;
  }
  PTP_WORK work =
      CreateThreadpoolWork(RunEvalTask, task.get(), GetEvalThreadPoolEnviron());
  if (work != nullptr) {
    task.release();  // Now owned by `RunEvalTask`.
    SubmitThreadpoolWork(work);
    return;
  }
  DWORD error = GetLastError();
  FreeLibrary(task->module);
  grpc::Status status(
      grpc::StatusCode::UNAVAILABLE,
      absl::StrCat("Failed to schedule TLS certificate verification: "
                   "CreateThreadpoolWork failed with error ",
                   error));
  LOG_WARN("TLS peer certificate verification failed: %s",
           status.error_message());
  // `AsyncTlsVerifier` reports an inline completion synchronously.
  task->completion(std::move(status));
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
  util::StatusOr<TlsTargetHost> parsed = ParseTlsTargetHost(target_name);
  if (!parsed.ok()) {
    return Unauthenticated(absl::StrCat(parsed.status().error_message(), ": '",
                                        absl::CHexEscape(target_name), "'"));
  }
  const TlsTargetHost& target = parsed.ValueOrDie();
  if (target.kind == TlsTargetHost::Kind::kDns &&
      (target.host.empty() || target.host.front() == '.' ||
       target.host.back() == '.' ||
       target.host.find('*') != std::string::npos)) {
    return Unauthenticated(absl::StrCat("Invalid TLS target host name: '",
                                        absl::CHexEscape(target_name), "'"));
  }
  std::wstring server_name;
  if (!Utf8ToWide(target.host, &server_name)) {
    return Unauthenticated(absl::StrCat("Invalid TLS target host name: '",
                                        absl::CHexEscape(target_name), "'"));
  }

  util::StatusOr<std::vector<std::string>> ders_or =
      SplitPemCertificates(pem_chain);
  if (!ders_or.ok()) {
    return Unauthenticated(ders_or.status().error_message());
  }
  const std::vector<std::string>& ders = ders_or.ValueOrDie();

  if (ders[0].size() > static_cast<size_t>(MAXDWORD)) {
    return Unauthenticated(
        "Leaf certificate in peer chain exceeds maximum supported size");
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

  bool peer_has_ccdp = HasCrossCertDistPoints(leaf.get());

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
    if (ders[i].size() > static_cast<size_t>(MAXDWORD)) {
      return Unauthenticated(
          absl::StrCat("Intermediate certificate ", i,
                       " in peer chain exceeds maximum supported size"));
    }
    PCCERT_CONTEXT raw_intermediate = nullptr;
    if (!CertAddEncodedCertificateToStore(
            intermediates.get(), kCertEncoding,
            reinterpret_cast<const BYTE*>(ders[i].data()),
            static_cast<DWORD>(ders[i].size()), CERT_STORE_ADD_ALWAYS,
            &raw_intermediate)) {
      return Unauthenticated(
          absl::StrCat("Failed to parse intermediate certificate ", i,
                       " in peer chain: error ", GetLastError()));
    }
    CertContextPtr intermediate(raw_intermediate);
    peer_has_ccdp = peer_has_ccdp || HasCrossCertDistPoints(intermediate.get());
  }

  char server_auth_oid[] = szOID_PKIX_KP_SERVER_AUTH;
  LPSTR usages[] = {server_auth_oid};
  CERT_CHAIN_PARA chain_para = {};
  chain_para.cbSize = sizeof(chain_para);
  chain_para.RequestedUsage.dwType = USAGE_MATCH_TYPE_AND;
  chain_para.RequestedUsage.Usage.cUsageIdentifier = 1;
  chain_para.RequestedUsage.Usage.rgpszUsageIdentifier = usages;

  auto build_chain = [&](DWORD flags, CertChainPtr* out) -> grpc::Status {
    PCCERT_CHAIN_CONTEXT raw_chain = nullptr;
    if (!CertGetCertificateChain(
            static_cast<HCERTCHAINENGINE>(config.chain_engine.get()),
            leaf.get(), /*pTime=*/nullptr, intermediates.get(), &chain_para,
            flags, /*pvReserved=*/nullptr, &raw_chain) ||
        raw_chain == nullptr) {
      return Unauthenticated(absl::StrCat(
          "CertGetCertificateChain failed with error ", GetLastError()));
    }
    out->reset(raw_chain);
    return grpc::Status::OK;
  };

  // Pass 1 (offline fast path): build the chain using only locally cached
  // roots, intermediates, and CTLs (`CERT_CHAIN_CACHE_ONLY_URL_RETRIEVAL`)
  // with RFC 5280 AIA disabled (`CERT_CHAIN_DISABLE_AIA`). Whenever the root
  // is already in `Root`, `AuthRoot`, or `hExclusiveRoot`, zero network I/O
  // occurs.
  //
  // No revocation flags: like the bundled-roots verification this replaces,
  // and like browsers, don't block on online CRL/OCSP checks. Certificates
  // in the `Disallowed` store and Microsoft's distrust lists are still
  // rejected.
  CertChainPtr chain;
  grpc::Status chain_status = build_chain(
      CERT_CHAIN_DISABLE_AIA | CERT_CHAIN_CACHE_ONLY_URL_RETRIEVAL, &chain);
  if (!chain_status.ok()) {
    return chain_status;
  }

  // Pass 2 (`AuthRoot` fallback): only allow network URL retrieval (so Windows
  // Automatic Root Certificates Update can fetch an uncached Microsoft-trusted
  // root) when using the system chain engine, Pass 1 failed solely for a
  // missing/untrusted root without explicit distrust, and no certificate in
  // the peer chain or built path carries Microsoft's Cross-Certificate
  // Distribution Points (`szOID_CROSS_CERT_DIST_POINTS`) extension — which
  // `CERT_CHAIN_DISABLE_AIA` does not suppress and which would otherwise let
  // an unauthenticated peer trigger outbound HTTP/LDAP/SMB requests.
  constexpr DWORD kMissingRootErrors =
      CERT_TRUST_IS_PARTIAL_CHAIN | CERT_TRUST_IS_UNTRUSTED_ROOT;
  const DWORD trust_errors = chain->TrustStatus.dwErrorStatus;
  if (config.chain_engine == nullptr && !peer_has_ccdp &&
      !ChainHasCrossCertDistPoints(chain.get()) &&
      (trust_errors & kMissingRootErrors) != 0 &&
      (trust_errors & CERT_TRUST_IS_EXPLICIT_DISTRUST) == 0) {
    chain_status = build_chain(CERT_CHAIN_DISABLE_AIA, &chain);
    if (!chain_status.ok()) {
      return chain_status;
    }
  }

  // CryptoAPI's SSL policy matches DNS names, but falls back to the Subject
  // Common Name when the certificate has no `dNSName` subjectAltName;
  // `VerifyHasDnsSubjectAltName()` closes that fallback afterwards (RFC 9525).
  // Its handling of IP address targets against `iPAddress` subjectAltNames
  // isn't consistent across Windows versions, so for IP targets the policy
  // skips the name check (null server name) and
  // `VerifyIpAddressSubjectAltName()` does it.
  const bool is_ip_target = target.kind != TlsTargetHost::Kind::kDns;
  SSL_EXTRA_CERT_CHAIN_POLICY_PARA ssl_para = {};
  ssl_para.cbSize = sizeof(ssl_para);
  ssl_para.dwAuthType = AUTHTYPE_SERVER;
  ssl_para.fdwChecks = 0;
  ssl_para.pwszServerName = is_ip_target ? nullptr : &server_name[0];

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
    return Unauthenticated(
        absl::StrCat("Windows TLS certificate verification failed for '",
                     absl::CHexEscape(target.host),
                     "': ", DescribeChainPolicyError(policy_status.dwError)));
  }
  if (is_ip_target) {
    return VerifyIpAddressSubjectAltName(leaf.get(), target);
  }
  return VerifyHasDnsSubjectAltName(leaf.get(), target);
}

std::shared_ptr<grpc::ChannelCredentials> CreateWindowsTlsCredentials(
    const WindowsTrustConfig& config) {
  grpc::experimental::TlsChannelCredentialsOptions options;

  // CryptoAPI owns chain building, trust, and hostname checks, so skip the SSL
  // library's own chain verification (which would need a root bundle). The
  // TLS handshake still proves possession of the server's private key, and
  // gRPC still populates `peer_cert_full_chain()` for the verifier.
  options.set_verify_server_certs(false);

  // gRPC's default per-RPC `check_call_host` stays enabled, as on Apple and
  // Linux; see the note on canonical IP-literal hosts in
  // grpc_tls_credentials_provider.h.

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
