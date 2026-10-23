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

#include <functional>
#include <memory>
#include <string>

#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/no_destructor.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/src/util/warnings.h"
#include "absl/strings/match.h"
#include "absl/strings/str_cat.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/security/tls_certificate_verifier.h"
#include "grpcpp/security/tls_credentials_options.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace {

constexpr absl::string_view kPemBeginCert = "-----BEGIN CERTIFICATE-----";
constexpr absl::string_view kPemEndCert = "-----END CERTIFICATE-----";

void SetStatus(grpc::Status* out_status, const grpc::Status& status) {
  if (out_status != nullptr) {
    *out_status = status;
  }
}

bool IsAsciiDigit(char c) {
  return c >= '0' && c <= '9';
}

bool IsIpv6AddressChar(char c) {
  return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') ||
         (c >= 'A' && c <= 'F') || c == ':' || c == '.';
}

bool IsValidUnbracketedIpv6Literal(absl::string_view host) {
  size_t colons = 0;
  for (char c : host) {
    if (!IsIpv6AddressChar(c)) {
      return false;
    }
    if (c == ':') {
      ++colons;
    }
  }
  return colons >= 2;
}

bool IsBase64Alphabet(char c) {
  return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
         (c >= '0' && c <= '9') || c == '+' || c == '/';
}

// Validates that `encoded` (already stripped of horizontal/vertical ASCII
// whitespace) is non-empty, has length divisible by 4, contains only standard
// RFC 4648 base64 characters, and has at most 2 trailing '=' padding
// characters.
bool IsStrictStandardBase64(absl::string_view encoded) {
  if (encoded.empty() || (encoded.size() % 4) != 0) {
    return false;
  }

  size_t data_end = encoded.size();
  if (encoded[data_end - 1] == '=') {
    --data_end;
    if (encoded[data_end - 1] == '=') {
      --data_end;
    }
  }

  for (size_t i = 0; i < data_end; ++i) {
    if (!IsBase64Alphabet(encoded[i])) {
      return false;
    }
  }
  return true;
}

absl::string_view StripTrailingHorizontalWhitespace(absl::string_view line) {
  while (!line.empty() && (line.back() == ' ' || line.back() == '\t')) {
    line.remove_suffix(1);
  }
  return line;
}

absl::string_view ToStringView(grpc::string_ref ref) {
  return ref.empty() ? absl::string_view{}
                     : absl::string_view(ref.data(), ref.size());
}

class AppleSecTrustCertificateVerifier final
    : public grpc::experimental::ExternalCertificateVerifier {
 public:
  explicit AppleSecTrustCertificateVerifier(CFArrayRef anchor_certs)
      : anchor_certs_(anchor_certs) {
    if (anchor_certs_ != nullptr) {
      CFRetain(anchor_certs_);
    }
  }

  ~AppleSecTrustCertificateVerifier() override {
    util::SafeCFRelease(anchor_certs_);
  }

  AppleSecTrustCertificateVerifier(const AppleSecTrustCertificateVerifier&) =
      delete;
  AppleSecTrustCertificateVerifier& operator=(
      const AppleSecTrustCertificateVerifier&) = delete;

  bool Verify(grpc::experimental::TlsCustomVerificationCheckRequest* request,
              std::function<void(grpc::Status)> callback,
              grpc::Status* sync_status) override {
    // TODO(dconeybe): Convert this synchronous verification to
    // `SecTrustEvaluateAsyncWithError` or dispatch `SecTrustEvaluateWithError`
    // onto a background queue (`return false` and invoke `callback`) so IPC to
    // `trustd` cannot block gRPC's EventEngine threads.
    (void)callback;

    HARD_ASSERT(sync_status != nullptr,
                "TLS synchronous verification status output must not be null");
    if (request == nullptr) {
      *sync_status = grpc::Status(
          grpc::StatusCode::UNAUTHENTICATED,
          "TLS custom verification check request must not be null");
      return true;
    }

    grpc::string_ref chain_ref = request->peer_cert_full_chain();
    if (chain_ref.empty()) {
      chain_ref = request->peer_cert();
    }

    *sync_status = VerifyAppleTlsCertificateChain(
        ToStringView(chain_ref), ToStringView(request->target_name()),
        anchor_certs_);
    return true;
  }

  void Cancel(
      grpc::experimental::TlsCustomVerificationCheckRequest* request) override {
    // No-op: `Verify()` executes synchronously (`return true`), so there is
    // never an in-flight asynchronous request to cancel.
    (void)request;
  }

 private:
  CFArrayRef anchor_certs_ = nullptr;
};

// Reuses a single stateless `CertificateVerifier` instance when no custom test
// anchors are supplied so `TlsCredentials::cmp_impl` compares equal across
// `Firestore` instances, allowing gRPC's `GlobalSubchannelPool` to share a
// single HTTP/2 TLS connection to `firestore.googleapis.com`.
std::shared_ptr<grpc::experimental::CertificateVerifier>
GetDefaultAppleCertificateVerifier() {
  static util::NoDestructor<
      std::shared_ptr<grpc::experimental::CertificateVerifier>>
      verifier(grpc::experimental::ExternalCertificateVerifier::Create<
               AppleSecTrustCertificateVerifier>(/*anchor_certs=*/nullptr));
  return *verifier;
}

}  // namespace

std::string ExtractTlsHostName(absl::string_view target_name) {
  if (target_name.empty()) {
    return "";
  }

  // Reject embedded NUL bytes, ASCII control characters, and whitespace.
  for (char c : target_name) {
    auto uc = static_cast<unsigned char>(c);
    if (uc <= 0x20 || uc == 0x7f) {
      return "";
    }
  }

  // Strip recognized gRPC target URI prefixes if present.
  if (absl::StartsWith(target_name, "dns:///")) {
    target_name.remove_prefix(7);
  } else if (absl::StartsWith(target_name, "dns://")) {
    size_t slash = target_name.find('/', 6);
    if (slash == absl::string_view::npos) {
      return "";
    }
    target_name.remove_prefix(slash + 1);
  } else if (absl::StartsWith(target_name, "dns:")) {
    target_name.remove_prefix(4);
  } else if (absl::StartsWith(target_name, "ipv4:") ||
             absl::StartsWith(target_name, "ipv6:")) {
    target_name.remove_prefix(5);
  }

  if (target_name.empty()) {
    return "";
  }

  // Reject unrecognized URI schemes, paths, userinfo, query/fragment, or
  // multi-address comma lists.
  for (char c : target_name) {
    if (c == '/' || c == '?' || c == '#' || c == '@' || c == ',') {
      return "";
    }
  }

  if (target_name.front() == '[') {
    size_t close_bracket = target_name.find(']');
    if (close_bracket == absl::string_view::npos || close_bracket == 1) {
      return "";
    }
    absl::string_view host = target_name.substr(1, close_bracket - 1);
    size_t zone = host.find('%');
    if (zone != absl::string_view::npos) {
      if (zone == 0 || zone + 1 == host.size()) {
        return "";
      }
      host = host.substr(0, zone);
    }
    if (!IsValidUnbracketedIpv6Literal(host)) {
      return "";
    }
    absl::string_view rest = target_name.substr(close_bracket + 1);
    if (!rest.empty()) {
      if (rest.front() != ':' || rest.size() == 1) {
        return "";
      }
      for (size_t i = 1; i < rest.size(); ++i) {
        if (!IsAsciiDigit(rest[i])) {
          return "";
        }
      }
    }
    return std::string(host);
  }

  if (target_name.find('[') != absl::string_view::npos ||
      target_name.find(']') != absl::string_view::npos) {
    return "";
  }

  size_t colon_count = 0;
  size_t first_colon = absl::string_view::npos;
  for (size_t i = 0; i < target_name.size(); ++i) {
    if (target_name[i] == ':') {
      if (colon_count == 0) {
        first_colon = i;
      }
      ++colon_count;
    }
  }

  if (colon_count == 0) {
    if (target_name.find('%') != absl::string_view::npos) {
      return "";
    }
    return std::string(target_name);
  }

  if (colon_count > 1) {
    size_t zone = target_name.find('%');
    if (zone != absl::string_view::npos) {
      if (zone == 0 || zone + 1 == target_name.size()) {
        return "";
      }
      target_name = target_name.substr(0, zone);
    }
    if (!IsValidUnbracketedIpv6Literal(target_name)) {
      return "";
    }
    return std::string(target_name);
  }

  if (first_colon == 0 || first_colon + 1 >= target_name.size()) {
    return "";
  }
  for (size_t i = first_colon + 1; i < target_name.size(); ++i) {
    if (!IsAsciiDigit(target_name[i])) {
      return "";
    }
  }
  absl::string_view host = target_name.substr(0, first_colon);
  if (host.find('%') != absl::string_view::npos) {
    return "";
  }
  return std::string(host);
}

CFArrayRef ParsePemCertificateChain(absl::string_view pem_chain,
                                    grpc::Status* out_status) {
  @autoreleasepool {
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

    bool in_cert = false;
    std::string base64_body;

    size_t cursor = 0;
    while (cursor <= pem_chain.size()) {
      size_t newline = pem_chain.find('\n', cursor);
      absl::string_view line;
      if (newline == absl::string_view::npos) {
        line = pem_chain.substr(cursor);
        cursor = pem_chain.size() + 1;
      } else {
        line = pem_chain.substr(cursor, newline - cursor);
        cursor = newline + 1;
      }

      if (!line.empty() && line.back() == '\r') {
        line.remove_suffix(1);
      }
      absl::string_view trimmed = StripTrailingHorizontalWhitespace(line);

      if (trimmed == kPemBeginCert) {
        if (in_cert) {
          SetStatus(out_status,
                    grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                                 "Nested or unclosed PEM CERTIFICATE block"));
          return nullptr;
        }
        in_cert = true;
        base64_body.clear();
        continue;
      }

      if (trimmed == kPemEndCert) {
        if (!in_cert) {
          SetStatus(
              out_status,
              grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                           "Stray PEM END CERTIFICATE marker in peer chain"));
          return nullptr;
        }

        if (!IsStrictStandardBase64(base64_body)) {
          SetStatus(
              out_status,
              grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                           "Invalid base64 payload in PEM CERTIFICATE block"));
          return nullptr;
        }

        NSString* ns_base64 = util::MakeNSString(base64_body);
        NSData* der_data = [[NSData alloc] initWithBase64EncodedString:ns_base64
                                                               options:0];
        if (der_data == nil || der_data.length == 0) {
          SetStatus(
              out_status,
              grpc::Status(
                  grpc::StatusCode::UNAUTHENTICATED,
                  "Failed to base64-decode PEM CERTIFICATE block payload"));
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

        in_cert = false;
        base64_body.clear();
        continue;
      }

      if (in_cert) {
        for (char c : line) {
          if (c != ' ' && c != '\t' && c != '\r') {
            base64_body.push_back(c);
          }
        }
      } else if (!trimmed.empty()) {
        SetStatus(out_status,
                  grpc::Status(
                      grpc::StatusCode::UNAUTHENTICATED,
                      "Unexpected non-whitespace text outside PEM CERTIFICATE "
                      "block in peer chain"));
        return nullptr;
      }
    }

    if (in_cert) {
      SetStatus(out_status,
                grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                             "Unclosed PEM CERTIFICATE block in peer chain"));
      return nullptr;
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

grpc::Status VerifyAppleTlsCertificateChain(absl::string_view pem_chain,
                                            absl::string_view target_name,
                                            CFArrayRef anchor_certs) {
  @autoreleasepool {
    std::string host = ExtractTlsHostName(target_name);
    if (host.empty()) {
      return grpc::Status(
          grpc::StatusCode::UNAUTHENTICATED,
          absl::StrCat("Invalid or empty TLS target host name: '", target_name,
                       "'"));
    }

    grpc::Status parse_status;
    CFArrayRef certs = ParsePemCertificateChain(pem_chain, &parse_status);
    util::Defer release_certs([&] { util::SafeCFRelease(certs); });
    if (certs == nullptr) {
      return parse_status;
    }

    CFStringRef cf_host = util::MakeCFString(host);
    util::Defer release_host([&] { util::SafeCFRelease(cf_host); });
    if (cf_host == nullptr) {
      return grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                          "Failed to convert TLS target host name to CFString");
    }

    SecPolicyRef policy = SecPolicyCreateSSL(/*server=*/true, cf_host);
    util::Defer release_policy([&] { util::SafeCFRelease(policy); });
    if (policy == nullptr) {
      return grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                          "Failed to create Apple SSL SecPolicy");
    }

    SecTrustRef trust = nullptr;
    OSStatus trust_status =
        SecTrustCreateWithCertificates(certs, policy, &trust);
    util::Defer release_trust([&] { util::SafeCFRelease(trust); });
    if (trust_status != errSecSuccess || trust == nullptr) {
      return grpc::Status(
          grpc::StatusCode::UNAUTHENTICATED,
          absl::StrCat("SecTrustCreateWithCertificates failed with OSStatus ",
                       trust_status));
    }

    if (anchor_certs != nullptr) {
      OSStatus anchor_status =
          SecTrustSetAnchorCertificates(trust, anchor_certs);
      if (anchor_status != errSecSuccess) {
        return grpc::Status(
            grpc::StatusCode::UNAUTHENTICATED,
            absl::StrCat("SecTrustSetAnchorCertificates failed with OSStatus ",
                         anchor_status));
      }
      OSStatus anchor_only_status =
          SecTrustSetAnchorCertificatesOnly(trust, true);
      if (anchor_only_status != errSecSuccess) {
        return grpc::Status(
            grpc::StatusCode::UNAUTHENTICATED,
            absl::StrCat(
                "SecTrustSetAnchorCertificatesOnly failed with OSStatus ",
                anchor_only_status));
      }
    }

    CFErrorRef cf_error = nullptr;
    bool trusted = SecTrustEvaluateWithError(trust, &cf_error);
    util::Defer release_error([&] { util::SafeCFRelease(cf_error); });
    if (trusted) {
      return grpc::Status::OK;
    }

    std::string error_detail = "unknown SecTrust evaluation error";
    if (cf_error != nullptr) {
      CFStringRef desc = CFErrorCopyDescription(cf_error);
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

  // Disable gRPC's per-call BoringSSL hostname check for two reasons, and note
  // the upstream deprecation status:
  //
  // 1. Why it is disabled: `SecPolicyCreateSSL(/*server=*/true, cf_host)`
  //    already performs full RFC 6125 / Apple X.509 hostname and IP Subject
  //    Alternative Name verification inside `Verify()`, making BoringSSL's
  //    default per-RPC host check redundant. gRPC's own documentation on
  //    `set_check_call_host` also specifies that it should be disabled when a
  //    custom verifier other than `HostNameCertificateVerifier` is used.
  //
  // 2. Deprecation uncertainty: gRPC's doc comment in
  //    `grpcpp/security/tls_credentials_options.h` states: "Deprecated: This
  //    function will be removed in the 1.66 release. This will be replaced by
  //    and handled within the custom verifier settings." However,
  //    `set_check_call_host` has no `[[deprecated]]` C++ attribute and remains
  //    present and active across `gRPC` `1.69.0` through `1.84.1+` with no
  //    replacement custom-verifier option shipped yet. If a future gRPC release
  //    removes or replaces `set_check_call_host`, revisit this call.
  options.set_check_call_host(false);

  options.set_certificate_verifier(
      anchor_certs == nullptr
          ? GetDefaultAppleCertificateVerifier()
          : grpc::experimental::ExternalCertificateVerifier::Create<
                AppleSecTrustCertificateVerifier>(anchor_certs));

  return grpc::experimental::TlsCredentials(options);
}

std::shared_ptr<grpc::ChannelCredentials> CreateDefaultTlsCredentials() {
  return CreateAppleTlsCredentials(/*anchor_certs=*/nullptr);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(__APPLE__)
