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

#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>

#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <ctime>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "Firestore/core/src/remote/grpc_tls_credentials_provider.h"
#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/src/util/warnings.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/str_replace.h"
#include "gtest/gtest.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/channel.h"
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/async_generic_service.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/security/credentials.h"
#include "grpcpp/security/server_credentials.h"
#include "grpcpp/server.h"
#include "grpcpp/server_builder.h"
#include "grpcpp/support/byte_buffer.h"
#include "grpcpp/support/channel_arguments.h"
#include "grpcpp/support/slice.h"
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using ByteVec = std::vector<uint8_t>;

// RAII wrapper for CoreFoundation / Security.framework references.
template <typename T>
class ScopedCFRef {
 public:
  ScopedCFRef() = default;
  explicit ScopedCFRef(T ref) : ref_(ref) {
  }
  ~ScopedCFRef() {
    Reset();
  }

  ScopedCFRef(const ScopedCFRef& other) : ref_(other.ref_) {
    if (ref_ != nullptr) {
      CFRetain(ref_);
    }
  }

  ScopedCFRef& operator=(const ScopedCFRef& other) {
    if (this != &other) {
      Reset();
      ref_ = other.ref_;
      if (ref_ != nullptr) {
        CFRetain(ref_);
      }
    }
    return *this;
  }

  ScopedCFRef(ScopedCFRef&& other) noexcept : ref_(other.ref_) {
    other.ref_ = nullptr;
  }

  ScopedCFRef& operator=(ScopedCFRef&& other) noexcept {
    if (this != &other) {
      Reset();
      ref_ = other.ref_;
      other.ref_ = nullptr;
    }
    return *this;
  }

  void Reset(T new_ref = nullptr) {
    if (ref_ != nullptr) {
      CFRelease(ref_);
    }
    ref_ = new_ref;
  }

  T get() const {
    return ref_;
  }

  explicit operator bool() const {
    return ref_ != nullptr;
  }

 private:
  T ref_ = nullptr;
};

// ---------------------------------------------------------------------------
// Minimal deterministic ASN.1 DER + X.509v3 + PKCS#8 P-256 generator
// ---------------------------------------------------------------------------

void AppendBytes(ByteVec* out, const ByteVec& bytes) {
  out->insert(out->end(), bytes.begin(), bytes.end());
}

void AppendDerLength(ByteVec* out, size_t len) {
  if (len < 0x80) {
    out->push_back(static_cast<uint8_t>(len));
  } else if (len <= 0xFF) {
    out->push_back(0x81);
    out->push_back(static_cast<uint8_t>(len));
  } else if (len <= 0xFFFF) {
    out->push_back(0x82);
    out->push_back(static_cast<uint8_t>((len >> 8) & 0xFF));
    out->push_back(static_cast<uint8_t>(len & 0xFF));
  } else {
    HARD_ASSERT(len <= 0xFFFFFF, "ASN.1 element exceeds 16 MiB");
    out->push_back(0x83);
    out->push_back(static_cast<uint8_t>((len >> 16) & 0xFF));
    out->push_back(static_cast<uint8_t>((len >> 8) & 0xFF));
    out->push_back(static_cast<uint8_t>(len & 0xFF));
  }
}

ByteVec DerTlv(uint8_t tag, const ByteVec& content) {
  ByteVec out;
  out.reserve(1 + 4 + content.size());
  out.push_back(tag);
  AppendDerLength(&out, content.size());
  AppendBytes(&out, content);
  return out;
}

ByteVec DerSequence(const ByteVec& content) {
  return DerTlv(0x30, content);
}

ByteVec DerSet(const ByteVec& content) {
  return DerTlv(0x31, content);
}

ByteVec DerOctetString(const ByteVec& content) {
  return DerTlv(0x04, content);
}

ByteVec DerOid(std::initializer_list<uint8_t> oid_bytes) {
  return DerTlv(0x06, ByteVec(oid_bytes));
}

ByteVec DerUtf8String(absl::string_view text) {
  return DerTlv(0x0C, ByteVec(reinterpret_cast<const uint8_t*>(text.data()),
                              reinterpret_cast<const uint8_t*>(text.data()) +
                                  text.size()));
}

ByteVec DerBitString(uint8_t unused_bits, const ByteVec& bits) {
  ByteVec content;
  content.reserve(1 + bits.size());
  content.push_back(unused_bits);
  AppendBytes(&content, bits);
  return DerTlv(0x03, content);
}

ByteVec DerUint64(uint64_t value) {
  ByteVec raw;
  for (int shift = 56; shift >= 0; shift -= 8) {
    uint8_t byte = static_cast<uint8_t>((value >> shift) & 0xFF);
    if (!raw.empty() || byte != 0 || shift == 0) {
      raw.push_back(byte);
    }
  }
  if ((raw.front() & 0x80) != 0) {
    raw.insert(raw.begin(), 0x00);
  }
  return DerTlv(0x02, raw);
}

ByteVec DerTime(std::chrono::system_clock::time_point tp) {
  std::time_t tt = std::chrono::system_clock::to_time_t(tp);
  struct tm utc_tm{};
  gmtime_r(&tt, &utc_tm);

  int year = utc_tm.tm_year + 1900;
  char buf[32] = {};
  if (year >= 1950 && year <= 2049) {
    std::snprintf(buf, sizeof(buf), "%02d%02d%02d%02d%02d%02dZ", year % 100,
                  utc_tm.tm_mon + 1, utc_tm.tm_mday, utc_tm.tm_hour,
                  utc_tm.tm_min, utc_tm.tm_sec);
    return DerTlv(0x17, ByteVec(buf, buf + 13));  // UTCTime
  }

  std::snprintf(buf, sizeof(buf), "%04d%02d%02d%02d%02d%02dZ", year,
                utc_tm.tm_mon + 1, utc_tm.tm_mday, utc_tm.tm_hour,
                utc_tm.tm_min, utc_tm.tm_sec);
  return DerTlv(0x18, ByteVec(buf, buf + 15));  // GeneralizedTime
}

ByteVec DerCommonNameRdnSequence(absl::string_view common_name) {
  // Name ::= SEQUENCE { RelativeDistinguishedName (SET { AttributeTypeAndValue
  // }) }
  // id-at-commonName = 2.5.4.3 -> {0x55, 0x04, 0x03}
  ByteVec atv;
  AppendBytes(&atv, DerOid({0x55, 0x04, 0x03}));
  AppendBytes(&atv, DerUtf8String(common_name));
  return DerSequence(DerSet(DerSequence(atv)));
}

ByteVec DerExtension(std::initializer_list<uint8_t> oid_bytes,
                     bool critical,
                     const ByteVec& extn_value_der) {
  ByteVec ext;
  AppendBytes(&ext, DerOid(oid_bytes));
  if (critical) {
    // Canonical DER BOOLEAN TRUE = 01 01 FF. (FALSE is DEFAULT and MUST be
    // omitted.)
    AppendBytes(&ext, ByteVec{0x01, 0x01, 0xFF});
  }
  AppendBytes(&ext, DerOctetString(extn_value_der));
  return DerSequence(ext);
}

ByteVec ComputeKeyIdentifier(const ByteVec& public_key_x963) {
  // RFC 7093 Method 1: leftmost 160 bits (20 bytes) of SHA-256 over the
  // SubjectPublicKey BIT STRING value.
  uint8_t digest[CC_SHA256_DIGEST_LENGTH] = {};
  CC_SHA256(public_key_x963.data(),
            static_cast<CC_LONG>(public_key_x963.size()), digest);
  return ByteVec(digest, digest + 20);
}

std::string PemEncode(absl::string_view label, const ByteVec& der) {
  NSData* data = [NSData dataWithBytes:der.data() length:der.size()];
  NSString* b64 = [data
      base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength |
                                     NSDataBase64EncodingEndLineWithLineFeed];
  std::string body = util::MakeString(b64);
  while (!body.empty() && (body.back() == '\n' || body.back() == '\r')) {
    body.pop_back();
  }
  return absl::StrCat("-----BEGIN ", label, "-----\n", body, "\n-----END ",
                      label, "-----\n");
}

ByteVec CopyCFDataBytes(CFDataRef data) {
  HARD_ASSERT(data != nullptr, "Expected non-null CFDataRef");
  const uint8_t* ptr = CFDataGetBytePtr(data);
  CFIndex len = CFDataGetLength(data);
  return ByteVec(ptr, ptr + len);
}

// Encodes a 97-byte Apple P-256 ANSI X9.63 private key (`04 || X || Y || D`)
// as standard RFC 5208 PKCS#8 `PrivateKeyInfo` wrapping RFC 5915
// `ECPrivateKey` so BoringSSL (`grpc::SslServerCredentials`) loads it
// natively.
std::string EncodePkcs8EcPrivateKeyPem(const ByteVec& x963_private_key) {
  HARD_ASSERT(x963_private_key.size() == 97 && x963_private_key[0] == 0x04,
              "Expected 97-byte uncompressed P-256 key representation");

  ByteVec pub_point(x963_private_key.begin(), x963_private_key.begin() + 65);
  ByteVec scalar_d(x963_private_key.begin() + 65, x963_private_key.end());

  // ECPrivateKey ::= SEQUENCE {
  //   version        INTEGER (1),
  //   privateKey     OCTET STRING (32-byte scalar D),
  //   publicKey  [1] EXPLICIT BIT STRING (0x00 || 65-byte point)
  // }
  ByteVec ec_priv_body;
  AppendBytes(&ec_priv_body, DerUint64(1));
  AppendBytes(&ec_priv_body, DerOctetString(scalar_d));
  AppendBytes(&ec_priv_body, DerTlv(0xA1, DerBitString(0x00, pub_point)));
  ByteVec ec_priv_der = DerSequence(ec_priv_body);

  // PrivateKeyAlgorithmIdentifier ::= SEQUENCE {
  //   id-ecPublicKey (1.2.840.10045.2.1),
  //   prime256v1     (1.2.840.10045.3.1.7)
  // }
  ByteVec alg_id_body;
  AppendBytes(&alg_id_body, DerOid({0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01}));
  AppendBytes(&alg_id_body,
              DerOid({0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07}));

  // PrivateKeyInfo ::= SEQUENCE {
  //   version               INTEGER (0),
  //   privateKeyAlgorithm   AlgorithmIdentifier,
  //   privateKey            OCTET STRING (ECPrivateKey DER)
  // }
  ByteVec pkcs8_body;
  AppendBytes(&pkcs8_body, DerUint64(0));
  AppendBytes(&pkcs8_body, DerSequence(alg_id_body));
  AppendBytes(&pkcs8_body, DerOctetString(ec_priv_der));

  return PemEncode("PRIVATE KEY", DerSequence(pkcs8_body));
}

struct CertOptions {
  std::string common_name;
  bool is_ca = false;
  std::chrono::seconds not_before_offset = std::chrono::hours(-1);
  std::chrono::seconds not_after_offset = std::chrono::hours(24);
  std::vector<std::string> dns_sans;
  std::vector<std::array<uint8_t, 4>> ipv4_sans;
  std::vector<std::array<uint8_t, 16>> ipv6_sans;
};

struct GeneratedCertificate {
  ScopedCFRef<SecKeyRef> private_key;
  ScopedCFRef<SecCertificateRef> sec_certificate;
  std::string private_key_pem;
  ByteVec cert_der;
  std::string cert_pem;
  ByteVec subject_der;
  ByteVec ski_bytes;
};

GeneratedCertificate GenerateCertificate(const CertOptions& options,
                                         const GeneratedCertificate* issuer) {
  static std::atomic<uint64_t> next_serial{0x1000};

  NSDictionary* key_attrs = @{
    (__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
    (__bridge id)kSecAttrKeySizeInBits : @256,
  };
  CFErrorRef raw_error = nullptr;
  ScopedCFRef<SecKeyRef> priv_key(
      SecKeyCreateRandomKey((__bridge CFDictionaryRef)key_attrs, &raw_error));
  ScopedCFRef<CFErrorRef> key_error(raw_error);
  HARD_ASSERT(priv_key.get() != nullptr, "SecKeyCreateRandomKey failed");

  ScopedCFRef<SecKeyRef> pub_key(SecKeyCopyPublicKey(priv_key.get()));
  HARD_ASSERT(pub_key.get() != nullptr, "SecKeyCopyPublicKey failed");

  raw_error = nullptr;
  ScopedCFRef<CFDataRef> pub_ext(
      SecKeyCopyExternalRepresentation(pub_key.get(), &raw_error));
  ScopedCFRef<CFErrorRef> pub_error(raw_error);
  HARD_ASSERT(pub_ext.get() != nullptr,
              "SecKeyCopyExternalRepresentation(public) failed");
  ByteVec pub_x963 = CopyCFDataBytes(pub_ext.get());
  HARD_ASSERT(pub_x963.size() == 65 && pub_x963[0] == 0x04,
              "Unexpected P-256 public key representation");

  raw_error = nullptr;
  ScopedCFRef<CFDataRef> priv_ext(
      SecKeyCopyExternalRepresentation(priv_key.get(), &raw_error));
  ScopedCFRef<CFErrorRef> priv_error(raw_error);
  HARD_ASSERT(priv_ext.get() != nullptr,
              "SecKeyCopyExternalRepresentation(private) failed");
  ByteVec priv_x963 = CopyCFDataBytes(priv_ext.get());

  ByteVec subject_der = DerCommonNameRdnSequence(options.common_name);
  ByteVec ski_bytes = ComputeKeyIdentifier(pub_x963);
  const ByteVec& issuer_name_der =
      issuer != nullptr ? issuer->subject_der : subject_der;
  const ByteVec& aki_bytes = issuer != nullptr ? issuer->ski_bytes : ski_bytes;
  SecKeyRef signing_key =
      issuer != nullptr ? issuer->private_key.get() : priv_key.get();

  // Signature AlgorithmIdentifier: ecdsa-with-SHA256 (1.2.840.10045.4.3.2),
  // parameters MUST be omitted per RFC 5758 Section 3.2.
  ByteVec sig_alg_der =
      DerSequence(DerOid({0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02}));

  // SubjectPublicKeyInfo for P-256.
  ByteVec spki_alg_body;
  AppendBytes(&spki_alg_body,
              DerOid({0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01}));
  AppendBytes(&spki_alg_body,
              DerOid({0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07}));
  ByteVec spki_body;
  AppendBytes(&spki_body, DerSequence(spki_alg_body));
  AppendBytes(&spki_body, DerBitString(0x00, pub_x963));
  ByteVec spki_der = DerSequence(spki_body);

  // Validity.
  auto now = std::chrono::system_clock::now();
  ByteVec validity_body;
  AppendBytes(&validity_body, DerTime(now + options.not_before_offset));
  AppendBytes(&validity_body, DerTime(now + options.not_after_offset));
  ByteVec validity_der = DerSequence(validity_body);

  // X.509v3 Extensions.
  ByteVec extensions_body;
  if (options.is_ca) {
    // BasicConstraints (2.5.29.19, critical): SEQUENCE { cA BOOLEAN TRUE }
    AppendBytes(&extensions_body,
                DerExtension({0x55, 0x1D, 0x13}, /*critical=*/true,
                             DerSequence(ByteVec{0x01, 0x01, 0xFF})));
    // KeyUsage (2.5.29.15, critical): keyCertSign (bit 5) | cRLSign (bit 6)
    // -> 0000_0110 = 0x06 with 1 unused trailing bit.
    AppendBytes(&extensions_body,
                DerExtension({0x55, 0x1D, 0x0F}, /*critical=*/true,
                             DerBitString(0x01, ByteVec{0x06})));
  } else {
    // BasicConstraints (2.5.29.19, critical): SEQUENCE {} (cA DEFAULT FALSE)
    AppendBytes(&extensions_body,
                DerExtension({0x55, 0x1D, 0x13}, /*critical=*/true,
                             DerSequence(ByteVec{})));
    // KeyUsage (2.5.29.15, critical): digitalSignature (bit 0)
    // -> 1000_0000 = 0x80 with 7 unused trailing bits.
    AppendBytes(&extensions_body,
                DerExtension({0x55, 0x1D, 0x0F}, /*critical=*/true,
                             DerBitString(0x07, ByteVec{0x80})));
    // ExtendedKeyUsage (2.5.29.37): id-kp-serverAuth (1.3.6.1.5.5.7.3.1)
    AppendBytes(&extensions_body,
                DerExtension({0x55, 0x1D, 0x25}, /*critical=*/false,
                             DerSequence(DerOid({0x2B, 0x06, 0x01, 0x05, 0x05,
                                                 0x07, 0x03, 0x01}))));
  }

  // SubjectKeyIdentifier (2.5.29.14): KeyIdentifier ::= OCTET STRING
  AppendBytes(&extensions_body,
              DerExtension({0x55, 0x1D, 0x0E}, /*critical=*/false,
                           DerOctetString(ski_bytes)));

  // AuthorityKeyIdentifier (2.5.29.35): SEQUENCE { [0] IMPLICIT KeyIdentifier }
  AppendBytes(&extensions_body,
              DerExtension({0x55, 0x1D, 0x23}, /*critical=*/false,
                           DerSequence(DerTlv(0x80, aki_bytes))));

  // SubjectAltName (2.5.29.17)
  if (!options.dns_sans.empty() || !options.ipv4_sans.empty() ||
      !options.ipv6_sans.empty()) {
    ByteVec general_names;
    for (const std::string& dns : options.dns_sans) {
      // dNSName [2] IMPLICIT IA5String
      ByteVec dns_bytes(dns.begin(), dns.end());
      AppendBytes(&general_names, DerTlv(0x82, dns_bytes));
    }
    for (const auto& ipv4 : options.ipv4_sans) {
      // iPAddress [7] IMPLICIT OCTET STRING (4 bytes for IPv4)
      AppendBytes(&general_names,
                  DerTlv(0x87, ByteVec(ipv4.begin(), ipv4.end())));
    }
    for (const auto& ipv6 : options.ipv6_sans) {
      // iPAddress [7] IMPLICIT OCTET STRING (16 bytes for IPv6)
      AppendBytes(&general_names,
                  DerTlv(0x87, ByteVec(ipv6.begin(), ipv6.end())));
    }
    AppendBytes(&extensions_body,
                DerExtension({0x55, 0x1D, 0x11}, /*critical=*/false,
                             DerSequence(general_names)));
  }

  // TBSCertificate ::= SEQUENCE {
  //   version         [0] EXPLICIT INTEGER (2 = v3),
  //   serialNumber        INTEGER,
  //   signature           AlgorithmIdentifier,
  //   issuer              Name,
  //   validity            Validity,
  //   subject             Name,
  //   subjectPublicKeyInfo SubjectPublicKeyInfo,
  //   extensions      [3] EXPLICIT Extensions
  // }
  uint64_t serial = next_serial.fetch_add(1, std::memory_order_relaxed);
  ByteVec tbs_body;
  AppendBytes(&tbs_body, DerTlv(0xA0, DerUint64(2)));
  AppendBytes(&tbs_body, DerUint64(serial));
  AppendBytes(&tbs_body, sig_alg_der);
  AppendBytes(&tbs_body, issuer_name_der);
  AppendBytes(&tbs_body, validity_der);
  AppendBytes(&tbs_body, subject_der);
  AppendBytes(&tbs_body, spki_der);
  AppendBytes(&tbs_body, DerTlv(0xA3, DerSequence(extensions_body)));
  ByteVec tbs_der = DerSequence(tbs_body);

  // Sign TBSCertificate with issuer's P-256 key (ECDSA-SHA256 X9.62 DER).
  ScopedCFRef<CFDataRef> tbs_cf_data(
      CFDataCreate(kCFAllocatorDefault, tbs_der.data(),
                   static_cast<CFIndex>(tbs_der.size())));
  raw_error = nullptr;
  ScopedCFRef<CFDataRef> sig_cf_data(SecKeyCreateSignature(
      signing_key, kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
      tbs_cf_data.get(), &raw_error));
  ScopedCFRef<CFErrorRef> sig_error(raw_error);
  HARD_ASSERT(sig_cf_data.get() != nullptr, "SecKeyCreateSignature failed");
  ByteVec sig_der = CopyCFDataBytes(sig_cf_data.get());

  // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm,
  // signatureValue }
  ByteVec cert_body;
  AppendBytes(&cert_body, tbs_der);
  AppendBytes(&cert_body, sig_alg_der);
  AppendBytes(&cert_body, DerBitString(0x00, sig_der));
  ByteVec cert_der = DerSequence(cert_body);

  ScopedCFRef<CFDataRef> cert_cf_data(
      CFDataCreate(kCFAllocatorDefault, cert_der.data(),
                   static_cast<CFIndex>(cert_der.size())));
  ScopedCFRef<SecCertificateRef> sec_cert(
      SecCertificateCreateWithData(kCFAllocatorDefault, cert_cf_data.get()));
  HARD_ASSERT(sec_cert.get() != nullptr,
              "Generated X.509 DER rejected by SecCertificateCreateWithData");

  GeneratedCertificate result;
  result.private_key = std::move(priv_key);
  result.sec_certificate = std::move(sec_cert);
  result.private_key_pem = EncodePkcs8EcPrivateKeyPem(priv_x963);
  result.cert_pem = PemEncode("CERTIFICATE", cert_der);
  result.cert_der = std::move(cert_der);
  result.subject_der = std::move(subject_der);
  result.ski_bytes = std::move(ski_bytes);
  return result;
}

struct ThreeTierPki {
  GeneratedCertificate root;
  GeneratedCertificate intermediate;
  GeneratedCertificate leaf;

  std::string ServerChainPem() const {
    return absl::StrCat(leaf.cert_pem, intermediate.cert_pem);
  }

  ScopedCFRef<CFArrayRef> RootAnchorArray() const {
    const void* values[] = {root.sec_certificate.get()};
    return ScopedCFRef<CFArrayRef>(
        CFArrayCreate(kCFAllocatorDefault, values, 1, &kCFTypeArrayCallBacks));
  }
};

ThreeTierPki BuildThreeTierPki(const CertOptions& leaf_options,
                               absl::string_view pki_label = "Primary") {
  CertOptions root_opts;
  root_opts.common_name = absl::StrCat("Firestore Test Root CA ", pki_label);
  root_opts.is_ca = true;
  root_opts.not_before_offset = std::chrono::hours(-2);
  root_opts.not_after_offset = std::chrono::hours(48);
  GeneratedCertificate root =
      GenerateCertificate(root_opts, /*issuer=*/nullptr);

  CertOptions inter_opts;
  inter_opts.common_name =
      absl::StrCat("Firestore Test Intermediate CA ", pki_label);
  inter_opts.is_ca = true;
  inter_opts.not_before_offset = std::chrono::hours(-2);
  inter_opts.not_after_offset = std::chrono::hours(48);
  GeneratedCertificate intermediate = GenerateCertificate(inter_opts, &root);

  GeneratedCertificate leaf = GenerateCertificate(leaf_options, &intermediate);
  return ThreeTierPki{std::move(root), std::move(intermediate),
                      std::move(leaf)};
}

ByteVec CopySecCertificateDer(SecCertificateRef cert) {
  ScopedCFRef<CFDataRef> data(SecCertificateCopyData(cert));
  return CopyCFDataBytes(data.get());
}

// ---------------------------------------------------------------------------
// In-process gRPC TLS loopback server & unary echo client helpers
// ---------------------------------------------------------------------------

// Ephemeral localhost gRPC TLS server backed by `grpc::AsyncGenericService`
// (compatible across both CMake gRPC 1.69.0 and CocoaPods/SPM gRPC 1.83.1+).
class TlsLoopbackServer {
 public:
  TlsLoopbackServer(const std::string& server_private_key_pem,
                    const std::string& server_cert_chain_pem) {
    grpc::SslServerCredentialsOptions ssl_options;
    ssl_options.pem_key_cert_pairs.push_back(
        {server_private_key_pem, server_cert_chain_pem});

    grpc::ServerBuilder builder;
    builder.AddListeningPort("127.0.0.1:0",
                             grpc::SslServerCredentials(ssl_options), &port_);
    builder.RegisterAsyncGenericService(&generic_service_);
    cq_ = builder.AddCompletionQueue();
    server_ = builder.BuildAndStart();

    if (server_ != nullptr && port_ > 0) {
      server_thread_ = std::thread([this] { ServeLoop(); });
    }
  }

  ~TlsLoopbackServer() {
    if (server_ != nullptr) {
      server_->Shutdown(std::chrono::system_clock::now());
    }
    {
      std::lock_guard<std::mutex> lock(mu_);
      shutting_down_ = true;
      if (cq_ != nullptr) {
        cq_->Shutdown();
      }
    }
    if (server_thread_.joinable()) {
      server_thread_.join();
    }
  }

  TlsLoopbackServer(const TlsLoopbackServer&) = delete;
  TlsLoopbackServer& operator=(const TlsLoopbackServer&) = delete;

  bool started() const {
    return server_ != nullptr && port_ > 0;
  }

  int port() const {
    return port_;
  }

  std::string target() const {
    return absl::StrCat("127.0.0.1:", port_);
  }

 private:
  enum class Step { kRequest, kRead, kWriteAndFinish };

  struct CallState {
    grpc::GenericServerContext ctx;
    grpc::GenericServerAsyncReaderWriter stream{&ctx};
    grpc::ByteBuffer request;
    Step step = Step::kRequest;
  };

  void SpawnCall() {
    std::lock_guard<std::mutex> lock(mu_);
    if (shutting_down_) {
      return;
    }
    auto* state = new CallState();
    generic_service_.RequestCall(&state->ctx, &state->stream, cq_.get(),
                                 cq_.get(), state);
  }

  void ServeLoop() {
    SpawnCall();

    void* tag = nullptr;
    bool ok = false;
    while (cq_->Next(&tag, &ok)) {
      auto* state = static_cast<CallState*>(tag);
      if (!ok) {
        delete state;
        continue;
      }

      switch (state->step) {
        case Step::kRequest: {
          SpawnCall();
          std::lock_guard<std::mutex> lock(mu_);
          if (shutting_down_) {
            delete state;
            break;
          }
          state->step = Step::kRead;
          state->stream.Read(&state->request, state);
          break;
        }
        case Step::kRead: {
          std::lock_guard<std::mutex> lock(mu_);
          if (shutting_down_) {
            delete state;
            break;
          }
          state->step = Step::kWriteAndFinish;
          state->stream.WriteAndFinish(state->request, grpc::WriteOptions{},
                                       grpc::Status::OK, state);
          break;
        }
        case Step::kWriteAndFinish:
          delete state;
          break;
      }
    }
  }

  int port_ = 0;
  grpc::AsyncGenericService generic_service_;
  std::unique_ptr<grpc::ServerCompletionQueue> cq_;
  std::unique_ptr<grpc::Server> server_;
  std::mutex mu_;
  bool shutting_down_ = false;
  std::thread server_thread_;
};

std::string ReadByteBuffer(const grpc::ByteBuffer& buffer) {
  std::vector<grpc::Slice> slices;
  grpc::Status dump_status = buffer.Dump(&slices);
  HARD_ASSERT(dump_status.ok(), "ByteBuffer::Dump failed");
  std::string out;
  for (const grpc::Slice& slice : slices) {
    out.append(reinterpret_cast<const char*>(slice.begin()), slice.size());
  }
  return out;
}

grpc::Status PerformUnaryEcho(const std::shared_ptr<grpc::Channel>& channel,
                              const std::string& payload,
                              std::string* out_response = nullptr) {
  grpc::GenericStub stub(channel);
  grpc::ClientContext context;
  context.set_deadline(std::chrono::system_clock::now() +
                       std::chrono::seconds(5));
  context.set_wait_for_ready(false);

  grpc::Slice req_slice(payload);
  grpc::ByteBuffer request(&req_slice, 1);
  grpc::ByteBuffer response;
  grpc::Status status;

  grpc::CompletionQueue cq;
  std::unique_ptr<grpc::GenericClientAsyncResponseReader> call =
      stub.PrepareUnaryCall(&context, "/firestore.TlsLoopbackTest/Echo",
                            request, &cq);
  HARD_ASSERT(call != nullptr, "PrepareUnaryCall returned null");
  call->StartCall();

  void* finish_tag = reinterpret_cast<void*>(1);
  call->Finish(&response, &status, finish_tag);

  void* got_tag = nullptr;
  bool ok = false;
  HARD_ASSERT(cq.Next(&got_tag, &ok) && got_tag == finish_tag,
              "Expected unary RPC finish tag from CompletionQueue");
  cq.Shutdown();
  while (cq.Next(&got_tag, &ok)) {
  }

  if (status.ok() && out_response != nullptr) {
    *out_response = ReadByteBuffer(response);
  }
  return status;
}

// ===========================================================================
// 1. ExtractTlsHostName Unit Tests (tested through
// VerifyAppleTlsCertificateChain)
// ===========================================================================

TEST(GrpcTlsCredentialsProviderAppleTest, ExtractTlsHostNameDnsAndIpv4) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "firestore.googleapis.com";
  leaf_opts.dns_sans = {"firestore.googleapis.com"};
  leaf_opts.ipv4_sans = {{127, 0, 0, 1}};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  for (const auto& target :
       {"firestore.googleapis.com", "firestore.googleapis.com:443", "127.0.0.1",
        "127.0.0.1:50051"}) {
    grpc::Status status = VerifyAppleTlsCertificateChain(pki.ServerChainPem(),
                                                         target, anchors.get());
    EXPECT_TRUE(status.ok())
        << "target: " << target << " error: " << status.error_message();
  }
}

TEST(GrpcTlsCredentialsProviderAppleTest, ExtractTlsHostNameIpv6) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "ipv6.firestore.local";
  leaf_opts.ipv6_sans = {
      {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
      {0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
      {0xfe, 0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
      {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff, 127, 0, 0, 1}};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  for (const auto& target : {"[::1]:443", "[2001:db8::1]", "[2001:db8::1]:8443",
                             "[::ffff:7f00:1]:443", "[fe80::1%en0]:443",
                             "fe80::1%en0", "::1", "2001:db8::1"}) {
    grpc::Status status = VerifyAppleTlsCertificateChain(pki.ServerChainPem(),
                                                         target, anchors.get());
    EXPECT_TRUE(status.ok())
        << "target: " << target << " error: " << status.error_message();
  }
}

TEST(GrpcTlsCredentialsProviderAppleTest, ExtractTlsHostNameEmptyAndMalformed) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "firestore.googleapis.com";
  leaf_opts.dns_sans = {"firestore.googleapis.com"};
  leaf_opts.ipv4_sans = {{127, 0, 0, 1}};
  leaf_opts.ipv6_sans = {
      {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
      {0xfe, 0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1}};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  const std::string embedded_nul_target(
      "firestore.googleapis.com\0evil",
      sizeof("firestore.googleapis.com\0evil") - 1);
  const std::vector<std::string> malformed_targets = {
      "",
      ":443",
      "firestore.googleapis.com:",
      "firestore.googleapis.com:notaport",
      "https://firestore.googleapis.com",
      "https://firestore.googleapis.com:443",
      "unix:/tmp/grpc.sock",
      "dns:///firestore.googleapis.com",
      "dns://8.8.8.8",
      "dns:",
      "ipv4:",
      "ipv6:",
      "foo:bar:baz",
      "[example.com]:443",
      "[::1",
      "[]",
      "[::1]:",
      "[::1]:notaport",
      "[fe80::1%]:443",
      "fe80::1%",
      "[::1]junk",
      "firestore.googleapis.com\n",
      embedded_nul_target};

  for (const auto& target : malformed_targets) {
    grpc::Status status = VerifyAppleTlsCertificateChain(pki.ServerChainPem(),
                                                         target, anchors.get());
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << "target: " << target;
  }
}

// ===========================================================================
// 2. ParsePemCertificateChain Unit Tests (tested through
// VerifyAppleTlsCertificateChain)
// ===========================================================================

TEST(GrpcTlsCredentialsProviderAppleTest,
     ParsePemCertificateChainSingleCertificate) {
  CertOptions opts;
  opts.common_name = "single.firestore.local";
  opts.dns_sans = {"single.firestore.local"};
  GeneratedCertificate cert = GenerateCertificate(opts, /*issuer=*/nullptr);

  const void* values[] = {cert.sec_certificate.get()};
  ScopedCFRef<CFArrayRef> anchor(
      CFArrayCreate(kCFAllocatorDefault, values, 1, &kCFTypeArrayCallBacks));

  grpc::Status status = VerifyAppleTlsCertificateChain(
      cert.cert_pem, "single.firestore.local", anchor.get());
  EXPECT_TRUE(status.ok()) << status.error_message();
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     ParsePemCertificateChainMultiCertPreservesExactOrder) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "leaf.firestore.local";
  leaf_opts.dns_sans = {"leaf.firestore.local"};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  std::string leaf_first_chain = absl::StrCat(
      pki.leaf.cert_pem, pki.intermediate.cert_pem, pki.root.cert_pem);
  grpc::Status ok_status = VerifyAppleTlsCertificateChain(
      leaf_first_chain, "leaf.firestore.local", anchors.get());
  EXPECT_TRUE(ok_status.ok()) << ok_status.error_message();

  std::string reversed_chain = absl::StrCat(
      pki.intermediate.cert_pem, pki.leaf.cert_pem, pki.root.cert_pem);
  grpc::Status bad_status = VerifyAppleTlsCertificateChain(
      reversed_chain, "leaf.firestore.local", anchors.get());
  EXPECT_EQ(bad_status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     ParsePemCertificateChainHandlesCrlfAndBlankWhitespaceLines) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "crlf.firestore.local";
  leaf_opts.dns_sans = {"crlf.firestore.local"};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  std::string crlf_leaf = absl::StrReplaceAll(
      pki.leaf.cert_pem,
      {{"-----BEGIN CERTIFICATE-----", "-----BEGIN CERTIFICATE-----   \t"},
       {"\n", "\r\n\r\n"}});
  std::string crlf_inter =
      absl::StrReplaceAll(pki.intermediate.cert_pem, {{"\n", "\r\n"}});

  std::string whitespace_padded_pem = absl::StrCat(
      "  \t\r\n\r\n", crlf_leaf, "   \t  \r\n\n", crlf_inter, "\r\n  \t \r\n");

  grpc::Status status = VerifyAppleTlsCertificateChain(
      whitespace_padded_pem, "crlf.firestore.local", anchors.get());
  EXPECT_TRUE(status.ok()) << status.error_message();
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     ParsePemCertificateChainFailsClosedOnEmptyOrNonPemInput) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "test.firestore.local";
  leaf_opts.dns_sans = {"test.firestore.local"};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  for (const auto& bad_input :
       {"", "   \t\r\n  \n ", "not a PEM block at all"}) {
    grpc::Status status = VerifyAppleTlsCertificateChain(
        bad_input, "test.firestore.local", anchors.get());
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  }
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     ParsePemCertificateChainFailsClosedOnUnclosedOrCorruptedBlocks) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "valid.firestore.local";
  leaf_opts.dns_sans = {"valid.firestore.local"};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  EXPECT_TRUE(VerifyAppleTlsCertificateChain(
                  pki.ServerChainPem(), "valid.firestore.local", anchors.get())
                  .ok());

  // Unclosed BEGIN CERTIFICATE block.
  {
    grpc::Status status =
        VerifyAppleTlsCertificateChain("-----BEGIN CERTIFICATE-----\nMIIB\n",
                                       "valid.firestore.local", anchors.get());
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  }

  // Malformed base64 inside PEM block.
  {
    grpc::Status status = VerifyAppleTlsCertificateChain(
        "-----BEGIN CERTIFICATE-----\n***not-valid-base64***\n"
        "-----END CERTIFICATE-----\n",
        "valid.firestore.local", anchors.get());
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  }

  // Valid base64 encoding non-DER garbage bytes.
  std::string garbage_pem = PemEncode(
      "CERTIFICATE", ByteVec{'n', 'o', 't', '-', 'x', '5', '0', '9', '-', 'd',
                             'e', 'r', '-', 'b', 'y', 't', 'e', 's'});
  {
    grpc::Status status = VerifyAppleTlsCertificateChain(
        garbage_pem, "valid.firestore.local", anchors.get());
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  }

  // Valid leaf followed by a trailing corrupted PEM block MUST fail closed
  // rather than silently returning only the first certificate.
  {
    std::string valid_then_corrupt = absl::StrCat(
        pki.ServerChainPem(), "-----BEGIN CERTIFICATE-----\n@@@corrupt@@@\n"
                              "-----END CERTIFICATE-----\n");
    grpc::Status status = VerifyAppleTlsCertificateChain(
        valid_then_corrupt, "valid.firestore.local", anchors.get());
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  }
  {
    std::string valid_then_garbage_der =
        absl::StrCat(pki.ServerChainPem(), garbage_pem);
    grpc::Status status = VerifyAppleTlsCertificateChain(
        valid_then_garbage_der, "valid.firestore.local", anchors.get());
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  }
  {
    std::string valid_then_unclosed =
        absl::StrCat(pki.ServerChainPem(), "-----BEGIN CERTIFICATE-----\nMIIB");
    grpc::Status status = VerifyAppleTlsCertificateChain(
        valid_then_unclosed, "valid.firestore.local", anchors.get());
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  }
  {
    std::string valid_then_truncated_header =
        absl::StrCat(pki.ServerChainPem(), "-----BEGIN CERTIFICAT\nMIIB\n");
    grpc::Status status = VerifyAppleTlsCertificateChain(
        valid_then_truncated_header, "valid.firestore.local", anchors.get());
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  }
  {
    std::string valid_then_trailing_junk =
        absl::StrCat(pki.ServerChainPem(), "unexpected trailing metadata\n");
    grpc::Status status = VerifyAppleTlsCertificateChain(
        valid_then_trailing_junk, "valid.firestore.local", anchors.get());
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  }
}

// ===========================================================================
// 3. VerifyAppleTlsCertificateChain Direct SecTrust Unit Tests
// ===========================================================================

TEST(GrpcTlsCredentialsProviderAppleTest,
     VerifyValidThreeTierChainWithMatchingDnsSan) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "test.firestore.local";
  leaf_opts.dns_sans = {"test.firestore.local"};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  grpc::Status status = VerifyAppleTlsCertificateChain(
      pki.ServerChainPem(), "test.firestore.local:443", anchors.get());
  EXPECT_TRUE(status.ok()) << status.error_message();
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     VerifyValidThreeTierChainWithMatchingIpv4San) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "ipv4-loopback.firestore.local";
  leaf_opts.ipv4_sans = {{127, 0, 0, 1}};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  grpc::Status status = VerifyAppleTlsCertificateChain(
      pki.ServerChainPem(), "127.0.0.1:443", anchors.get());
  EXPECT_TRUE(status.ok()) << status.error_message();
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     VerifyValidThreeTierChainWithMatchingIpv6San) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "ipv6-loopback.firestore.local";
  leaf_opts.ipv6_sans = {{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1}};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  EXPECT_TRUE(VerifyAppleTlsCertificateChain(pki.ServerChainPem(), "[::1]:443",
                                             anchors.get())
                  .ok());
  EXPECT_TRUE(
      VerifyAppleTlsCertificateChain(pki.ServerChainPem(), "::1", anchors.get())
          .ok());
  EXPECT_TRUE(VerifyAppleTlsCertificateChain(pki.ServerChainPem(),
                                             "[::1%en0]:443", anchors.get())
                  .ok());
}

TEST(GrpcTlsCredentialsProviderAppleTest, VerifyRejectsExpiredLeafCertificate) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "test.firestore.local";
  leaf_opts.dns_sans = {"test.firestore.local"};
  leaf_opts.not_before_offset = std::chrono::hours(-48);
  leaf_opts.not_after_offset = std::chrono::hours(-24);
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  grpc::Status status = VerifyAppleTlsCertificateChain(
      pki.ServerChainPem(), "test.firestore.local:443", anchors.get());
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     VerifyRejectsNotYetValidLeafCertificate) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "test.firestore.local";
  leaf_opts.dns_sans = {"test.firestore.local"};
  leaf_opts.not_before_offset = std::chrono::hours(24);
  leaf_opts.not_after_offset = std::chrono::hours(48);
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  grpc::Status status = VerifyAppleTlsCertificateChain(
      pki.ServerChainPem(), "test.firestore.local:443", anchors.get());
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST(GrpcTlsCredentialsProviderAppleTest, VerifyRejectsWrongTargetHostName) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "test.firestore.local";
  leaf_opts.dns_sans = {"test.firestore.local"};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  grpc::Status status = VerifyAppleTlsCertificateChain(
      pki.ServerChainPem(), "wrong.firestore.local", anchors.get());
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST(GrpcTlsCredentialsProviderAppleTest, VerifyRejectsUntrustedRoot) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "test.firestore.local";
  leaf_opts.dns_sans = {"test.firestore.local"};
  ThreeTierPki pki_a = BuildThreeTierPki(leaf_opts, "RootA");
  ThreeTierPki pki_b = BuildThreeTierPki(leaf_opts, "RootB");
  ScopedCFRef<CFArrayRef> root_a_anchors = pki_a.RootAnchorArray();

  // Chain signed by Root B evaluated against custom anchor Root A.
  grpc::Status custom_anchor_status = VerifyAppleTlsCertificateChain(
      pki_b.ServerChainPem(), "test.firestore.local:443", root_a_anchors.get());
  EXPECT_EQ(custom_anchor_status.error_code(),
            grpc::StatusCode::UNAUTHENTICATED);

  // Ephemeral chain signed by Root B evaluated against default Apple OS trust.
  grpc::Status os_trust_status = VerifyAppleTlsCertificateChain(
      pki_b.ServerChainPem(), "test.firestore.local:443",
      /*anchor_certs=*/nullptr);
  EXPECT_EQ(os_trust_status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     VerifyRejectsMissingOrUntrustedIntermediate) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "test.firestore.local";
  leaf_opts.dns_sans = {"test.firestore.local"};
  ThreeTierPki pki_a = BuildThreeTierPki(leaf_opts, "RootA");
  ThreeTierPki pki_b = BuildThreeTierPki(leaf_opts, "RootB");
  ScopedCFRef<CFArrayRef> root_a_anchors = pki_a.RootAnchorArray();
  ScopedCFRef<CFArrayRef> root_b_anchors = pki_b.RootAnchorArray();

  // Leaf signed by Intermediate B (omitted from PEM chain) against Root A.
  grpc::Status wrong_anchor_status = VerifyAppleTlsCertificateChain(
      pki_b.leaf.cert_pem, "test.firestore.local:443", root_a_anchors.get());
  EXPECT_EQ(wrong_anchor_status.error_code(),
            grpc::StatusCode::UNAUTHENTICATED);

  // Leaf signed by Intermediate B (omitted from PEM chain) against Root B.
  grpc::Status missing_inter_status = VerifyAppleTlsCertificateChain(
      pki_b.leaf.cert_pem, "test.firestore.local:443", root_b_anchors.get());
  EXPECT_EQ(missing_inter_status.error_code(),
            grpc::StatusCode::UNAUTHENTICATED);
}

TEST(GrpcTlsCredentialsProviderAppleTest, VerifyRejectsEmptyTargetName) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "test.firestore.local";
  leaf_opts.dns_sans = {"test.firestore.local"};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> anchors = pki.RootAnchorArray();

  grpc::Status status =
      VerifyAppleTlsCertificateChain(pki.ServerChainPem(), "", anchors.get());
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

// ===========================================================================
// 4. End-to-End In-Process gRPC Server TLS Loopback Tests
// ===========================================================================

TEST(GrpcTlsCredentialsProviderAppleTest,
     LoopbackGrpcServerSucceedsWithValidIpv4SanChain) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "ipv4-loopback.firestore.local";
  leaf_opts.ipv4_sans = {{127, 0, 0, 1}};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> root_anchors = pki.RootAnchorArray();

  TlsLoopbackServer server(pki.leaf.private_key_pem, pki.ServerChainPem());
  ASSERT_TRUE(server.started());

  std::shared_ptr<grpc::Channel> channel = grpc::CreateChannel(
      server.target(), CreateAppleTlsCredentials(root_anchors.get()));

  std::string echoed;
  grpc::Status status =
      PerformUnaryEcho(channel, "ping-ipv4-loopback", &echoed);
  EXPECT_EQ(status.error_code(), grpc::StatusCode::OK)
      << status.error_message();
  EXPECT_EQ(echoed, "ping-ipv4-loopback");
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     LoopbackGrpcServerSucceedsWithDnsSanAndSslTargetNameOverride) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "loopback.firestore.test";
  leaf_opts.dns_sans = {"loopback.firestore.test"};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> root_anchors = pki.RootAnchorArray();

  TlsLoopbackServer server(pki.leaf.private_key_pem, pki.ServerChainPem());
  ASSERT_TRUE(server.started());

  grpc::ChannelArguments args;
  args.SetSslTargetNameOverride("loopback.firestore.test");
  std::shared_ptr<grpc::Channel> channel = grpc::CreateCustomChannel(
      server.target(), CreateAppleTlsCredentials(root_anchors.get()), args);

  std::string echoed;
  grpc::Status status =
      PerformUnaryEcho(channel, "ping-dns-override-loopback", &echoed);
  EXPECT_EQ(status.error_code(), grpc::StatusCode::OK)
      << status.error_message();
  EXPECT_EQ(echoed, "ping-dns-override-loopback");
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     LoopbackGrpcServerRejectsUntrustedRoot) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "127.0.0.1";
  leaf_opts.ipv4_sans = {{127, 0, 0, 1}};
  ThreeTierPki pki_a = BuildThreeTierPki(leaf_opts, "RootA");
  ThreeTierPki pki_b = BuildThreeTierPki(leaf_opts, "RootB");
  ScopedCFRef<CFArrayRef> root_a_anchors = pki_a.RootAnchorArray();

  TlsLoopbackServer server(pki_b.leaf.private_key_pem, pki_b.ServerChainPem());
  ASSERT_TRUE(server.started());

  // Custom anchor Root A must reject server chain signed by Root B.
  std::shared_ptr<grpc::Channel> custom_anchor_channel = grpc::CreateChannel(
      server.target(), CreateAppleTlsCredentials(root_a_anchors.get()));
  grpc::Status custom_status =
      PerformUnaryEcho(custom_anchor_channel, "should-fail-root-a");
  EXPECT_FALSE(custom_status.ok());

  // Default OS trust (`CreateDefaultTlsCredentials()`) must also reject
  // ephemeral Root B.
  std::shared_ptr<grpc::Channel> default_trust_channel =
      grpc::CreateChannel(server.target(), CreateDefaultTlsCredentials());
  grpc::Status default_status =
      PerformUnaryEcho(default_trust_channel, "should-fail-os-trust");
  EXPECT_FALSE(default_status.ok());
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     LoopbackGrpcServerRejectsWrongHostName) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "expected.firestore.test";
  leaf_opts.dns_sans = {"expected.firestore.test"};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> root_anchors = pki.RootAnchorArray();

  TlsLoopbackServer server(pki.leaf.private_key_pem, pki.ServerChainPem());
  ASSERT_TRUE(server.started());

  grpc::ChannelArguments args;
  args.SetSslTargetNameOverride("wrong.firestore.test");
  std::shared_ptr<grpc::Channel> channel = grpc::CreateCustomChannel(
      server.target(), CreateAppleTlsCredentials(root_anchors.get()), args);

  grpc::Status status = PerformUnaryEcho(channel, "should-fail-wrong-host");
  EXPECT_FALSE(status.ok());
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     LoopbackGrpcServerRejectsMissingIntermediate) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "127.0.0.1";
  leaf_opts.ipv4_sans = {{127, 0, 0, 1}};
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> root_anchors = pki.RootAnchorArray();

  // Server presents ONLY leaf.cert_pem (omitting intermediate.cert_pem), while
  // client trusts only root.
  TlsLoopbackServer server(pki.leaf.private_key_pem, pki.leaf.cert_pem);
  ASSERT_TRUE(server.started());

  std::shared_ptr<grpc::Channel> channel = grpc::CreateChannel(
      server.target(), CreateAppleTlsCredentials(root_anchors.get()));

  grpc::Status status = PerformUnaryEcho(channel, "should-fail-missing-inter");
  EXPECT_FALSE(status.ok());
}

TEST(GrpcTlsCredentialsProviderAppleTest,
     LoopbackGrpcServerRejectsExpiredLeafCertificate) {
  CertOptions leaf_opts;
  leaf_opts.common_name = "127.0.0.1";
  leaf_opts.ipv4_sans = {{127, 0, 0, 1}};
  leaf_opts.not_before_offset = std::chrono::hours(-48);
  leaf_opts.not_after_offset = std::chrono::hours(-24);
  ThreeTierPki pki = BuildThreeTierPki(leaf_opts);
  ScopedCFRef<CFArrayRef> root_anchors = pki.RootAnchorArray();

  TlsLoopbackServer server(pki.leaf.private_key_pem, pki.ServerChainPem());
  ASSERT_TRUE(server.started());

  std::shared_ptr<grpc::Channel> channel = grpc::CreateChannel(
      server.target(), CreateAppleTlsCredentials(root_anchors.get()));

  grpc::Status status = PerformUnaryEcho(channel, "should-fail-expired-leaf");
  EXPECT_FALSE(status.ok());
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(__APPLE__)
