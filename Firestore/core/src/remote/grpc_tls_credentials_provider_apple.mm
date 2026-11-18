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

#include "Firestore/core/src/remote/grpc_tls_credentials_provider_apple.h"

#if defined(__APPLE__)

#import <Foundation/Foundation.h>
#import <Security/Security.h>

#include <arpa/inet.h>  // NOLINT(build/include)
#include <netinet/in.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/remote/grpc_tls_pem.h"
#include "Firestore/core/src/remote/grpc_tls_target_host.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/src/util/warnings.h"
#include "absl/strings/escaping.h"
#include "absl/strings/str_cat.h"
#include "absl/types/optional.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/security/tls_certificate_verifier.h"
#include "grpcpp/security/tls_credentials_options.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace {

void SetStatus(grpc::Status* out_status, const grpc::Status& status) {
  if (out_status != nullptr) {
    *out_status = status;
  }
}

// Returns the host to pass to `SecPolicyCreateSSL` for `target_name`, or an
// empty string if `target_name` is malformed (see `ParseTlsTargetHost()`).
//
// `SecPolicyCreateSSL` only matches an IPv6 address with an embedded IPv4
// suffix (such as the IPv4-mapped `::ffff:127.0.0.1`, which is how `inet_ntop`
// writes it) against a certificate's IP SAN when the address is written all
// in hex (`::ffff:7f00:1`), so such addresses are rewritten here.
std::string ExtractTlsHostName(absl::string_view target_name) {
  absl::optional<TlsTargetHost> host = ParseTlsTargetHost(target_name);
  if (!host.has_value()) {
    return std::string();
  }
  if (host->kind == TlsTargetHost::Kind::kIpv6 &&
      host->host.find('.') != std::string::npos) {
    in6_addr addr = {};
    if (inet_pton(AF_INET6, host->host.c_str(), &addr) != 1) {
      return std::string();
    }
    const uint8_t* b = addr.s6_addr;
    size_t last_colon = host->host.rfind(':');
    host->host = absl::StrCat(host->host.substr(0, last_colon + 1),
                              absl::Hex((b[12] << 8) | b[13]), ":",
                              absl::Hex((b[14] << 8) | b[15]));
  }
  return host->host;
}

bool ContainsNonAscii(absl::string_view s) {
  for (char c : s) {
    if (static_cast<unsigned char>(c) >= 0x80) {
      return true;
    }
  }
  return false;
}

// This file is compiled with ARC. CoreFoundation objects that this code owns
// are handed to ARC with `CFBridgingRelease` and held in `id` / `NSArray*`
// variables, which blocks and lambdas retain automatically. Borrowed references
// (the caller's `anchor_certs`, and the `CFErrorRef` that Security.framework
// passes to the evaluation result block) are only ever bridged with `__bridge`.

// Parses `pem_chain` into an array of `SecCertificateRef`s, failing closed on
// any malformed input (see `SplitPemCertificates()`). On failure, returns nil
// and stores the reason in `*out_status`.
NSArray* CreateCertificateChainFromPem(absl::string_view pem_chain,
                                       grpc::Status* out_status) {
  std::vector<std::string> der_certificates;
  std::string error;
  if (!SplitPemCertificates(pem_chain, &der_certificates, &error)) {
    SetStatus(out_status,
              grpc::Status(grpc::StatusCode::UNAUTHENTICATED, error));
    return nil;
  }

  NSMutableArray* certs =
      [NSMutableArray arrayWithCapacity:der_certificates.size()];
  for (const std::string& der : der_certificates) {
    NSData* data = [NSData dataWithBytes:der.data() length:der.size()];
    id cert = CFBridgingRelease(SecCertificateCreateWithData(
        kCFAllocatorDefault, (__bridge CFDataRef)data));
    if (cert == nil) {
      SetStatus(
          out_status,
          grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                       "Failed to parse DER X.509 certificate in peer chain"));
      return nil;
    }
    [certs addObject:cert];
  }

  SetStatus(out_status, grpc::Status::OK);
  return certs;
}

grpc::Status OSStatusError(const char* function, OSStatus status) {
  return grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                      absl::StrCat(function, " failed with OSStatus ", status));
}

/**
 * Creates a `SecTrustRef` for `pem_chain` with the SSL server policy for the
 * host in `target_name`, restricted to `anchors` when non-nil.
 *
 * On success, returns the trust object and stores the host name in
 * `*out_host`. On failure, returns nil and stores the reason in `*out_status`.
 */
id CreateAppleSecTrust(absl::string_view pem_chain,
                       absl::string_view target_name,
                       NSArray* anchors,
                       std::string* out_host,
                       grpc::Status* out_status) {
  std::string host = ExtractTlsHostName(target_name);
  if (host.empty()) {
    SetStatus(
        out_status,
        grpc::Status(
            grpc::StatusCode::UNAUTHENTICATED,
            ContainsNonAscii(target_name)
                ? absl::StrCat("TLS target host name must be ASCII; encode "
                               "internationalized names as Punycode "
                               "(A-labels): '",
                               absl::CHexEscape(target_name), "'")
                : absl::StrCat("Invalid or empty TLS target host name: '",
                               absl::CHexEscape(target_name), "'")));
    return nil;
  }

  NSArray* certs = CreateCertificateChainFromPem(pem_chain, out_status);
  if (certs == nil) {
    return nil;
  }

  NSString* ns_host = util::MakeNSString(host);
  id policy = CFBridgingRelease(
      SecPolicyCreateSSL(/*server=*/true, (__bridge CFStringRef)ns_host));
  if (policy == nil) {
    SetStatus(out_status, grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                                       "Failed to create Apple SSL SecPolicy"));
    return nil;
  }

  SecTrustRef raw_trust = nullptr;
  OSStatus trust_status = SecTrustCreateWithCertificates(
      (__bridge CFArrayRef)certs, (__bridge SecPolicyRef)policy, &raw_trust);
  id trust = CFBridgingRelease(raw_trust);
  if (trust_status != errSecSuccess || trust == nil) {
    SetStatus(out_status,
              OSStatusError("SecTrustCreateWithCertificates", trust_status));
    return nil;
  }
  SecTrustRef sec_trust = (__bridge SecTrustRef)trust;

  // Never let trustd fetch missing intermediates (AIA caIssuers URLs) or
  // other resources over the network on behalf of the unauthenticated peer:
  // a server could otherwise make the device request any URL it chooses.
  // Incomplete chains fail closed instead.
  //
  // Revocation: this verifier relies on trustd's locally stored revocation
  // data rather than per-handshake OCSP or CRL queries. `SecPolicyCreateSSL`
  // alone requests no live revocation checking (that would take
  // `SecPolicyCreateRevocation`), and with network fetches disabled none
  // could happen anyway. Disabling fetches does not disable Apple's `Valid`
  // revocation database, which trustd syncs in the background and consults
  // offline, nor OS, MDM, or OTA trust-store updates. Live checks are avoided
  // because they add latency to every connection (and can stall it behind an
  // unreachable responder), reveal to the CA which hosts the device connects
  // to, and, being necessarily soft-fail in a client library, offer little
  // protection against an attacker who can block the responder. A second,
  // network-enabled evaluation after an offline one would be exactly such a
  // live check, with the same costs.
  //
  // This is an accepted trade-off of delegating trust to the OS: a device
  // whose `Valid` data is stale (for example, freshly restored, or unable to
  // reach Apple) may accept a chain that Apple has since revoked. That can
  // include chains the previous embedded root bundle rejected, where a root
  // was removed from the bundle but Apple still trusts it and blocks only
  // specific intermediates. In the common case, though, the OS's revocation
  // updates arrive far sooner than an app ships a new SDK with a new bundle.
  OSStatus fetch_status = SecTrustSetNetworkFetchAllowed(sec_trust, false);
  if (fetch_status != errSecSuccess) {
    SetStatus(out_status,
              OSStatusError("SecTrustSetNetworkFetchAllowed", fetch_status));
    return nil;
  }

  if (anchors != nil) {
    OSStatus anchor_status =
        SecTrustSetAnchorCertificates(sec_trust, (__bridge CFArrayRef)anchors);
    if (anchor_status != errSecSuccess) {
      SetStatus(out_status,
                OSStatusError("SecTrustSetAnchorCertificates", anchor_status));
      return nil;
    }
    OSStatus anchor_only_status =
        SecTrustSetAnchorCertificatesOnly(sec_trust, true);
    if (anchor_only_status != errSecSuccess) {
      SetStatus(out_status, OSStatusError("SecTrustSetAnchorCertificatesOnly",
                                          anchor_only_status));
      return nil;
    }
  }

  *out_host = std::move(host);
  SetStatus(out_status, grpc::Status::OK);
  return trust;
}

/**
 * Maps the result of `SecTrustEvaluateAsyncWithError` to a gRPC status. `error`
 * is borrowed (owned by Security.framework).
 */
grpc::Status TrustResultToStatus(bool trusted,
                                 CFErrorRef error,
                                 const std::string& host) {
  if (trusted) {
    return grpc::Status::OK;
  }

  std::string error_detail = "unknown SecTrust evaluation error";
  if (error != nullptr) {
    NSString* desc = CFBridgingRelease(CFErrorCopyDescription(error));
    if (desc != nil) {
      // The description quotes certificate subject names chosen by the peer,
      // so escape it, like the target name above, to prevent log injection.
      error_detail = absl::CHexEscape(util::MakeString(desc));
    }
  }

  return grpc::Status(
      grpc::StatusCode::UNAUTHENTICATED,
      absl::StrCat("Apple SecTrust TLS certificate verification failed for '",
                   host, "': ", error_detail));
}

AsyncTlsVerifier::Evaluator MakeAppleSecTrustEvaluator(CFArrayRef anchor_certs,
                                                       dispatch_queue_t queue) {
  if (queue == nullptr) {
    queue =
        dispatch_queue_create("com.google.firebase.firestore.tls_verification",
                              DISPATCH_QUEUE_SERIAL);
  }
  // Snapshot the caller's anchors so later mutation of a mutable array cannot
  // affect this verifier. The lambda holds strong references to `anchors` and
  // `queue`, so both live as long as the verifier (and any evaluator copies).
  NSArray* anchors =
      anchor_certs == nullptr ? nil : [(__bridge NSArray*)anchor_certs copy];
  return [anchors, queue](TlsVerificationInput input,
                          TlsVerificationCallback completion) {
    VerifyAppleTlsCertificateChainAsync(std::move(input),
                                        (__bridge CFArrayRef)anchors, queue,
                                        std::move(completion));
  };
}

// Delivers cancellations on a global concurrent queue: never on the thread
// inside `Cancel()` (which holds gRPC's handshake lock), and independent of the
// verifier's evaluation queue, which may be busy.
AsyncTlsVerifier::Scheduler MakeAppleCancellationScheduler() {
  return [](std::function<void()> task) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
      task();
    });
  };
}

}  // namespace

void VerifyAppleTlsCertificateChainAsync(TlsVerificationInput input,
                                         CFArrayRef anchor_certs,
                                         dispatch_queue_t queue,
                                         TlsVerificationCallback completion) {
  HARD_ASSERT(queue != nullptr, "TLS verification queue must not be null");
  HARD_ASSERT(completion != nullptr,
              "TLS verification completion must not be null");

  // Blocks copy C++ captures, so move the inputs into shared state once rather
  // than copying the PEM chain into every block.
  struct State {
    TlsVerificationInput input;
    TlsVerificationCallback completion;
  };
  auto state =
      std::make_shared<State>(State{std::move(input), std::move(completion)});
  // Borrowed from the caller; the block below retains it.
  NSArray* anchors = (__bridge NSArray*)anchor_certs;

  dispatch_async(queue, ^{
    @autoreleasepool {
      std::string host;
      grpc::Status status;
      id trust =
          CreateAppleSecTrust(state->input.pem_chain, state->input.target_name,
                              anchors, &host, &status);
      if (trust == nil) {
        state->completion(status);
        return;
      }

      // `SecTrustEvaluateAsyncWithError` must be called from `queue`, the
      // queue it delivers the result on; this block is running on it. The
      // result block retains `trust` until it has run (or, if evaluation
      // fails to start, until it is discarded).
      OSStatus start_status = SecTrustEvaluateAsyncWithError(
          (__bridge SecTrustRef)trust, queue,
          ^(SecTrustRef, bool trusted, CFErrorRef error) {
            (void)trust;
            state->completion(TrustResultToStatus(trusted, error, host));
          });
      if (start_status != errSecSuccess) {
        state->completion(
            OSStatusError("SecTrustEvaluateAsyncWithError", start_status));
      }
    }
  });
}

AppleSecTrustCertificateVerifier::AppleSecTrustCertificateVerifier(
    CFArrayRef anchor_certs, dispatch_queue_t queue)
    : AsyncTlsVerifier(MakeAppleSecTrustEvaluator(anchor_certs, queue),
                       MakeAppleCancellationScheduler()) {
}

std::shared_ptr<grpc::ChannelCredentials> CreateAppleTlsCredentials(
    CFArrayRef anchor_certs) {
  grpc::experimental::TlsChannelCredentialsOptions options;

  // Skip BoringSSL's static `X509_STORE` chain verification (and its default
  // `/etc/ssl/cert.pem` root lookup, which fails on iOS devices where that file
  // does not exist). BoringSSL still completes the full cryptographic TLS
  // handshake (verifying proof-of-possession of the server's private key) and
  // populates `peer_cert_full_chain()` for `AppleSecTrustCertificateVerifier`.
  options.set_verify_server_certs(false);

  // Keep gRPC's default `check_call_host(true)` alongside Apple SecTrust:
  // Handshake-time `SecTrust` evaluates the peer certificate chain against
  // `SecPolicyCreateSSL(/*server=*/true, cf_host)` on the channel target name,
  // enforcing Apple's strict RFC 9525 and HT210176 requirements (SAN-only,
  // PSL wildcard validation, and OS/MDM/OTA trust settings). In addition,
  // gRPC's per-call check (`ClientAuthFilter` -> `SslCheckCallHost`) matches
  // each call's `:authority` against the peer certificate and fails the call
  // before any request headers are sent, so a mismatch never transmits the
  // Firebase Auth and App Check tokens that Firestore adds as call metadata.
  // Leaving it enabled preserves defense-in-depth and avoids calling the
  // deprecated `set_check_call_host` setter. Because gRPC compares IP
  // addresses there as text, IP-literal hosts must be written in canonical
  // form (as `inet_ntop` prints them); see `CreateDefaultTlsCredentials()`.

  // Creates a dedicated verifier instance per channel credentials object.
  // In gRPC, `TlsCredentials::cmp_impl` compares credentials options by
  // verifier pointer identity. Allocating a fresh verifier per channel ensures
  // each channel receives its own subchannel in `GlobalSubchannelPool`,
  // preserving `GrpcConnection::RegisterConnectivityMonitor`'s ability to
  // drop dead TCP sockets immediately on cellular/Wi-Fi handover via
  // `grpc_channel_.reset()`.
  options.set_certificate_verifier(
      grpc::experimental::ExternalCertificateVerifier::Create<
          AppleSecTrustCertificateVerifier>(anchor_certs, nullptr));

  return grpc::experimental::TlsCredentials(options);
}

std::shared_ptr<grpc::ChannelCredentials> CreateDefaultTlsCredentials() {
  return CreateAppleTlsCredentials(/*anchor_certs=*/nullptr);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(__APPLE__)
