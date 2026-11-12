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

#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cstdio>
#include <fstream>
#include <map>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/util/filesystem.h"
#include "Firestore/core/src/util/path.h"
#include "Firestore/core/test/unit/remote/tls_loopback_server.h"
#include "Firestore/core/test/unit/remote/tls_test_pki.h"
#include "Firestore/core/test/unit/testutil/filesystem_testing.h"
#include "absl/strings/str_cat.h"
#include "absl/types/optional.h"
#include "gtest/gtest.h"
#include "openssl/bio.h"
#include "openssl/obj_mac.h"
#include "openssl/objects.h"
#include "openssl/pem.h"
#include "openssl/x509.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using tls_testing::CreateTestPki;
using tls_testing::IssueTestCertificate;
using tls_testing::PemChain;
using tls_testing::TestCertificate;
using tls_testing::TestCertOptions;
using tls_testing::TestPki;
using tls_testing::TlsLoopbackServer;
using util::Path;

constexpr const char* kHost = "loopback.firestore.test";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void WriteFile(const Path& path, const std::string& contents) {
  std::ofstream out(path.ToUtf8String(), std::ios::binary | std::ios::trunc);
  ASSERT_TRUE(out.good()) << path.ToUtf8String();
  out << contents;
}

enum class AuxTrust {
  kTrustServerAuth,
  kTrustEmailOnly,
  kRejectServerAuth,
  kRejectAnyEku
};

// Encodes `cert` as an OpenSSL `TRUSTED CERTIFICATE` PEM block carrying the
// given auxiliary trust settings, like the entries of Fedora's
// `ca-bundle.trust.crt`.
std::string TrustedCertificatePem(const TestCertificate& cert, AuxTrust trust) {
  std::unique_ptr<X509, decltype(&X509_free)> copy(X509_dup(cert.x509()),
                                                   X509_free);
  switch (trust) {
    case AuxTrust::kTrustServerAuth:
      X509_add1_trust_object(copy.get(), OBJ_nid2obj(NID_server_auth));
      X509_add1_trust_object(copy.get(), OBJ_nid2obj(NID_email_protect));
      break;
    case AuxTrust::kTrustEmailOnly:
      X509_add1_trust_object(copy.get(), OBJ_nid2obj(NID_email_protect));
      break;
    case AuxTrust::kRejectServerAuth:
      X509_add1_reject_object(copy.get(), OBJ_nid2obj(NID_client_auth));
      X509_add1_reject_object(copy.get(), OBJ_nid2obj(NID_server_auth));
      break;
    case AuxTrust::kRejectAnyEku:
      X509_add1_reject_object(copy.get(), OBJ_nid2obj(NID_anyExtendedKeyUsage));
      break;
  }
  std::unique_ptr<BIO, decltype(&BIO_free)> bio(BIO_new(BIO_s_mem()), BIO_free);
  EXPECT_EQ(PEM_write_bio_X509_AUX(bio.get(), copy.get()), 1);
  char* data = nullptr;
  long len = BIO_get_mem_data(bio.get(), &data);  // NOLINT(runtime/int)
  std::string pem(data, static_cast<size_t>(len));
  EXPECT_NE(pem.find("BEGIN TRUSTED CERTIFICATE"), std::string::npos);
  return pem;
}

std::string PublicKeyPem(const TestCertificate& cert) {
  std::unique_ptr<BIO, decltype(&BIO_free)> bio(BIO_new(BIO_s_mem()), BIO_free);
  EXPECT_EQ(PEM_write_bio_PUBKEY(bio.get(), cert.key()), 1);
  char* data = nullptr;
  long len = BIO_get_mem_data(bio.get(), &data);  // NOLINT(runtime/int)
  return std::string(data, static_cast<size_t>(len));
}

TestCertificate MakeRoot(const std::string& name) {
  TestCertOptions opts;
  opts.common_name = absl::StrCat("Firestore Linux Test Root ", name);
  opts.is_ca = true;
  return IssueTestCertificate(opts, /*issuer=*/nullptr);
}

// Whether `store.anchors_pem` contains `cert`.
bool HasAnchor(const LinuxTrustStore& store, const TestCertificate& cert) {
  return store.anchors_pem.find(cert.cert_pem()) != std::string::npos;
}

bool IsBlocked(const LinuxTrustStore& store, const TestCertificate& cert) {
  return store.IsBlocked(cert.cert_der(), cert.spki_der());
}

// A `LinuxTrustConfig` isolated from the host: no environment, and every
// distro path points into `dir` (which starts out empty).
class IsolatedConfig {
 public:
  IsolatedConfig() {
    config_.get_env = [this](const char* name) -> absl::optional<std::string> {
      auto it = env_.find(name);
      if (it == env_.end()) return absl::nullopt;
      return it->second;
    };
    config_.bundle_files = std::vector<std::string>{};
    config_.cert_dirs = std::vector<std::string>{};
    config_.blocklist_dirs = std::vector<std::string>{};
    config_.trust_bundle_files = std::vector<std::string>{};
  }

  void SetEnv(const std::string& name, const std::string& value) {
    env_[name] = value;
  }

  LinuxTrustConfig& config() {
    return config_;
  }

 private:
  std::map<std::string, std::string> env_;
  LinuxTrustConfig config_;
};

// Sets (or unsets) a real environment variable and restores it on scope exit.
class ScopedEnv {
 public:
  ScopedEnv(const char* name, const char* value) : name_(name) {
    const char* old = getenv(name);
    if (old != nullptr) old_ = std::string(old);
    if (value != nullptr) {
      setenv(name, value, /*overwrite=*/1);
    } else {
      unsetenv(name);
    }
  }
  ~ScopedEnv() {
    if (old_) {
      setenv(name_.c_str(), old_->c_str(), /*overwrite=*/1);
    } else {
      unsetenv(name_.c_str());
    }
  }

 private:
  std::string name_;
  absl::optional<std::string> old_;
};

class GrpcTlsCredentialsProviderLinuxTest : public ::testing::Test {
 protected:
  Path File(const std::string& name, const std::string& contents) {
    Path path = dir_.AppendUtf8(name);
    WriteFile(path, contents);
    return path;
  }

  Path Dir(const std::string& name) {
    Path path = dir_.AppendUtf8(name);
    EXPECT_TRUE(util::Filesystem::Default()->RecursivelyCreateDir(path).ok());
    return path;
  }

  testutil::TestTempDir temp_dir_;
  const Path& dir_ = temp_dir_.path();
};

// ===========================================================================
// 1. Anchor resolution order
// ===========================================================================

TEST_F(GrpcTlsCredentialsProviderLinuxTest, ExplicitCaPathWinsOverEverything) {
  TestCertificate a = MakeRoot("explicit-a");
  TestCertificate b = MakeRoot("explicit-b");
  TestCertificate c = MakeRoot("explicit-c");
  Path file_a = File("a.pem", a.cert_pem());
  Path file_b = File("b.pem", b.cert_pem());
  Path file_c = File("c.pem", c.cert_pem());

  IsolatedConfig iso;
  iso.config().ca_path = file_a.ToUtf8String();
  iso.SetEnv("SSL_CERT_FILE", file_b.ToUtf8String());
  iso.config().bundle_files = std::vector<std::string>{file_c.ToUtf8String()};

  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());
  EXPECT_EQ(store.anchor_count, 1u);
  EXPECT_TRUE(HasAnchor(store, a));
  EXPECT_FALSE(HasAnchor(store, b));
  EXPECT_FALSE(HasAnchor(store, c));
  EXPECT_NE(store.anchor_source.find(file_a.ToUtf8String()), std::string::npos);
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest, ExplicitCaPathDoesNotFallBack) {
  TestCertificate c = MakeRoot("explicit-nofallback");
  Path file_c = File("c.pem", c.cert_pem());

  IsolatedConfig iso;
  iso.config().ca_path = dir_.AppendUtf8("missing.pem").ToUtf8String();
  iso.config().bundle_files = std::vector<std::string>{file_c.ToUtf8String()};

  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());
  EXPECT_FALSE(store.has_anchors());
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest, ExplicitCaPathMayBeADirectory) {
  TestCertificate a = MakeRoot("explicit-dir-a");
  TestCertificate b = MakeRoot("explicit-dir-b");
  Path dir = Dir("explicit");
  WriteFile(dir.AppendUtf8("a.pem"), a.cert_pem());
  WriteFile(dir.AppendUtf8("b.crt"), b.cert_pem());

  IsolatedConfig iso;
  iso.config().ca_path = dir.ToUtf8String();

  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());
  EXPECT_EQ(store.anchor_count, 2u);
  EXPECT_TRUE(HasAnchor(store, a));
  EXPECT_TRUE(HasAnchor(store, b));
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest, EnvironmentVariablePrecedence) {
  TestCertificate grpc_file = MakeRoot("env-grpc-file");
  TestCertificate ssl_file = MakeRoot("env-ssl-file");
  TestCertificate grpc_dir = MakeRoot("env-grpc-dir");
  TestCertificate ssl_dir = MakeRoot("env-ssl-dir");
  TestCertificate distro = MakeRoot("env-distro");
  Path grpc_file_path = File("grpc.pem", grpc_file.cert_pem());
  Path ssl_file_path = File("ssl.pem", ssl_file.cert_pem());
  Path grpc_dir_path = Dir("grpcdir");
  WriteFile(grpc_dir_path.AppendUtf8("r.pem"), grpc_dir.cert_pem());
  Path ssl_dir_path = Dir("ssldir");
  WriteFile(ssl_dir_path.AppendUtf8("r.pem"), ssl_dir.cert_pem());
  Path distro_path = File("distro.pem", distro.cert_pem());

  struct Case {
    std::vector<std::pair<std::string, std::string>> env;
    const TestCertificate* expected;
  };
  const std::vector<Case> cases = {
      {{{"GRPC_DEFAULT_SSL_ROOTS_FILE_PATH", grpc_file_path.ToUtf8String()},
        {"SSL_CERT_FILE", ssl_file_path.ToUtf8String()},
        {"GRPC_SYSTEM_SSL_ROOTS_DIR", grpc_dir_path.ToUtf8String()},
        {"SSL_CERT_DIR", ssl_dir_path.ToUtf8String()}},
       &grpc_file},
      {{{"SSL_CERT_FILE", ssl_file_path.ToUtf8String()},
        {"GRPC_SYSTEM_SSL_ROOTS_DIR", grpc_dir_path.ToUtf8String()},
        {"SSL_CERT_DIR", ssl_dir_path.ToUtf8String()}},
       &ssl_file},
      {{{"GRPC_SYSTEM_SSL_ROOTS_DIR", grpc_dir_path.ToUtf8String()},
        {"SSL_CERT_DIR", ssl_dir_path.ToUtf8String()}},
       &grpc_dir},
      {{{"SSL_CERT_DIR", ssl_dir_path.ToUtf8String()}}, &ssl_dir},
      {{}, &distro},
      // Set but unusable variables fall through to the next source.
      {{{"GRPC_DEFAULT_SSL_ROOTS_FILE_PATH",
         dir_.AppendUtf8("missing.pem").ToUtf8String()},
        {"SSL_CERT_FILE", ""}},
       &distro},
  };

  for (size_t i = 0; i < cases.size(); ++i) {
    IsolatedConfig iso;
    for (const auto& kv : cases[i].env) iso.SetEnv(kv.first, kv.second);
    iso.config().bundle_files =
        std::vector<std::string>{distro_path.ToUtf8String()};
    LinuxTrustStore store = LoadLinuxTrustStore(iso.config());
    EXPECT_EQ(store.anchor_count, 1u) << "case " << i;
    EXPECT_TRUE(HasAnchor(store, *cases[i].expected)) << "case " << i;
  }
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest, SslCertDirIsColonSeparated) {
  TestCertificate a = MakeRoot("certdir-a");
  TestCertificate b = MakeRoot("certdir-b");
  Path dir_a = Dir("da");
  WriteFile(dir_a.AppendUtf8("a.pem"), a.cert_pem());
  Path dir_b = Dir("db");
  WriteFile(dir_b.AppendUtf8("b.pem"), b.cert_pem());

  IsolatedConfig iso;
  iso.SetEnv("SSL_CERT_DIR",
             absl::StrCat(dir_a.ToUtf8String(), ":", dir_b.ToUtf8String()));
  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());
  EXPECT_EQ(store.anchor_count, 2u);
  EXPECT_TRUE(HasAnchor(store, a));
  EXPECT_TRUE(HasAnchor(store, b));
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest, RealEnvironmentIsConsulted) {
  TestCertificate a = MakeRoot("real-env");
  Path file_a = File("a.pem", a.cert_pem());

  ScopedEnv grpc_roots("GRPC_DEFAULT_SSL_ROOTS_FILE_PATH", nullptr);
  ScopedEnv ssl_file("SSL_CERT_FILE", file_a.ToUtf8String().c_str());

  LinuxTrustConfig config;  // Default env lookup.
  config.bundle_files = std::vector<std::string>{};
  config.cert_dirs = std::vector<std::string>{};
  config.blocklist_dirs = std::vector<std::string>{};
  config.trust_bundle_files = std::vector<std::string>{};
  LinuxTrustStore store = LoadLinuxTrustStore(config);
  EXPECT_EQ(store.anchor_count, 1u);
  EXPECT_TRUE(HasAnchor(store, a));
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest, FirstUsableBundleFileWins) {
  TestCertificate a = MakeRoot("bundle-a");
  TestCertificate b = MakeRoot("bundle-b");
  Path empty = File("empty.pem", "not a certificate\n");
  Path file_a = File("a.pem", a.cert_pem());
  Path file_b = File("b.pem", b.cert_pem());

  IsolatedConfig iso;
  iso.config().bundle_files = std::vector<std::string>{
      dir_.AppendUtf8("missing.pem").ToUtf8String(), empty.ToUtf8String(),
      file_a.ToUtf8String(), file_b.ToUtf8String()};
  iso.config().cert_dirs = std::vector<std::string>{dir_.ToUtf8String()};

  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());
  EXPECT_EQ(store.anchor_count, 1u);
  EXPECT_TRUE(HasAnchor(store, a));
  EXPECT_NE(store.anchor_source.find(file_a.ToUtf8String()), std::string::npos);
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest,
       CertDirsAreUsedWhenNoBundleAndDeduplicated) {
  TestCertificate a = MakeRoot("dir-a");
  TestCertificate b = MakeRoot("dir-b");
  Path certs = Dir("certs");
  WriteFile(certs.AppendUtf8("a.pem"), a.cert_pem());
  WriteFile(certs.AppendUtf8("b.pem"), b.cert_pem());
  // Hash symlinks and bundle copies duplicate the individual files.
  ASSERT_EQ(symlink(certs.AppendUtf8("a.pem").ToUtf8String().c_str(),
                    certs.AppendUtf8("1a2b3c4d.0").ToUtf8String().c_str()),
            0);
  WriteFile(certs.AppendUtf8("bundle.crt"), a.cert_pem() + b.cert_pem());
  Dir("certs/subdir");
  // A dangling symlink is ignored.
  ASSERT_EQ(symlink("/nonexistent/firestore.pem",
                    certs.AppendUtf8("dangling.pem").ToUtf8String().c_str()),
            0);

  IsolatedConfig iso;
  iso.config().bundle_files =
      std::vector<std::string>{dir_.AppendUtf8("missing.pem").ToUtf8String()};
  iso.config().cert_dirs = std::vector<std::string>{certs.ToUtf8String()};

  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());
  EXPECT_EQ(store.anchor_count, 2u);
  EXPECT_TRUE(HasAnchor(store, a));
  EXPECT_TRUE(HasAnchor(store, b));
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest, NoAnchorsFound) {
  IsolatedConfig iso;
  iso.config().bundle_files =
      std::vector<std::string>{dir_.AppendUtf8("missing.pem").ToUtf8String()};
  iso.config().cert_dirs =
      std::vector<std::string>{dir_.AppendUtf8("missing").ToUtf8String()};

  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());
  EXPECT_FALSE(store.has_anchors());
  EXPECT_TRUE(store.anchors_pem.empty());

  TestPki pki = CreateTestPki("no-anchors", {kHost});
  grpc::Status status =
      VerifyLinuxPeerCertificateChain(pki.ServerChainPem(), kHost, store);
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAVAILABLE);
  EXPECT_NE(status.error_message().find("SSL_CERT_FILE"), std::string::npos)
      << status.error_message();
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest, DefaultConfigLoadsHostStore) {
  // Smoke test against the real system store of the machine running the test.
  // Hosts without a CA store (minimal containers) yield no anchors.
  LinuxTrustStore store = LoadLinuxTrustStore();
  if (store.has_anchors()) {
    EXPECT_NE(store.anchors_pem.find("-----BEGIN CERTIFICATE-----"),
              std::string::npos);
    EXPECT_EQ(store.anchors_pem.find("TRUSTED CERTIFICATE"), std::string::npos);
    EXPECT_FALSE(store.anchor_source.empty());
  }
}

// ===========================================================================
// 2. TRUSTED CERTIFICATE transcoding and blocklists
// ===========================================================================

TEST_F(GrpcTlsCredentialsProviderLinuxTest,
       TrustedCertificateEntriesAreTranscodedOrBlocklisted) {
  TestCertificate trusted = MakeRoot("aux-trusted");
  TestCertificate email_only = MakeRoot("aux-email");
  TestCertificate rejected = MakeRoot("aux-rejected");
  TestCertificate rejected_any = MakeRoot("aux-rejected-any");
  TestCertificate plain = MakeRoot("aux-plain");
  Path bundle = File(
      "trust.crt",
      absl::StrCat(TrustedCertificatePem(trusted, AuxTrust::kTrustServerAuth),
                   TrustedCertificatePem(email_only, AuxTrust::kTrustEmailOnly),
                   TrustedCertificatePem(rejected, AuxTrust::kRejectServerAuth),
                   TrustedCertificatePem(rejected_any, AuxTrust::kRejectAnyEku),
                   plain.cert_pem()));

  IsolatedConfig iso;
  iso.config().ca_path = bundle.ToUtf8String();
  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());

  EXPECT_EQ(store.anchor_count, 2u);
  EXPECT_TRUE(HasAnchor(store, trusted));  // Re-emitted as plain CERTIFICATE.
  EXPECT_TRUE(HasAnchor(store, plain));
  EXPECT_FALSE(HasAnchor(store, email_only));
  EXPECT_FALSE(HasAnchor(store, rejected));
  EXPECT_FALSE(HasAnchor(store, rejected_any));
  EXPECT_EQ(store.anchors_pem.find("TRUSTED CERTIFICATE"), std::string::npos);

  EXPECT_TRUE(IsBlocked(store, rejected));
  EXPECT_TRUE(IsBlocked(store, rejected_any));
  EXPECT_FALSE(IsBlocked(store, email_only));
  EXPECT_FALSE(IsBlocked(store, trusted));
  EXPECT_FALSE(IsBlocked(store, plain));
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest,
       TrustBundleFilesContributeOnlyDistrustedEntries) {
  TestCertificate anchor = MakeRoot("tb-anchor");
  TestCertificate trusted = MakeRoot("tb-trusted");
  TestCertificate rejected = MakeRoot("tb-rejected");
  Path anchors = File("anchors.pem", anchor.cert_pem() + rejected.cert_pem());
  Path trust_bundle =
      File("ca-bundle.trust.crt",
           absl::StrCat(
               TrustedCertificatePem(trusted, AuxTrust::kTrustServerAuth),
               TrustedCertificatePem(rejected, AuxTrust::kRejectServerAuth)));

  IsolatedConfig iso;
  iso.config().bundle_files = std::vector<std::string>{anchors.ToUtf8String()};
  iso.config().trust_bundle_files =
      std::vector<std::string>{trust_bundle.ToUtf8String()};
  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());

  EXPECT_EQ(store.anchor_count, 1u);
  EXPECT_TRUE(HasAnchor(store, anchor));
  EXPECT_FALSE(HasAnchor(store, trusted));
  EXPECT_FALSE(HasAnchor(store, rejected));  // Removed by the blocklist.
  EXPECT_TRUE(IsBlocked(store, rejected));
  EXPECT_FALSE(IsBlocked(store, trusted));
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest,
       BlocklistDirectoriesAcceptPemDerAndPublicKeys) {
  TestCertificate pem_root = MakeRoot("bl-pem");
  TestCertificate der_root = MakeRoot("bl-der");
  TestCertificate key_root = MakeRoot("bl-key");
  TestCertificate kept = MakeRoot("bl-kept");
  Path anchors =
      File("anchors.pem", absl::StrCat(pem_root.cert_pem(), der_root.cert_pem(),
                                       key_root.cert_pem(), kept.cert_pem()));
  Path blacklist = Dir("blacklist");
  WriteFile(blacklist.AppendUtf8("pem.pem"), pem_root.cert_pem());
  WriteFile(blacklist.AppendUtf8("der.crt"), der_root.cert_der());
  Path blocklist = Dir("blocklist");
  WriteFile(blocklist.AppendUtf8("key.pem"), PublicKeyPem(key_root));

  IsolatedConfig iso;
  iso.config().bundle_files = std::vector<std::string>{anchors.ToUtf8String()};
  iso.config().blocklist_dirs = std::vector<std::string>{
      blacklist.ToUtf8String(), blocklist.ToUtf8String(),
      dir_.AppendUtf8("missing").ToUtf8String()};
  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());

  EXPECT_TRUE(IsBlocked(store, pem_root));
  EXPECT_TRUE(IsBlocked(store, der_root));
  EXPECT_TRUE(IsBlocked(store, key_root));
  EXPECT_FALSE(IsBlocked(store, kept));
  EXPECT_EQ(store.anchor_count, 1u);
  EXPECT_TRUE(HasAnchor(store, kept));
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest,
       BlocklistMatchesReissuedCertificateBySpki) {
  TestCertificate root = MakeRoot("spki");
  TestCertOptions inter_opts;
  inter_opts.common_name = "Firestore Linux Test Distrusted Intermediate";
  inter_opts.is_ca = true;
  TestCertificate distrusted = IssueTestCertificate(inter_opts, &root);
  TestCertificate reissued =
      IssueTestCertificate(inter_opts, &root, /*reuse_key_from=*/&distrusted);
  ASSERT_NE(reissued.cert_der(), distrusted.cert_der());
  ASSERT_EQ(reissued.spki_der(), distrusted.spki_der());

  Path anchors = File("anchors.pem", root.cert_pem());
  Path blacklist = Dir("blacklist");
  WriteFile(blacklist.AppendUtf8("distrusted.pem"), distrusted.cert_pem());

  IsolatedConfig iso;
  iso.config().bundle_files = std::vector<std::string>{anchors.ToUtf8String()};
  iso.config().blocklist_dirs =
      std::vector<std::string>{blacklist.ToUtf8String()};
  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());

  EXPECT_TRUE(IsBlocked(store, distrusted));
  EXPECT_TRUE(IsBlocked(store, reissued));
  EXPECT_FALSE(IsBlocked(store, root));
}

// ===========================================================================
// 3. VerifyLinuxPeerCertificateChain
// ===========================================================================

LinuxTrustStore StoreWithAnchor(const TestCertificate& anchor) {
  LinuxTrustStore store;
  store.anchors_pem = anchor.cert_pem();
  store.anchor_count = 1;
  store.anchor_source = "test";
  return store;
}

TEST(GrpcTlsCredentialsProviderLinuxVerifyTest, AcceptsMatchingHostNames) {
  TestPki pki = CreateTestPki("verify-ok", {kHost, "*.wild.firestore.test"},
                              {"127.0.0.1", "::1"});
  LinuxTrustStore store = StoreWithAnchor(pki.root);
  for (const char* target :
       {"loopback.firestore.test", "loopback.firestore.test:443",
        "LOOPBACK.firestore.test", "a.wild.firestore.test", "127.0.0.1",
        "127.0.0.1:50051", "::1", "[::1]", "[::1]:443"}) {
    grpc::Status status =
        VerifyLinuxPeerCertificateChain(pki.ServerChainPem(), target, store);
    EXPECT_TRUE(status.ok())
        << "target: " << target << " error: " << status.error_message();
  }
}

TEST(GrpcTlsCredentialsProviderLinuxVerifyTest, RejectsMismatchedHostNames) {
  TestPki pki = CreateTestPki("verify-mismatch",
                              {kHost, "*.wild.firestore.test"}, {"127.0.0.1"});
  LinuxTrustStore store = StoreWithAnchor(pki.root);
  for (const char* target :
       {"wrong.firestore.test", "wrong.firestore.test:443", "firestore.test",
        "a.b.wild.firestore.test", "wild.firestore.test", "127.0.0.2",
        "[::1]:443", "", ":443", "[::1", "[]"}) {
    grpc::Status status =
        VerifyLinuxPeerCertificateChain(pki.ServerChainPem(), target, store);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << "target: " << target;
  }
}

TEST(GrpcTlsCredentialsProviderLinuxVerifyTest,
     DoesNotFallBackToSubjectCommonName) {
  TestCertificate root = MakeRoot("verify-cn");
  TestCertOptions leaf_opts;
  leaf_opts.common_name = kHost;  // No subjectAltName.
  TestCertificate leaf = IssueTestCertificate(leaf_opts, &root);
  LinuxTrustStore store = StoreWithAnchor(root);
  grpc::Status status =
      VerifyLinuxPeerCertificateChain(leaf.cert_pem(), kHost, store);
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST(GrpcTlsCredentialsProviderLinuxVerifyTest, ChecksHostNameOnLeafOnly) {
  // The intermediate (second) certificate never satisfies the hostname check.
  TestPki pki = CreateTestPki("verify-leaf", {"other.firestore.test"});
  TestCertOptions inter_like;
  inter_like.common_name = "Firestore Linux Test Leafy Intermediate";
  inter_like.is_ca = true;
  inter_like.dns_sans = {kHost};
  TestCertificate inter = IssueTestCertificate(inter_like, &pki.root);
  LinuxTrustStore store = StoreWithAnchor(pki.root);
  grpc::Status status = VerifyLinuxPeerCertificateChain(
      PemChain({&pki.leaf, &inter}), kHost, store);
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST_F(GrpcTlsCredentialsProviderLinuxTest,
       VerifyRejectsBlocklistedChainMember) {
  TestPki pki = CreateTestPki("verify-blocked", {kHost});
  Path anchors = File("anchors.pem", pki.root.cert_pem());
  Path blacklist = Dir("blacklist");

  IsolatedConfig iso;
  iso.config().bundle_files = std::vector<std::string>{anchors.ToUtf8String()};
  iso.config().blocklist_dirs =
      std::vector<std::string>{blacklist.ToUtf8String()};
  ASSERT_TRUE(VerifyLinuxPeerCertificateChain(pki.ServerChainPem(), kHost,
                                              LoadLinuxTrustStore(iso.config()))
                  .ok());

  // Blocklisting the intermediate rejects the chain, including through the
  // cross-signed copy that shares its key.
  WriteFile(blacklist.AppendUtf8("intermediate.pem"),
            pki.intermediate.cert_pem());
  LinuxTrustStore store = LoadLinuxTrustStore(iso.config());
  ASSERT_TRUE(store.has_anchors());
  for (const std::string& chain :
       {pki.ServerChainPem(), PemChain({&pki.leaf, &pki.cross_intermediate})}) {
    grpc::Status status = VerifyLinuxPeerCertificateChain(chain, kHost, store);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  }

  // Blocklisting the leaf itself also rejects.
  Path leaf_blacklist = Dir("leaf_blacklist");
  WriteFile(leaf_blacklist.AppendUtf8("leaf.pem"), pki.leaf.cert_pem());
  iso.config().blocklist_dirs =
      std::vector<std::string>{leaf_blacklist.ToUtf8String()};
  EXPECT_EQ(VerifyLinuxPeerCertificateChain(pki.ServerChainPem(), kHost,
                                            LoadLinuxTrustStore(iso.config()))
                .error_code(),
            grpc::StatusCode::UNAUTHENTICATED);
}

TEST(GrpcTlsCredentialsProviderLinuxVerifyTest, RejectsMalformedChains) {
  TestPki pki = CreateTestPki("verify-malformed", {kHost});
  LinuxTrustStore store = StoreWithAnchor(pki.root);
  for (const std::string& chain :
       {std::string(), std::string("garbage"),
        std::string("-----BEGIN CERTIFICATE-----\nAAAA\n"
                    "-----END CERTIFICATE-----\n")}) {
    grpc::Status status = VerifyLinuxPeerCertificateChain(chain, kHost, store);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << "chain: " << chain;
  }
}

// Corrupts the base64 body of a PEM block without touching its markers.
std::string CorruptBase64(std::string pem) {
  size_t body = pem.find('\n') + 1;
  pem[body + 10] = '!';
  return pem;
}

TEST(GrpcTlsCredentialsProviderLinuxVerifyTest,
     RejectsChainsWithAnyMalformedBlock) {
  // A malformed block must fail the whole chain rather than be skipped:
  // skipping the leaf would hostname-check an intermediate, and skipping an
  // intermediate would bypass the blocklist.
  TestPki pki = CreateTestPki("verify-corrupt", {kHost});
  LinuxTrustStore store = StoreWithAnchor(pki.root);
  ASSERT_TRUE(
      VerifyLinuxPeerCertificateChain(pki.ServerChainPem(), kHost, store).ok());

  const std::string bad_der =
      "-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n";
  const std::vector<std::string> chains = {
      pki.leaf.cert_pem() + CorruptBase64(pki.intermediate.cert_pem()),
      CorruptBase64(pki.intermediate.cert_pem()) + pki.ServerChainPem(),
      pki.leaf.cert_pem() + bad_der,
      bad_der + pki.ServerChainPem(),
      pki.ServerChainPem() + PublicKeyPem(pki.intermediate),
      TrustedCertificatePem(pki.leaf, AuxTrust::kTrustServerAuth) +
          pki.intermediate.cert_pem(),
  };
  for (size_t i = 0; i < chains.size(); ++i) {
    grpc::Status status =
        VerifyLinuxPeerCertificateChain(chains[i], kHost, store);
    EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAUTHENTICATED)
        << "chain " << i;
  }
}

TEST(GrpcTlsCredentialsProviderLinuxVerifyTest, RejectsTrailingDotHostName) {
  // X509_check_host does not strip a trailing root dot, so the fully qualified
  // form fails closed. (gRPC targets never carry one.)
  TestPki pki = CreateTestPki("verify-trailing-dot", {kHost});
  LinuxTrustStore store = StoreWithAnchor(pki.root);
  EXPECT_EQ(VerifyLinuxPeerCertificateChain(pki.ServerChainPem(),
                                            "loopback.firestore.test.", store)
                .error_code(),
            grpc::StatusCode::UNAUTHENTICATED);
}

// ===========================================================================
// 4. End-to-end TLS loopback through CreateLinuxTlsCredentials
// ===========================================================================

class GrpcTlsCredentialsProviderLinuxLoopbackTest
    : public GrpcTlsCredentialsProviderLinuxTest {
 protected:
  // Credentials that trust exactly `anchors` and blocklist `blocked`.
  std::shared_ptr<grpc::ChannelCredentials> Credentials(
      const std::vector<const TestCertificate*>& anchors,
      const std::vector<const TestCertificate*>& blocked = {}) {
    IsolatedConfig iso;
    std::string anchors_pem = PemChain(anchors);
    if (!anchors_pem.empty()) {
      iso.config().ca_path =
          File(absl::StrCat("anchors", ++files_, ".pem"), anchors_pem)
              .ToUtf8String();
    } else {
      iso.config().ca_path = dir_.AppendUtf8("missing.pem").ToUtf8String();
    }
    Path blacklist = Dir(absl::StrCat("blacklist", ++files_));
    for (size_t i = 0; i < blocked.size(); ++i) {
      WriteFile(blacklist.AppendUtf8(absl::StrCat(i, ".pem")),
                blocked[i]->cert_pem());
    }
    iso.config().blocklist_dirs =
        std::vector<std::string>{blacklist.ToUtf8String()};
    return CreateLinuxTlsCredentials(iso.config());
  }

  grpc::Status Echo(const TlsLoopbackServer& server,
                    const std::shared_ptr<grpc::ChannelCredentials>& creds,
                    const std::string& target_name = kHost) {
    std::string response;
    grpc::Status status = tls_testing::PerformUnaryEcho(
        tls_testing::CreateLoopbackChannel(server, creds, target_name), "ping",
        &response);
    if (status.ok()) {
      EXPECT_EQ(response, "ping");
    }
    return status;
  }

  int files_ = 0;
};

TEST_F(GrpcTlsCredentialsProviderLinuxLoopbackTest, AcceptsValidChain) {
  TestPki pki = CreateTestPki("loop-valid", {kHost});
  TlsLoopbackServer server(pki.leaf.private_key_pem(), pki.ServerChainPem());
  ASSERT_TRUE(server.started());
  grpc::Status status = Echo(server, Credentials({&pki.root}));
  EXPECT_TRUE(status.ok()) << status.error_message();
}

TEST_F(GrpcTlsCredentialsProviderLinuxLoopbackTest,
       AcceptsCrossSignedAlternatePath) {
  TestPki pki = CreateTestPki("loop-cross", {kHost});
  TlsLoopbackServer server(pki.leaf.private_key_pem(),
                           PemChain({&pki.leaf, &pki.cross_intermediate}));
  ASSERT_TRUE(server.started());
  grpc::Status status = Echo(server, Credentials({&pki.cross_root}));
  EXPECT_TRUE(status.ok()) << status.error_message();
}

TEST_F(GrpcTlsCredentialsProviderLinuxLoopbackTest, RejectsUntrustedRoot) {
  TestPki pki = CreateTestPki("loop-untrusted", {kHost});
  TestCertificate other = MakeRoot("loop-untrusted-other");
  TlsLoopbackServer server(pki.leaf.private_key_pem(), pki.ServerChainPem());
  ASSERT_TRUE(server.started());
  ASSERT_TRUE(Echo(server, Credentials({&pki.root})).ok());
  EXPECT_FALSE(Echo(server, Credentials({&other})).ok());
}

TEST_F(GrpcTlsCredentialsProviderLinuxLoopbackTest,
       RejectsBlocklistedIntermediateUnderTrustedRoot) {
  // The eMudhra case: the root stays trusted, but a distrusted intermediate
  // must not be accepted beneath it.
  TestPki pki = CreateTestPki("loop-blocked", {kHost});
  TlsLoopbackServer server(pki.leaf.private_key_pem(), pki.ServerChainPem());
  ASSERT_TRUE(server.started());
  ASSERT_TRUE(Echo(server, Credentials({&pki.root})).ok());
  EXPECT_FALSE(
      Echo(server, Credentials({&pki.root}, {&pki.intermediate})).ok());
}

TEST_F(GrpcTlsCredentialsProviderLinuxLoopbackTest, RejectsWrongHostName) {
  // Guards against losing gRPC's hostname check: installing a custom
  // certificate verifier replaces gRPC's default hostname verifier, and the
  // target name override bypasses gRPC's per-call host check.
  TestPki pki = CreateTestPki("loop-hostname", {kHost});
  TlsLoopbackServer server(pki.leaf.private_key_pem(), pki.ServerChainPem());
  ASSERT_TRUE(server.started());
  auto creds = Credentials({&pki.root});
  ASSERT_TRUE(Echo(server, creds, kHost).ok());
  EXPECT_FALSE(Echo(server, creds, "wrong.firestore.test").ok());
}

TEST_F(GrpcTlsCredentialsProviderLinuxLoopbackTest, RejectsExpiredLeaf) {
  TestPki pki = CreateTestPki("loop-expired", {kHost});
  TlsLoopbackServer valid_server(pki.leaf.private_key_pem(),
                                 pki.ServerChainPem());
  ASSERT_TRUE(valid_server.started());
  TlsLoopbackServer server(pki.expired_leaf.private_key_pem(),
                           pki.ExpiredServerChainPem());
  ASSERT_TRUE(server.started());
  auto creds = Credentials({&pki.root});
  ASSERT_TRUE(Echo(valid_server, creds).ok());
  EXPECT_FALSE(Echo(server, creds).ok());
}

TEST_F(GrpcTlsCredentialsProviderLinuxLoopbackTest, FailsWithoutAnchors) {
  TestPki pki = CreateTestPki("loop-no-anchors", {kHost});
  TlsLoopbackServer server(pki.leaf.private_key_pem(), pki.ServerChainPem());
  ASSERT_TRUE(server.started());
  grpc::Status status = Echo(server, Credentials({}));
  EXPECT_FALSE(status.ok());
  EXPECT_EQ(status.error_code(), grpc::StatusCode::UNAVAILABLE)
      << status.error_message();
  // The verifier's actionable message reaches the RPC status, which tells
  // this failure apart from any other handshake failure.
  EXPECT_NE(status.error_message().find("No trusted CA certificates"),
            std::string::npos)
      << status.error_message();
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // !defined(__APPLE__) && !defined(_WIN32)
