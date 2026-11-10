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

#import <arpa/inet.h>
#include <functional>
#include <memory>
#include <string>
#include <type_traits>
#include <utility>

#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/src/util/warnings.h"
#include "absl/strings/escaping.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/str_format.h"

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

// Returns the IPv6 literal to pass to `SecPolicyCreateSSL`. SecPolicy matches
// IPv4-mapped addresses only in hex form (`::ffff:7f00:1`), so dotted forms
// such as `::ffff:127.0.0.1` are rewritten; other literals are unchanged.
// `literal` must be the zone-free text that `addr` was parsed from.
std::string Ipv6HostForSecPolicy(const struct in6_addr& addr,
                                 NSString* literal) {
  if (IN6_IS_ADDR_V4MAPPED(&addr)) {
    return absl::StrFormat("::ffff:%x:%x",
                           (addr.s6_addr[12] << 8) | addr.s6_addr[13],
                           (addr.s6_addr[14] << 8) | addr.s6_addr[15]);
  }
  return util::MakeString((__bridge CFStringRef)literal);
}

std::string ExtractTlsHostName(absl::string_view target_name) {
  if (target_name.empty()) {
    return "";
  }

  @autoreleasepool {
    NSString* target = [[NSString alloc] initWithBytes:target_name.data()
                                                length:target_name.size()
                                              encoding:NSUTF8StringEncoding];
    if (target == nil || target.length == 0) {
      return "";
    }

    if ([target rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]]
                .location != NSNotFound ||
        [target rangeOfCharacterFromSet:[NSCharacterSet
                                            whitespaceAndNewlineCharacterSet]]
                .location != NSNotFound ||
        [target
            rangeOfCharacterFromSet:
                [NSCharacterSet characterSetWithCharactersInString:@"/,?#@"]]
                .location != NSNotFound) {
      return "";
    }

    BOOL has_open_bracket = [target rangeOfString:@"["].location != NSNotFound;
    BOOL has_close_bracket = [target rangeOfString:@"]"].location != NSNotFound;

    // Handle bare unbracketed IPv6 literals.
    if (!has_open_bracket && !has_close_bracket &&
        [target rangeOfString:@":"].location != NSNotFound) {
      NSRange percent_range = [target rangeOfString:@"%"];
      NSString* candidate = target;
      if (percent_range.location != NSNotFound) {
        if (percent_range.location == 0 ||
            percent_range.location + 1 == target.length ||
            [target rangeOfString:@"%" options:NSBackwardsSearch].location !=
                percent_range.location) {
          return "";
        }
        candidate = [target substringToIndex:percent_range.location];
      }
      struct in6_addr addr6;
      if (inet_pton(AF_INET6, candidate.UTF8String, &addr6) == 1) {
        return Ipv6HostForSecPolicy(addr6, candidate);
      }
      if (percent_range.location != NSNotFound) {
        return "";
      }
    }

    // Handle bracketed IPv6 ([ipv6] or [ipv6]:port).
    if (has_open_bracket || has_close_bracket) {
      if (![target hasPrefix:@"["]) {
        return "";
      }
      NSUInteger close_bracket = [target rangeOfString:@"]"].location;
      if (close_bracket == NSNotFound || close_bracket == 1) {
        return "";
      }
      if ([target rangeOfString:@"[" options:NSBackwardsSearch].location != 0 ||
          [target rangeOfString:@"]" options:NSBackwardsSearch].location !=
              close_bracket) {
        return "";
      }
      NSString* inner =
          [target substringWithRange:NSMakeRange(1, close_bracket - 1)];
      NSRange inner_percent = [inner rangeOfString:@"%"];
      NSString* ipv6_candidate = inner;
      if (inner_percent.location != NSNotFound) {
        if (inner_percent.location == 0 ||
            inner_percent.location + 1 == inner.length ||
            [inner rangeOfString:@"%" options:NSBackwardsSearch].location !=
                inner_percent.location) {
          return "";
        }
        ipv6_candidate = [inner substringToIndex:inner_percent.location];
      }

      struct in6_addr addr6;
      if (inet_pton(AF_INET6, ipv6_candidate.UTF8String, &addr6) != 1) {
        return "";
      }

      NSString* suffix = [target substringFromIndex:close_bracket + 1];
      NSString* normalized =
          [NSString stringWithFormat:@"[%@]%@", ipv6_candidate, suffix];
      NSURLComponents* comps = [NSURLComponents
          componentsWithString:[@"https://"
                                   stringByAppendingString:normalized]];
      if (comps == nil || comps.host.length == 0) {
        return "";
      }
      if (suffix.length > 0) {
        if (comps.port == nil ||
            ![suffix isEqualToString:[@":" stringByAppendingString:
                                               comps.port.stringValue]]) {
          return "";
        }
      } else if (comps.port != nil) {
        return "";
      }
      return Ipv6HostForSecPolicy(addr6, ipv6_candidate);
    }

    // Non-bracketed host or host:port.
    if ([target rangeOfString:@"%"].location != NSNotFound) {
      return "";
    }
    NSURLComponents* comps = [NSURLComponents
        componentsWithString:[@"https://" stringByAppendingString:target]];
    if (comps == nil || comps.host.length == 0) {
      return "";
    }
    if ([target rangeOfString:@":"].location != NSNotFound) {
      if (comps.port == nil ||
          ![target
              isEqualToString:[NSString stringWithFormat:@"%@:%@", comps.host,
                                                         comps.port]]) {
        return "";
      }
    } else {
      if (![target isEqualToString:comps.host]) {
        return "";
      }
    }
    return util::MakeString((__bridge CFStringRef)comps.host);
  }
}

CFArrayRef CreateCertificateChainFromPem(absl::string_view pem_chain,
                                         grpc::Status* out_status) {
  if (pem_chain.empty()) {
    SetStatus(out_status,
              grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                           "No PEM certificates found in peer chain"));
    return nullptr;
  }

  @autoreleasepool {
    NSString* pem = [[NSString alloc] initWithBytes:pem_chain.data()
                                             length:pem_chain.size()
                                           encoding:NSUTF8StringEncoding];
    if (pem == nil || pem.length == 0) {
      SetStatus(out_status, grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                                         "Invalid UTF-8 in PEM peer chain"));
      return nullptr;
    }

    CFMutableArrayRef certs =
        CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    if (certs == nullptr) {
      SetStatus(out_status,
                grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                             "Failed to allocate CFArray for peer chain"));
      return nullptr;
    }

    bool ok = false;
    util::Defer cleanup_certs([&] {
      if (!ok) {
        util::SafeCFRelease(certs);
      }
    });

    NSString* const kBeginMarker = @"-----BEGIN CERTIFICATE-----";
    NSString* const kEndMarker = @"-----END CERTIFICATE-----";
    // Under RFC 7468 (Textual Encodings of PKIX Artifacts), PEM formatting is
    // strictly 7-bit ASCII consisting of spaces, horizontal tabs, carriage
    // returns, and newlines. Using explicit ASCII whitespace characters rather
    // than `+[NSCharacterSet whitespaceAndNewlineCharacterSet]` prevents
    // non-ASCII Unicode whitespace (such as U+00A0 non-breaking space or
    // U+3000 ideographic space) from being permissively stripped from base64
    // payloads.
    NSCharacterSet* ws =
        [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n"];

    NSScanner* scanner = [NSScanner scannerWithString:pem];
    scanner.charactersToBeSkipped = nil;

    while (!scanner.isAtEnd) {
      [scanner scanCharactersFromSet:ws intoString:NULL];
      if (scanner.isAtEnd) {
        break;
      }

      if ([scanner scanString:kEndMarker intoString:NULL]) {
        SetStatus(
            out_status,
            grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                         "Stray PEM END CERTIFICATE marker in peer chain"));
        return nullptr;
      }

      if (![scanner scanString:kBeginMarker intoString:NULL]) {
        SetStatus(out_status,
                  grpc::Status(
                      grpc::StatusCode::UNAUTHENTICATED,
                      "Unexpected non-whitespace text outside PEM CERTIFICATE "
                      "block in peer chain"));
        return nullptr;
      }

      NSString* raw_base64 = @"";
      [scanner scanUpToString:kEndMarker intoString:&raw_base64];

      if ([raw_base64 rangeOfString:kBeginMarker].location != NSNotFound) {
        SetStatus(out_status,
                  grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                               "Nested or unclosed PEM CERTIFICATE block"));
        return nullptr;
      }

      if (![scanner scanString:kEndMarker intoString:NULL]) {
        SetStatus(out_status,
                  grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                               "Unclosed PEM CERTIFICATE block in peer chain"));
        return nullptr;
      }

      NSString* clean_base64 =
          [[raw_base64 componentsSeparatedByCharactersInSet:ws]
              componentsJoinedByString:@""];

      if (clean_base64.length == 0) {
        SetStatus(
            out_status,
            grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                         "Invalid base64 payload in PEM CERTIFICATE block"));
        return nullptr;
      }

      NSData* der_data =
          [[NSData alloc] initWithBase64EncodedString:clean_base64 options:0];
      if (der_data == nil || der_data.length == 0) {
        SetStatus(
            out_status,
            grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                         "Invalid base64 payload in PEM CERTIFICATE block"));
        return nullptr;
      }

      SecCertificateRef cert = SecCertificateCreateWithData(
          kCFAllocatorDefault, (__bridge CFDataRef)der_data);
      if (cert == nullptr) {
        SetStatus(out_status,
                  grpc::Status(
                      grpc::StatusCode::UNAUTHENTICATED,
                      "Failed to parse DER X.509 certificate in peer chain"));
        return nullptr;
      }

      CFArrayAppendValue(certs, cert);
      CFRelease(cert);
    }

    if (CFArrayGetCount(certs) == 0) {
      SetStatus(out_status,
                grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                             "No PEM certificates found in peer chain"));
      return nullptr;
    }

    ok = true;
    SetStatus(out_status, grpc::Status::OK);
    return certs;
  }
}

// Owns a +1 CoreFoundation reference. Captured by value in blocks (which
// copy-construct C++ captures) so that CF objects live exactly as long as the
// blocks that use them, whether or not those blocks ever run.
template <typename T>
using SharedCFRef = std::shared_ptr<typename std::remove_pointer<T>::type>;

template <typename T>
SharedCFRef<T> AdoptCFRef(T ref) {
  return SharedCFRef<T>(ref, [](T r) { util::SafeCFRelease(r); });
}

template <typename T>
SharedCFRef<T> RetainCFRef(T ref) {
  if (ref != nullptr) {
    CFRetain(ref);
  }
  return AdoptCFRef(ref);
}

/**
 * Creates a `SecTrustRef` for `pem_chain` with the SSL server policy for the
 * host in `target_name`, restricted to `anchor_certs` when non-null. This is
 * the setup shared by the synchronous and asynchronous evaluation paths.
 *
 * On success, returns a +1 reference and stores the host name in `*out_host`.
 * On failure, returns nullptr and stores the reason in `*out_status`.
 */
SecTrustRef CreateAppleSecTrust(absl::string_view pem_chain,
                                absl::string_view target_name,
                                CFArrayRef anchor_certs,
                                std::string* out_host,
                                grpc::Status* out_status) {
  @autoreleasepool {
    std::string host = ExtractTlsHostName(target_name);
    if (host.empty()) {
      SetStatus(out_status,
                grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                             absl::StrCat("Invalid or empty TLS target host "
                                          "name: '",
                                          absl::CHexEscape(target_name), "'")));
      return nullptr;
    }

    grpc::Status parse_status;
    CFArrayRef certs = CreateCertificateChainFromPem(pem_chain, &parse_status);
    util::Defer release_certs([&] { util::SafeCFRelease(certs); });
    if (certs == nullptr) {
      SetStatus(out_status, parse_status);
      return nullptr;
    }

    CFStringRef cf_host = util::MakeCFString(host);
    util::Defer release_host([&] { util::SafeCFRelease(cf_host); });
    if (cf_host == nullptr) {
      SetStatus(out_status,
                grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                             "Failed to convert TLS target host name to "
                             "CFString"));
      return nullptr;
    }

    SecPolicyRef policy = SecPolicyCreateSSL(/*server=*/true, cf_host);
    util::Defer release_policy([&] { util::SafeCFRelease(policy); });
    if (policy == nullptr) {
      SetStatus(out_status,
                grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                             "Failed to create Apple SSL SecPolicy"));
      return nullptr;
    }

    SecTrustRef trust = nullptr;
    OSStatus trust_status =
        SecTrustCreateWithCertificates(certs, policy, &trust);
    bool ok = false;
    util::Defer release_trust([&] {
      if (!ok) {
        util::SafeCFRelease(trust);
      }
    });
    if (trust_status != errSecSuccess || trust == nullptr) {
      SetStatus(
          out_status,
          grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                       absl::StrCat("SecTrustCreateWithCertificates failed "
                                    "with OSStatus ",
                                    trust_status)));
      return nullptr;
    }

    // Never let trustd fetch missing intermediates (AIA caIssuers URLs) or
    // other resources over the network on behalf of the unauthenticated peer:
    // a server could otherwise make the device request any URL it chooses.
    // Incomplete chains fail closed instead, as they do on Linux and Windows.
    // This also turns off online revocation checks, which are not requested.
    OSStatus fetch_status = SecTrustSetNetworkFetchAllowed(trust, false);
    if (fetch_status != errSecSuccess) {
      SetStatus(out_status,
                grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                             absl::StrCat("SecTrustSetNetworkFetchAllowed "
                                          "failed with OSStatus ",
                                          fetch_status)));
      return nullptr;
    }

    if (anchor_certs != nullptr) {
      OSStatus anchor_status =
          SecTrustSetAnchorCertificates(trust, anchor_certs);
      if (anchor_status != errSecSuccess) {
        SetStatus(out_status,
                  grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                               absl::StrCat("SecTrustSetAnchorCertificates "
                                            "failed with OSStatus ",
                                            anchor_status)));
        return nullptr;
      }
      OSStatus anchor_only_status =
          SecTrustSetAnchorCertificatesOnly(trust, true);
      if (anchor_only_status != errSecSuccess) {
        SetStatus(out_status,
                  grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                               absl::StrCat("SecTrustSetAnchorCertificatesOnly "
                                            "failed with OSStatus ",
                                            anchor_only_status)));
        return nullptr;
      }
    }

    ok = true;
    *out_host = std::move(host);
    SetStatus(out_status, grpc::Status::OK);
    return trust;
  }
}

/**
 * Maps the result of `SecTrustEvaluateWithError` or
 * `SecTrustEvaluateAsyncWithError` to a gRPC status. `error` is borrowed.
 */
grpc::Status TrustResultToStatus(bool trusted,
                                 CFErrorRef error,
                                 const std::string& host) {
  if (trusted) {
    return grpc::Status::OK;
  }

  std::string error_detail = "unknown SecTrust evaluation error";
  if (error != nullptr) {
    CFStringRef desc = CFErrorCopyDescription(error);
    util::Defer release_desc([&] { util::SafeCFRelease(desc); });
    if (desc != nullptr) {
      error_detail = util::MakeString(desc);
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
  // affect this verifier.
  SharedCFRef<CFArrayRef> anchors =
      AdoptCFRef(anchor_certs == nullptr
                     ? nullptr
                     : CFArrayCreateCopy(kCFAllocatorDefault, anchor_certs));
  // Under ARC the lambda holds a strong reference to `queue`, so the queue
  // lives as long as the verifier (and any copies of the evaluator).
  return [anchors, queue](TlsVerificationInput input,
                          TlsVerificationCallback completion) {
    VerifyAppleTlsCertificateChainAsync(std::move(input), anchors.get(), queue,
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

grpc::Status VerifyAppleTlsCertificateChain(absl::string_view pem_chain,
                                            absl::string_view target_name,
                                            CFArrayRef anchor_certs) {
  @autoreleasepool {
    std::string host;
    grpc::Status status;
    SecTrustRef trust = CreateAppleSecTrust(pem_chain, target_name,
                                            anchor_certs, &host, &status);
    util::Defer release_trust([&] { util::SafeCFRelease(trust); });
    if (trust == nullptr) {
      return status;
    }

    CFErrorRef cf_error = nullptr;
    bool trusted = SecTrustEvaluateWithError(trust, &cf_error);
    util::Defer release_error([&] { util::SafeCFRelease(cf_error); });
    return TrustResultToStatus(trusted, cf_error, host);
  }
}

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
  SharedCFRef<CFArrayRef> anchors = RetainCFRef(anchor_certs);

  dispatch_async(queue, ^{
    @autoreleasepool {
      std::string host;
      grpc::Status status;
      SharedCFRef<SecTrustRef> trust = AdoptCFRef(
          CreateAppleSecTrust(state->input.pem_chain, state->input.target_name,
                              anchors.get(), &host, &status));
      if (trust == nullptr) {
        state->completion(status);
        return;
      }

      // `SecTrustEvaluateAsyncWithError` must be called from `queue`, the
      // queue it delivers the result on; this block is running on it. The
      // result block keeps `trust` alive until it has run (or, if evaluation
      // fails to start, until it is discarded).
      OSStatus start_status = SecTrustEvaluateAsyncWithError(
          trust.get(), queue, ^(SecTrustRef, bool trusted, CFErrorRef error) {
            (void)trust;
            // `error` is owned by Security.framework; do not release it.
            state->completion(TrustResultToStatus(trusted, error, host));
          });
      if (start_status != errSecSuccess) {
        state->completion(grpc::Status(
            grpc::StatusCode::UNAUTHENTICATED,
            absl::StrCat("SecTrustEvaluateAsyncWithError failed with OSStatus ",
                         start_status)));
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
  // gRPC's default per-RPC `check_call_host(true)` (`ClientAuthFilter` ->
  // `SslCheckCallHost`) verifies the per-call HTTP/2 `:authority` header
  // before attaching sensitive bearer credentials (such as Firebase Auth and
  // AppCheck tokens). Leaving this enabled preserves defense-in-depth and
  // avoids calling the deprecated `set_check_call_host` setter.

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
