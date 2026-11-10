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

#include "Firestore/core/src/remote/grpc_tls_credentials_provider_linux.h"

#if !defined(__APPLE__) && !defined(_WIN32)

#include <dirent.h>
#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/pem.h>
#include <openssl/sha.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iterator>
#include <utility>

#include "Firestore/core/src/remote/grpc_tls_target_host.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "absl/strings/escaping.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/str_join.h"
#include "absl/strings/str_split.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/security/credentials.h"
#include "grpcpp/security/tls_certificate_provider.h"
#include "grpcpp/security/tls_certificate_verifier.h"
#include "grpcpp/security/tls_credentials_options.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace {

// ---------------------------------------------------------------------------
// Default system locations
// ---------------------------------------------------------------------------

// CA bundle files, tried in order; the first one that yields an anchor wins.
// This is the list used by Go's crypto/x509 (root_linux.go, root_bsd.go) plus
// a few BSD locations.
const char* const kDefaultBundleFiles[] = {
    "/etc/ssl/certs/ca-certificates.crt",  // Debian, Ubuntu, Gentoo, Arch
    "/etc/pki/tls/certs/ca-bundle.crt",    // Fedora, RHEL 6
    "/etc/ssl/ca-bundle.pem",              // openSUSE
    "/etc/pki/tls/cacert.pem",             // OpenELEC
    "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",  // CentOS, RHEL 7+
    "/etc/ssl/cert.pem",                       // Alpine, OpenBSD, FreeBSD
    "/usr/local/etc/ssl/cert.pem",             // FreeBSD
    "/usr/local/share/certs/ca-root-nss.crt",  // DragonFly BSD
};

// CA directories, used (all of them) if no bundle file yields an anchor.
const char* const kDefaultCertDirs[] = {
    "/etc/ssl/certs",                       // SLES, Debian (hash links)
    "/etc/pki/tls/certs",                   // Fedora, RHEL
    "/system/etc/security/cacerts",         // Android
    "/apex/com.android.conscrypt/cacerts",  // Android 14+
};

// p11-kit distrust directories: everything in them is blocklisted.
const char* const kDefaultBlocklistDirs[] = {
    "/etc/ca-certificates/trust-source/blacklist",  // Arch
    "/etc/ca-certificates/trust-source/blocklist",
    "/usr/share/ca-certificates/trust-source/blacklist",
    "/usr/share/ca-certificates/trust-source/blocklist",
    "/etc/pki/ca-trust/source/blacklist",  // Fedora, RHEL
    "/etc/pki/ca-trust/source/blocklist",
    "/usr/share/pki/ca-trust-source/blacklist",
    "/usr/share/pki/ca-trust-source/blocklist",
};

// p11-kit "openssl-bundle" extracts: `TRUSTED CERTIFICATE` entries carrying
// explicit distrust are blocklisted.
const char* const kDefaultTrustBundleFiles[] = {
    "/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt",  // Fedora, RHEL
    "/etc/pki/tls/certs/ca-bundle.trust.crt",
    "/etc/ca-certificates/extracted/ca-bundle.trust.crt",  // Arch
};

// Anything larger is certainly not a CA bundle (Mozilla's is ~250 KiB).
constexpr off_t kMaxFileSize = 16 * 1024 * 1024;

template <size_t N>
std::vector<std::string> ToVector(const char* const (&paths)[N]) {
  return std::vector<std::string>(std::begin(paths), std::end(paths));
}

// ---------------------------------------------------------------------------
// OpenSSL / BoringSSL helpers
// ---------------------------------------------------------------------------

struct X509Deleter {
  void operator()(X509* cert) const {
    X509_free(cert);
  }
};
using UniqueX509 = std::unique_ptr<X509, X509Deleter>;

struct BioDeleter {
  void operator()(BIO* bio) const {
    BIO_free(bio);
  }
};
using UniqueBio = std::unique_ptr<BIO, BioDeleter>;

std::string Sha256(const uint8_t* data, size_t size) {
  uint8_t digest[SHA256_DIGEST_LENGTH];
  SHA256(data, size, digest);
  return std::string(reinterpret_cast<const char*>(digest), sizeof(digest));
}

std::string Sha256(absl::string_view data) {
  return Sha256(reinterpret_cast<const uint8_t*>(data.data()), data.size());
}

std::string CertDer(X509* cert) {
  uint8_t* der = nullptr;
  int len = i2d_X509(cert, &der);
  if (len <= 0) return "";
  std::string result(reinterpret_cast<const char*>(der),
                     static_cast<size_t>(len));
  OPENSSL_free(der);
  return result;
}

std::string SpkiDer(X509* cert) {
  uint8_t* der = nullptr;
  int len = i2d_X509_PUBKEY(X509_get_X509_PUBKEY(cert), &der);
  if (len <= 0) return "";
  std::string result(reinterpret_cast<const char*>(der),
                     static_cast<size_t>(len));
  OPENSSL_free(der);
  return result;
}

std::string SubjectName(X509* cert) {
  char buf[256];
  X509_NAME_oneline(X509_get_subject_name(cert), buf, sizeof(buf));
  return buf;
}

// Parses exactly `size` bytes of DER as a certificate. Returns null if the
// bytes are not a certificate or have trailing data.
UniqueX509 ParseCertDer(const uint8_t* data, size_t size, size_t* consumed) {
  const uint8_t* p = data;
  UniqueX509 cert(d2i_X509(nullptr, &p, static_cast<long>(size)));  // NOLINT
  if (cert == nullptr) return nullptr;
  *consumed = static_cast<size_t>(p - data);
  return cert;
}

// ---------------------------------------------------------------------------
// TRUSTED CERTIFICATE auxiliary trust settings
// ---------------------------------------------------------------------------

// The DER contents of the OBJECT IDENTIFIERs we look for.
constexpr uint8_t kServerAuthOid[] = {0x2b, 0x06, 0x01, 0x05, 0x05,
                                      0x07, 0x03, 0x01};    // 1.3.6.1.5.5.7.3.1
constexpr uint8_t kAnyEkuOid[] = {0x55, 0x1d, 0x25, 0x00};  // 2.5.29.37.0

struct AuxTrust {
  bool has_trust_list = false;
  bool trusts_server_auth = false;
  bool rejects_server_auth = false;
};

// Reads one DER TLV (definite length only) from `*data`.
bool ReadTlv(absl::string_view* data,
             uint8_t* tag,
             absl::string_view* contents) {
  if (data->size() < 2) return false;
  *tag = static_cast<uint8_t>((*data)[0]);
  if ((*tag & 0x1f) == 0x1f) return false;  // High tag numbers: unsupported.
  size_t len = static_cast<uint8_t>((*data)[1]);
  size_t header = 2;
  if (len & 0x80) {
    size_t num_bytes = len & 0x7f;
    if (num_bytes == 0 || num_bytes > 4 || data->size() < 2 + num_bytes) {
      return false;
    }
    len = 0;
    for (size_t i = 0; i < num_bytes; ++i) {
      len = (len << 8) | static_cast<uint8_t>((*data)[2 + i]);
    }
    header += num_bytes;
  }
  if (data->size() - header < len) return false;
  *contents = data->substr(header, len);
  data->remove_prefix(header + len);
  return true;
}

// Scans a SEQUENCE OF OBJECT IDENTIFIER body for serverAuth or
// anyExtendedKeyUsage.
bool ContainsServerAuth(absl::string_view oids, bool* found) {
  *found = false;
  while (!oids.empty()) {
    uint8_t tag = 0;
    absl::string_view oid;
    if (!ReadTlv(&oids, &tag, &oid) || tag != 0x06) return false;
    auto equals = [&](const uint8_t* expected, size_t size) {
      return oid.size() == size && std::memcmp(oid.data(), expected, size) == 0;
    };
    if (equals(kServerAuthOid, sizeof(kServerAuthOid)) ||
        equals(kAnyEkuOid, sizeof(kAnyEkuOid))) {
      *found = true;
    }
  }
  return true;
}

// Parses the OpenSSL `X509_CERT_AUX` structure that follows the certificate in
// a `TRUSTED CERTIFICATE` block:
//
//   X509_CERT_AUX ::= SEQUENCE {
//     trust  SEQUENCE OF OBJECT IDENTIFIER OPTIONAL,
//     reject [0] IMPLICIT SEQUENCE OF OBJECT IDENTIFIER OPTIONAL,
//     alias  UTF8String OPTIONAL,
//     keyid  OCTET STRING OPTIONAL,
//     other  [1] IMPLICIT SEQUENCE OF AlgorithmIdentifier OPTIONAL }
//
// This is parsed directly rather than with `X509_check_trust` because OpenSSL
// and BoringSSL interpret trust lists differently (OpenSSL rejects any purpose
// missing from a non-empty trust list; BoringSSL does not), and BoringSSL has
// no accessors for the lists themselves.
bool ParseAuxTrust(absl::string_view aux, AuxTrust* out) {
  *out = AuxTrust{};
  if (aux.empty()) return true;  // No auxiliary data at all.
  uint8_t tag = 0;
  absl::string_view body;
  if (!ReadTlv(&aux, &tag, &body) || tag != 0x30 || !aux.empty()) return false;
  while (!body.empty()) {
    absl::string_view field;
    if (!ReadTlv(&body, &tag, &field)) return false;
    if (tag == 0x30) {
      out->has_trust_list = true;
      if (!ContainsServerAuth(field, &out->trusts_server_auth)) return false;
    } else if (tag == 0xa0) {
      if (!ContainsServerAuth(field, &out->rejects_server_auth)) return false;
    }
    // alias, keyid and other are irrelevant.
  }
  return true;
}

// ---------------------------------------------------------------------------
// Certificate file parsing
// ---------------------------------------------------------------------------

enum class Classification {
  kAnchor,     // Usable as a trust anchor for TLS server authentication.
  kExclude,    // Trusted for other purposes only: not an anchor.
  kBlocklist,  // Explicitly distrusted for TLS server authentication.
};

struct ParsedEntry {
  UniqueX509 cert;       // Null for bare public keys.
  std::string spki_der;  // Set for bare public keys.
  Classification classification = Classification::kAnchor;
};

Classification Classify(const AuxTrust& aux) {
  if (aux.rejects_server_auth) return Classification::kBlocklist;
  if (aux.has_trust_list && !aux.trusts_server_auth) {
    return Classification::kExclude;
  }
  return Classification::kAnchor;
}

// Parses every `CERTIFICATE`, `TRUSTED CERTIFICATE` and `PUBLIC KEY` PEM block
// in `data`. If there are none and `allow_der` is set, tries to parse `data` as
// a single DER certificate.
std::vector<ParsedEntry> ParseCertificates(const std::string& data,
                                           const std::string& path,
                                           bool allow_der) {
  std::vector<ParsedEntry> entries;
  UniqueBio bio(BIO_new_mem_buf(data.data(), static_cast<int>(data.size())));
  if (bio == nullptr) return entries;

  bool saw_pem = false;
  while (true) {
    char* name = nullptr;
    char* header = nullptr;
    uint8_t* body = nullptr;
    long len = 0;  // NOLINT(runtime/int)
    if (!PEM_read_bio(bio.get(), &name, &header, &body, &len)) break;
    saw_pem = true;
    std::string block_name = name;
    absl::string_view block(reinterpret_cast<const char*>(body),
                            static_cast<size_t>(len));
    OPENSSL_free(name);
    OPENSSL_free(header);

    if (block_name == "CERTIFICATE" || block_name == "X509 CERTIFICATE" ||
        block_name == "TRUSTED CERTIFICATE") {
      size_t consumed = 0;
      UniqueX509 cert = ParseCertDer(body, static_cast<size_t>(len), &consumed);
      AuxTrust aux;
      bool trusted_block = block_name == "TRUSTED CERTIFICATE";
      if (cert == nullptr ||
          (!trusted_block && consumed != static_cast<size_t>(len)) ||
          (trusted_block && !ParseAuxTrust(block.substr(consumed), &aux))) {
        LOG_WARN("Ignoring malformed %s in %s", block_name, path);
      } else {
        ParsedEntry entry;
        entry.cert = std::move(cert);
        entry.classification = Classify(aux);
        entries.push_back(std::move(entry));
      }
    } else if (block_name == "PUBLIC KEY") {
      ParsedEntry entry;
      entry.spki_der = std::string(block);
      entries.push_back(std::move(entry));
    }
    OPENSSL_free(body);
  }
  // Reaching the end of the input leaves a PEM_R_NO_START_LINE error behind.
  ERR_clear_error();

  if (!saw_pem && allow_der && !data.empty()) {
    size_t consumed = 0;
    UniqueX509 cert = ParseCertDer(
        reinterpret_cast<const uint8_t*>(data.data()), data.size(), &consumed);
    ERR_clear_error();
    if (cert != nullptr && consumed == data.size()) {
      ParsedEntry entry;
      entry.cert = std::move(cert);
      entries.push_back(std::move(entry));
    }
  }
  return entries;
}

// Strictly parses a peer certificate chain: every PEM block must be a
// well-formed `CERTIFICATE`. Unlike `ParseCertificates`, which skips malformed
// entries in system files, any malformed or unexpected block fails the whole
// chain, so that a skipped leaf or intermediate can never weaken the hostname
// or blocklist checks.
bool ParsePeerChain(absl::string_view pem_chain, std::vector<UniqueX509>* out) {
  out->clear();
  ERR_clear_error();
  UniqueBio bio(
      BIO_new_mem_buf(pem_chain.data(), static_cast<int>(pem_chain.size())));
  if (bio == nullptr) return false;

  bool ok = true;
  while (ok) {
    char* name = nullptr;
    char* header = nullptr;
    uint8_t* body = nullptr;
    long len = 0;  // NOLINT(runtime/int)
    if (!PEM_read_bio(bio.get(), &name, &header, &body, &len)) {
      // Running out of input is the only acceptable way to stop.
      uint32_t error = static_cast<uint32_t>(ERR_peek_last_error());
      ok = ERR_GET_LIB(error) == ERR_LIB_PEM &&
           ERR_GET_REASON(error) == PEM_R_NO_START_LINE;
      break;
    }
    size_t consumed = 0;
    UniqueX509 cert;
    if (std::strcmp(name, "CERTIFICATE") == 0) {
      cert = ParseCertDer(body, static_cast<size_t>(len), &consumed);
    }
    if (cert == nullptr || consumed != static_cast<size_t>(len)) {
      ok = false;
    } else {
      out->push_back(std::move(cert));
    }
    OPENSSL_free(name);
    OPENSSL_free(header);
    OPENSSL_free(body);
  }
  ERR_clear_error();
  return ok && !out->empty();
}

// ---------------------------------------------------------------------------
// File system helpers
// ---------------------------------------------------------------------------

bool IsDirectory(const std::string& path) {
  struct stat st;
  return stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

// Reads a regular file (following symlinks). Returns nullopt if it does not
// exist, is not a regular file, is too large, or cannot be read.
absl::optional<std::string> ReadRegularFile(const std::string& path) {
  struct stat st;
  if (stat(path.c_str(), &st) != 0 || !S_ISREG(st.st_mode)) {
    return absl::nullopt;
  }
  if (st.st_size > kMaxFileSize) {
    LOG_WARN("Ignoring %s: too large to be a CA bundle", path);
    return absl::nullopt;
  }
  std::ifstream in(path, std::ios::binary);
  if (!in) return absl::nullopt;
  return std::string(std::istreambuf_iterator<char>(in),
                     std::istreambuf_iterator<char>());
}

// Returns the paths of the regular files (following symlinks) in `dir`, sorted
// by name. Hidden files are skipped.
std::vector<std::string> ListRegularFiles(const std::string& dir) {
  std::vector<std::string> names;
  DIR* d = opendir(dir.c_str());
  if (d == nullptr) return {};
  while (struct dirent* entry = readdir(d)) {
    if (entry->d_name[0] == '.') continue;
    names.emplace_back(entry->d_name);
  }
  closedir(d);
  std::sort(names.begin(), names.end());

  std::vector<std::string> paths;
  for (const std::string& name : names) {
    std::string path = absl::StrCat(dir, "/", name);
    struct stat st;
    if (stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode)) {
      paths.push_back(std::move(path));
    }
  }
  return paths;
}

absl::optional<std::string> SecureGetEnv(const char* name) {
#if defined(__GLIBC__)
  const char* value = secure_getenv(name);
#else
  // Ignore the environment in set-uid / set-gid processes, like secure_getenv.
  const char* value =
      (getuid() == geteuid() && getgid() == getegid()) ? getenv(name) : nullptr;
#endif
  if (value == nullptr) return absl::nullopt;
  return std::string(value);
}

// ---------------------------------------------------------------------------
// Trust store builder
// ---------------------------------------------------------------------------

class TrustStoreBuilder {
 public:
  void Block(X509* cert) {
    store_.blocked_cert_sha256.insert(Sha256(CertDer(cert)));
    BlockSpki(SpkiDer(cert));
  }

  void BlockSpki(const std::string& spki_der) {
    if (!spki_der.empty()) {
      store_.blocked_spki_sha256.insert(Sha256(spki_der));
    }
  }

  // Adds every entry in `path` to the blocklist.
  void LoadBlocklistFile(const std::string& path) {
    absl::optional<std::string> data = ReadRegularFile(path);
    if (!data) return;
    for (ParsedEntry& entry :
         ParseCertificates(*data, path, /*allow_der=*/true)) {
      if (entry.cert != nullptr) {
        Block(entry.cert.get());
      } else {
        BlockSpki(entry.spki_der);
      }
    }
  }

  // Adds the explicitly distrusted entries in `path` to the blocklist.
  void LoadTrustBundleFile(const std::string& path) {
    absl::optional<std::string> data = ReadRegularFile(path);
    if (!data) return;
    for (ParsedEntry& entry :
         ParseCertificates(*data, path, /*allow_der=*/false)) {
      if (entry.cert != nullptr &&
          entry.classification == Classification::kBlocklist) {
        Block(entry.cert.get());
      }
    }
  }

  // Adds the anchors in a bundle file (or every file in a directory) as
  // candidates. Returns the number of anchor candidates found.
  size_t LoadAnchors(const std::string& path) {
    std::vector<std::string> files;
    if (IsDirectory(path)) {
      files = ListRegularFiles(path);
    } else {
      files.push_back(path);
    }
    size_t found = 0;
    for (const std::string& file : files) {
      absl::optional<std::string> data = ReadRegularFile(file);
      if (!data) continue;
      for (ParsedEntry& entry :
           ParseCertificates(*data, file, /*allow_der=*/false)) {
        if (entry.cert == nullptr) continue;
        switch (entry.classification) {
          case Classification::kAnchor:
            candidates_.push_back(std::move(entry.cert));
            ++found;
            break;
          case Classification::kBlocklist:
            Block(entry.cert.get());
            break;
          case Classification::kExclude:
            break;
        }
      }
    }
    if (found > 0) sources_.push_back(path);
    return found;
  }

  // Re-emits the non-blocklisted, de-duplicated anchor candidates as plain
  // PEM `CERTIFICATE` blocks.
  LinuxTrustStore Finish() && {
    std::unordered_set<std::string> seen;
    UniqueBio bio(BIO_new(BIO_s_mem()));
    for (const UniqueX509& cert : candidates_) {
      std::string der = CertDer(cert.get());
      if (der.empty() || store_.IsBlocked(der, SpkiDer(cert.get()))) continue;
      if (!seen.insert(Sha256(der)).second) continue;
      if (PEM_write_bio_X509(bio.get(), cert.get()) != 1) continue;
      ++store_.anchor_count;
    }
    char* data = nullptr;
    long len = BIO_get_mem_data(bio.get(), &data);  // NOLINT(runtime/int)
    if (len > 0) store_.anchors_pem.assign(data, static_cast<size_t>(len));
    store_.anchor_source = absl::StrJoin(sources_, ", ");
    return std::move(store_);
  }

 private:
  LinuxTrustStore store_;
  std::vector<UniqueX509> candidates_;
  std::vector<std::string> sources_;
};

// ---------------------------------------------------------------------------
// Verifier
// ---------------------------------------------------------------------------

constexpr const char* kNoAnchorsMessage =
    "No trusted CA certificates were found on this system, so Firestore "
    "cannot verify TLS connections. Install the system CA certificates "
    "package (for example `ca-certificates`), or set SSL_CERT_FILE or "
    "SSL_CERT_DIR to a PEM bundle of trusted CA certificates.";

absl::string_view ToStringView(grpc::string_ref ref) {
  return ref.empty() ? absl::string_view{}
                     : absl::string_view(ref.data(), ref.size());
}

/**
 * Rejects blocklisted certificates and hostname mismatches. Chain validation
 * against the system anchors is done by the TLS library beforehand
 * (`verify_server_certs(true)`).
 *
 * Verification is synchronous: it only parses the (short) peer chain and
 * computes a few digests, with no I/O.
 */
class LinuxBlocklistCertificateVerifier final
    : public grpc::experimental::ExternalCertificateVerifier {
 public:
  explicit LinuxBlocklistCertificateVerifier(
      std::shared_ptr<const LinuxTrustStore> store)
      : store_(std::move(store)) {
  }

  bool Verify(grpc::experimental::TlsCustomVerificationCheckRequest* request,
              std::function<void(grpc::Status)>,
              grpc::Status* sync_status) override {
    HARD_ASSERT(sync_status != nullptr,
                "TLS synchronous verification status output must not be null");
    if (request == nullptr) {
      *sync_status = grpc::Status(
          grpc::StatusCode::UNAUTHENTICATED,
          "TLS custom verification check request must not be null");
      return true;
    }
    grpc::string_ref chain = request->peer_cert_full_chain();
    if (chain.empty()) chain = request->peer_cert();
    *sync_status = VerifyLinuxPeerCertificateChain(
        ToStringView(chain), ToStringView(request->target_name()), *store_);
    return true;
  }

  void Cancel(grpc::experimental::TlsCustomVerificationCheckRequest*) override {
    // Nothing to cancel: `Verify()` always completes synchronously.
  }

 private:
  std::shared_ptr<const LinuxTrustStore> store_;
};

}  // namespace

bool LinuxTrustStore::IsBlocked(absl::string_view cert_der,
                                absl::string_view spki_der) const {
  return blocked_cert_sha256.count(Sha256(cert_der)) > 0 ||
         blocked_spki_sha256.count(Sha256(spki_der)) > 0;
}

LinuxTrustStore LoadLinuxTrustStore(const LinuxTrustConfig& config) {
  TrustStoreBuilder builder;

  for (const std::string& dir :
       config.blocklist_dirs.value_or(ToVector(kDefaultBlocklistDirs))) {
    for (const std::string& file : ListRegularFiles(dir)) {
      builder.LoadBlocklistFile(file);
    }
  }
  for (const std::string& file :
       config.trust_bundle_files.value_or(ToVector(kDefaultTrustBundleFiles))) {
    builder.LoadTrustBundleFile(file);
  }

  if (!config.ca_path.empty()) {
    if (builder.LoadAnchors(config.ca_path) == 0) {
      LOG_WARN("No CA certificates found in %s", config.ca_path);
    }
    return std::move(builder).Finish();
  }

  std::function<absl::optional<std::string>(const char*)> get_env =
      config.get_env ? config.get_env : SecureGetEnv;
  auto env = [&](const char* name) -> std::string {
    return get_env(name).value_or("");
  };

  // Environment overrides: single files first, then directory lists.
  for (const char* var :
       {"GRPC_DEFAULT_SSL_ROOTS_FILE_PATH", "SSL_CERT_FILE"}) {
    std::string path = env(var);
    if (path.empty()) continue;
    if (builder.LoadAnchors(path) > 0) return std::move(builder).Finish();
    LOG_WARN("Ignoring %s=%s: no CA certificates found there", var, path);
  }
  for (const char* var : {"GRPC_SYSTEM_SSL_ROOTS_DIR", "SSL_CERT_DIR"}) {
    std::string dirs = env(var);
    if (dirs.empty()) continue;
    size_t found = 0;
    for (absl::string_view dir : absl::StrSplit(dirs, ':', absl::SkipEmpty())) {
      found += builder.LoadAnchors(std::string(dir));
    }
    if (found > 0) return std::move(builder).Finish();
    LOG_WARN("Ignoring %s=%s: no CA certificates found there", var, dirs);
  }

  for (const std::string& file :
       config.bundle_files.value_or(ToVector(kDefaultBundleFiles))) {
    if (builder.LoadAnchors(file) > 0) return std::move(builder).Finish();
  }

  for (const std::string& dir :
       config.cert_dirs.value_or(ToVector(kDefaultCertDirs))) {
    builder.LoadAnchors(dir);
  }
  return std::move(builder).Finish();
}

grpc::Status VerifyLinuxPeerCertificateChain(absl::string_view pem_chain,
                                             absl::string_view target_name,
                                             const LinuxTrustStore& store) {
  if (!store.has_anchors()) {
    return grpc::Status(grpc::StatusCode::UNAVAILABLE, kNoAnchorsMessage);
  }

  absl::optional<TlsTargetHost> host = ParseTlsTargetHost(target_name);
  if (!host) {
    return grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                        absl::StrCat("Invalid TLS target host name: '",
                                     absl::CHexEscape(target_name), "'"));
  }

  std::vector<UniqueX509> chain;
  if (!ParsePeerChain(pem_chain, &chain)) {
    return grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                        "Missing or malformed TLS peer certificate chain");
  }

  for (const UniqueX509& entry : chain) {
    X509* cert = entry.get();
    if (store.IsBlocked(CertDer(cert), SpkiDer(cert))) {
      return grpc::Status(
          grpc::StatusCode::UNAUTHENTICATED,
          absl::StrCat("TLS peer certificate '", SubjectName(cert),
                       "' is distrusted by the system CA blocklist"));
    }
  }

  // Match subjectAltNames only (RFC 9525, as on Apple platforms): no fallback
  // to the subject common name, and wildcards only as a whole leftmost label.
  X509* leaf = chain.front().get();
  int match = 0;
  if (host->kind == TlsTargetHost::Kind::kDns) {
    match = X509_check_host(leaf, host->host.data(), host->host.size(),
                            X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS |
                                X509_CHECK_FLAG_NEVER_CHECK_SUBJECT,
                            nullptr);
  } else {
    match = X509_check_ip_asc(leaf, host->host.c_str(), 0);
  }
  ERR_clear_error();
  if (match != 1) {
    return grpc::Status(
        grpc::StatusCode::UNAUTHENTICATED,
        absl::StrCat("TLS peer certificate '", SubjectName(leaf),
                     "' does not match host '", host->host, "'"));
  }
  return grpc::Status::OK;
}

std::shared_ptr<grpc::ChannelCredentials> CreateLinuxTlsCredentials(
    const LinuxTrustConfig& config) {
  auto store =
      std::make_shared<const LinuxTrustStore>(LoadLinuxTrustStore(config));

  grpc::experimental::TlsChannelCredentialsOptions options;
  if (store->has_anchors()) {
    LOG_DEBUG(
        "Loaded %s TLS trust anchors from %s; %s certificates and %s "
        "keys blocklisted",
        store->anchor_count, store->anchor_source,
        store->blocked_cert_sha256.size(), store->blocked_spki_sha256.size());
    // gRPC 1.83 deprecates these in favor of `InMemoryCertificateProvider` and
    // `set_root_certificate_provider`, which gRPC 1.69 (used by CMake builds)
    // does not have.
    SUPPRESS_DEPRECATED_DECLARATIONS_BEGIN()
    options.set_certificate_provider(
        std::make_shared<grpc::experimental::StaticDataCertificateProvider>(
            store->anchors_pem));
    options.watch_root_certs();
    SUPPRESS_END()
    options.set_verify_server_certs(true);
  } else {
    // Constructing `StaticDataCertificateProvider` with no roots aborts, so
    // skip chain validation and let the verifier fail every handshake.
    LOG_ERROR("%s", kNoAnchorsMessage);
    options.set_verify_server_certs(false);
  }

  // A fresh verifier per credentials object, as on Apple platforms: gRPC
  // compares TLS credentials by verifier identity, so each channel gets its own
  // subchannel.
  options.set_certificate_verifier(
      grpc::experimental::ExternalCertificateVerifier::Create<
          LinuxBlocklistCertificateVerifier>(std::move(store)));
  // gRPC's per-call `check_call_host` stays enabled (the default); see
  // grpc_tls_credentials_provider.h for why IP-literal hosts must be canonical.
  return grpc::experimental::TlsCredentials(options);
}

std::shared_ptr<grpc::ChannelCredentials> CreateDefaultTlsCredentials() {
  return CreateLinuxTlsCredentials();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // !defined(__APPLE__) && !defined(_WIN32)
