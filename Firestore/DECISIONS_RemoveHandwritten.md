# Decisions: Removing Handwritten String-Parsing Functions

This file documents the scope, structure, and design decisions made while
researching and authoring the report on removing custom hostname/URI and
PEM/Base64 string-parsing functions from
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
in upstream PR `#16946`.

---

## 1. Scope of Custom Parsing and Encoding Code to Address

### Context

In upstream PR `#16946`, the production file
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
contains ~310 lines of custom hostname/URI and PEM/Base64 string parsing across
[`IsAsciiDigit`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`IsIpv6AddressChar`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`IsValidUnbracketedIpv6Literal`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`IsBase64Alphabet`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`IsStrictStandardBase64`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`StripTrailingHorizontalWhitespace`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
and
[`ParsePemCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm).
Alongside the production code, the test file
[`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
also includes ~450 lines of hand-rolled ASN.1 DER, X.509v3, and PKCS#8 encoding
helpers (such as
[`DerTlv`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm),
[`EncodePkcs8EcPrivateKeyPem`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm),
and
[`BuildCertificateChainFixture`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm))
used to synthesize test certificates at runtime. Because both files introduce
low-level cryptographic/networking byte-manipulation logic into Firestore, the
report could either focus strictly on removing the production string parsers or
also address replacing the custom ASN.1/PEM construction in the unit tests.

### Question

Should the report focus exclusively on removing the custom string-parsing logic
in production
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
or should it also include recommendations for eliminating the custom ASN.1 DER /
PEM generation logic in
[`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)?

### Options Presented

* **Option 1: ProductionOnly** (Recommended) — Focus the 3–5 proposals strictly
  on eliminating the hostname/URI and PEM/Base64 parsing functions in
  production
  [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
  (and deleting their corresponding parser unit tests), keeping the report
  tightly aligned with production attack surface and maintenance risk.
* **Option 2: ProductionAndTests** — Cover the 3–5 ways to remove the
  production string parsing in
  [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
  and also include a section on replacing the hand-rolled ASN.1 DER / PKCS#8
  certificate-builder code in
  [`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
  (e.g., using BoringSSL's `X509` APIs or pre-generated test fixtures).

### Selection

**Option 1: ProductionOnly** — Focused the report exclusively on removing the
8 handwritten string-parsing functions in production
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm).

---

## 2. Architectural Range of the Proposals

### Context

Eliminating the custom string parsing in
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
can be approached either strictly within PR `#16946`'s existing
[`CreatePlatformGrpcSslCredentials`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
/
[`ExternalCertificateVerifier`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
boundary, or by also considering architectural changes outside that file. Within
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
we can immediately remove the custom parsers by delegating PEM decoding to
BoringSSL (`PEM_read_bio_X509` / `i2d_X509`) or Foundation (`NSData`), and by
delegating hostname handling to gRPC (`check_call_host` / `SplitHostPort` with
`SecPolicyCreateSSL(true, nullptr)` as in Envoy Mobile) or `NSURLComponents` (as
in `iRPC`). Beyond that single file, `google3` prior art also illustrates
approaches that avoid `ExternalCertificateVerifier`'s PEM string round-trip
altogether, such as upstreaming native `SecTrust` / raw-DER peer certificate
exposure into `gRPC-Core`, feeding Keychain trust anchors into
`grpc::SslCredentials`, or using an Apple-native TLS transport
(`Network.framework` / `NSURLSession`).

### Question

What architectural range should the 3–5 proposals in the report cover?

### Options Presented

* **Option 1: Spectrum** (Recommended) — Present 3–5 solutions that prioritize
  immediate, drop-in replacements for
  [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
  in PR `#16946` (delegating to BoringSSL, gRPC, and Apple OS APIs), while also
  including 1–2 architectural alternatives that avoid the
  `ExternalCertificateVerifier` PEM string round-trip altogether.
* **Option 2: DropIn** — Restrict all 3–5 proposals strictly to drop-in changes
  inside
  [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
  (and Firestore's build files) that can land directly in PR `#16946` today
  without upstream `gRPC` changes or transport replacements.
* **Option 3: Architectural** — Focus primarily on higher-level transport and
  `gRPC-Core` integration architectures that bypass
  `ExternalCertificateVerifier` string serialization entirely, treating
  in-place parser delegation as a single baseline option.

### Selection

**Option 1: Spectrum (excluding upstream `gRPC-Core` modifications)** — Cover
both drop-in replacements in
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
and higher-level architectural alternatives in Firestore, while explicitly
excluding upstream changes to `gRPC-Core` as out of scope.

---

## 3. Report Organization Across Parsing Responsibilities

### Context

The 8 custom string-parsing functions in
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
split cleanly into two independent halves: hostname/URI extraction
([`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`IsAsciiDigit`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`IsIpv6AddressChar`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
and
[`IsValidUnbracketedIpv6Literal`](core/src/remote/grpc_tls_credentials_provider_apple.mm))
and PEM/Base64 certificate chain decoding
([`ParsePemCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`IsBase64Alphabet`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`IsStrictStandardBase64`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
and
[`StripTrailingHorizontalWhitespace`](core/src/remote/grpc_tls_credentials_provider_apple.mm)).
For the drop-in approaches, techniques for the hostname half (such as
delegating SAN matching to gRPC/BoringSSL with
`SecPolicyCreateSSL(true, nullptr)` like Envoy Mobile, or parsing with
`NSURLComponents` like `iRPC`) can be freely combined with techniques for the
PEM half (such as BoringSSL's `PEM_read_bio_X509` or Foundation's `NSData` /
`SecItemImport`). Meanwhile, higher-level architectural approaches (such as
feeding system/keychain anchors into `grpc::SslCredentials` or using an
Apple-native TLS transport) replace both halves at once.

### Question

How should the report structure the 3–5 proposals across these two parsing
responsibilities?

### Options Presented

* **Option 1: EndToEnd** (Recommended) — Present 4–5 complete, self-contained
  approaches where each approach eliminates all 8 parsing functions (pairing a
  concrete hostname solution with a concrete PEM solution, or bypassing both
  architecturally), plus a brief mix-and-match matrix showing how the drop-in
  hostname and PEM pieces can be recombined.
* **Option 2: ByResponsibility** — Divide the report into three sections—(A)
  ways to eliminate hostname/URI parsing, (B) ways to eliminate PEM/Base64
  parsing, and (C) architectural ways to avoid `ExternalCertificateVerifier`
  parsing altogether—concluding with a recommended end-to-end combination.

### Selection

**Option 2: ByResponsibility** — Structure the report into three sections by
responsibility: (A) Hostname/URI Parsing Elimination, (B) PEM/Base64 Chain
Parsing Elimination, and (C) Architectural Alternatives Avoiding
`ExternalCertificateVerifier` Parsing, followed by a recommended end-to-end
combination.

---

## 4. Hostname Verification Philosophy in the Recommended Combination (Initial Question)

### Context

For **Section A (Hostname/URI Parsing Elimination)**, `google3` prior art
highlights two distinct zero-parser philosophies for handling the target
hostname in
[`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm).
In the **Envoy Mobile** approach (`apple_platform_cert_verifier.cc`), the
verifier passes `nullptr` as the hostname to
`SecPolicyCreateSSL(/*server=*/true, nullptr)` so `SecTrust` validates X.509
chain signatures, validity periods, BasicConstraints/EKU, system/MDM roots, and
`trustd` revocations, while delegating RFC 6125 DNS/IP SAN matching entirely to
gRPC/BoringSSL (`check_call_host(true)` / `grpc_ssl_host_matches_name`). In the
**iRPC / Dual-Enforcement** approach (`ChannelTransport Security.swift`),
`SecPolicyCreateSSL(/*server=*/true, cf_host)` continues to enforce Apple's own
hostname/SAN policy in addition to gRPC's check, and
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
is replaced by delegating host extraction to `NSURLComponents` or gRPC's
`TlsChannelSecurityConnector` (which already strips schemes and calls
`SplitHostPort` before populating `request->target_name()`).

### Question

While the report will cover both approaches in Section A, which hostname
verification philosophy should the report's recommended end-to-end combination
favor?

### Options Presented

* **Option 1: DualEnforcement** (Recommended) — Keep
  `SecPolicyCreateSSL(/*server=*/true, cf_host)` as a defense-in-depth
  hostname/SAN check inside `SecTrust` (alongside gRPC's
  `check_call_host(true)`), and eliminate
  [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
  by delegating host parsing to Foundation's `NSURLComponents` or gRPC's
  pre-split `target_name()`.
* **Option 2: DelegateHostname** — Recommend Envoy Mobile's split where
  `SecPolicyCreateSSL(/*server=*/true, nullptr)` evaluates the X.509 chain and
  trust store with zero hostname string handling in Firestore, and
  gRPC/BoringSSL (`check_call_host(true)` + `HostNameCertificateVerifier`)
  serves as the single authority for DNS/IP SAN matching.

### Selection

Deferred pending security comparison — requested a detailed analysis of the
pros and cons of gRPC/BoringSSL hostname/SAN checking vs. Apple's `SecTrust`
(prioritizing security first, and code complexity / maintenance burden second),
followed by the interaction between `SecTrust` and `check_call_host(true)`
(resolved in Section 5).

---

## 5. `SecTrust` Hostname Verification and `check_call_host(true)` Interaction (Follow-Up Question)

### Context

Inspecting `gRPC-Core`'s hostname matchers (`SslCheckCallHost` ->
`grpc_ssl_host_matches_name` -> `tsi_ssl_peer_matches_name` in `ssl_utils.cc`
and `ssl_transport_security.cc`, plus `HostNameCertificateVerifier::Verify` in
`grpc_tls_certificate_verifier.cc`) revealed five security advantages of
keeping `SecPolicyCreateSSL(/*server=*/true, cf_host)` over delegating solely
to gRPC:

1. **`ssl_target_name_override` Bypass Risk**: `SslCheckCallHost` skips
   `grpc_ssl_host_matches_name` whenever `overridden_target_name` is non-empty
   and `host == target_name`, assuming the handshake verifier already checked
   `overridden_target_name`. Passing `nullptr` to `SecPolicyCreateSSL` without
   chaining `HostNameCertificateVerifier` bypasses hostname checks when target
   name overrides are used.
2. **Legacy Subject `CN` Fallback**: Both `tsi_ssl_peer_matches_name` and
   `HostNameCertificateVerifier` fall back to matching Subject Common Name
   (`CN`) when no `dNSName` SAN is present, whereas `SecPolicyCreateSSL`
   enforces RFC 9525 §6.3 / Apple HT210176 by requiring a `SubjectAltName`
   extension.
3. **SAN Type Confusion**: `add_subject_alt_names_properties_to_peer` copies
   `GEN_DNS`, `GEN_EMAIL`, and `GEN_URI` into the same
   `TSI_X509_SUBJECT_ALTERNATIVE_NAME_PEER_PROPERTY` bucket, which
   `tsi_ssl_peer_matches_name` matches indistinguishably, whereas `SecTrust`
   strictly separates `dNSName` and `iPAddress` SANs.
4. **Public Suffix List (PSL) Wildcards**: `SecTrust` rejects wildcards covering
   multi-label public suffixes (e.g., `*.co.uk`), whereas gRPC only checks that
   the wildcard suffix contains at least one dot.
5. **IPv6 Canonicalization**: `SecTrust` parses IPv6 targets into 16-byte octets
   before matching `iPAddress` SANs, whereas gRPC compares `target_host` against
   `inet_ntop` output via raw string equality (`==`).

Further inspection of `TlsChannelSecurityConnector::check_peer` and
`ClientAuthFilter::Call::OnClientInitialMetadata` showed that `SecTrust` (which
runs once per TLS handshake on the channel target name) and
`check_call_host(true)` (which runs per RPC on the HTTP/2 `:authority` header
right before `GetCallCredsMetadata` attaches Firebase Auth / AppCheck bearer
tokens) are independent hooks. Keeping `check_call_host(true)` alongside
`SecPolicyCreateSSL(true, cf_host)` protects per-RPC `:authority` overrides and
requires zero configuration code (avoiding the deprecated
`set_check_call_host` setter), with the sole tradeoff that `SslCheckCallHost`'s
raw string comparison can reject non-canonical IPv6 literals.

### Question

In light of this interaction between handshake-time
`SecPolicyCreateSSL(true, cf_host)` and per-RPC `check_call_host`, what should
the report recommend for **Section A (Hostname/URI Parsing Elimination)**?

### Options Presented

* **Option 1: KeepBoth** (Recommended) — Recommend
  `SecPolicyCreateSSL(/*server=*/true, cf_host)` for the handshake check
  (eliminating
  [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
  via `NSURLComponents` or `grpc_core::SplitHostPort`) while leaving
  `check_call_host` at its default (`true`) so per-RPC `:authority` checks
  remain active before bearer credentials are sent, and document the
  non-canonical IPv6 nuance.
* **Option 2: SecTrustOnly** — Recommend
  `SecPolicyCreateSSL(/*server=*/true, cf_host)` for the handshake check (using
  `NSURLComponents` or `grpc_core::SplitHostPort`) and explicitly call
  `options.set_check_call_host(false)` so `SecTrust` is the sole hostname/IP
  verifier and non-canonical IPv6 literals are not rejected by
  `SslCheckCallHost`.
* **Option 3: DelegateToGrpc** — Recommend
  `SecPolicyCreateSSL(/*server=*/true, nullptr)` with
  `HostNameCertificateVerifier` + `check_call_host(true)` (the Envoy Mobile
  pattern), trading `SecTrust`'s stricter RFC 9525 / PSL hostname checks for
  zero hostname handling in `SecTrust`.

### Selection

**Option 1: KeepBoth** — Recommend keeping
`SecPolicyCreateSSL(/*server=*/true, cf_host)` (with host extraction delegated
to `NSURLComponents` or gRPC's `SplitHostPort`) alongside gRPC's default
`check_call_host(true)`, while documenting the non-canonical IPv6 nuance and
comparing the alternative options in Section A.

---

## 6. PEM/Base64 Certificate Chain Decoding Strategy (Initial Question)

### Context

For **Section B (PEM/Base64 Certificate Chain Parsing Elimination)**,
`request->peer_cert_full_chain()` is produced inside
`tsi_ssl_get_cert_chain_contents` (`ssl_transport_security.cc`), where
BoringSSL has already parsed the wire TLS `Certificate` message into `X509*`
structures and serialized them into canonical PEM via `PEM_write_bio_X509`. To
turn that string back into `SecCertificateRef` objects without custom
Base64/whitespace parsers, the two main drop-in candidates have different
build-system footprints. Delegating to **BoringSSL (`BIO_new_mem_buf` +
`PEM_read_bio_X509` + `i2d_X509`)** uses the exact C library that wrote the PEM
string with zero delimiter searching in Firestore, but requires adding an
explicit dependency on `BoringSSL-GRPC` / `openssl_grpc` to
[`FirebaseFirestoreInternal.podspec`](../FirebaseFirestoreInternal.podspec),
[`Package.swift`](../Package.swift), and
[`Firestore/core/CMakeLists.txt`](core/CMakeLists.txt) so
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
can include `<openssl/pem.h>`. Alternatively, delegating Base64 decoding to
**Apple's `Foundation` (`NSData` + `NSScanner`)** requires **zero** build-system
or podspec changes while still eliminating
[`IsBase64Alphabet`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`IsStrictStandardBase64`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
[`StripTrailingHorizontalWhitespace`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
and the line-by-line state machine.

### Question

While the report will analyze both in Section B (along with `SecItemImport` on
macOS), how do you weigh adding a direct `BoringSSL-GRPC` / `openssl_grpc`
build dependency in Firestore's podspec/SwiftPM/CMake files versus keeping zero
new build dependencies with Foundation's `NSData` Base64 decoder?

### Options Presented

* **Option 1: FoundationNoDeps** (Recommended) — Favor the Foundation `NSData`
  / `NSScanner` approach in the final recommendation so PR `#16946` eliminates
  all custom Base64/whitespace parsing with zero changes to
  [`FirebaseFirestoreInternal.podspec`](../FirebaseFirestoreInternal.podspec),
  [`Package.swift`](../Package.swift), or
  [`Firestore/core/CMakeLists.txt`](core/CMakeLists.txt), while presenting
  BoringSSL `PEM_read_bio_X509` as the runner-up if direct `BoringSSL-GRPC`
  header access is desired.
* **Option 2: BoringSslDep** — Favor adding the `BoringSSL-GRPC` /
  `openssl_grpc` build dependency so
  [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
  can call `PEM_read_bio_X509` and `i2d_X509` directly without any PEM
  header/footer string scanning at all.

### Selection

Deferred pending security, code complexity, and maintenance comparison between
Foundation (`NSScanner` + `NSData`) and BoringSSL (`PEM_read_bio_X509`)
(resolved in Section 7).

---

## 7. Security, Complexity, and Maintenance Comparison of Foundation vs. BoringSSL PEM Decoding (Follow-Up Question)

### Context

Inspecting BoringSSL's PEM implementation in `crypto/pem/pem_lib.cc` and
`crypto/pem/pem_oth.cc` revealed a notable security and behavioral difference
when compared against Foundation's `NSScanner` + `NSData`:

1. **Security (Top Metric)**:
   * **Fail-Closed on Trailing/Corrupted Blocks**: In `pem_lib.cc:571-598`,
     `PEM_read_bio` silently skips arbitrary lines before `-----BEGIN `, and
     when reading a multi-certificate chain in a loop, returns
     `PEM_R_NO_START_LINE` both on clean EOF and when a trailing block is
     missing its `-----BEGIN ` line—causing a naive `PEM_read_bio_X509` loop to
     silently drop a corrupted trailing certificate instead of rejecting the
     chain. Furthermore, `PEM_bytes_read_bio` (`pem_lib.cc:182-197`) silently
     skips non-`CERTIFICATE` PEM blocks (e.g., `PRIVATE KEY`). By contrast, a
     short `NSScanner` loop over `-----BEGIN CERTIFICATE-----` and
     `-----END CERTIFICATE-----` can trivially assert that only whitespace
     exists outside certificate blocks, failing closed on any extraneous data
     or non-certificate block.
   * **Strict RFC 4648 Base64**: Rather than passing
     `NSDataBase64DecodingIgnoreUnknownCharacters` (which ignores arbitrary
     non-Base64 symbols), stripping ASCII whitespace via
     `NSCharacterSet.whitespaceAndNewlineCharacterSet` and calling
     `[[NSData alloc] initWithBase64EncodedString:body options:0]` enforces
     strict RFC 4648 Base64 alphabet and `=` padding in OS code.
2. **Code Complexity (Secondary Metric)**:
   * Foundation (`NSScanner` + `NSCharacterSet` + `NSData` with `options:0`) is
     ~25 lines of ARC-managed Objective-C in
     [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
     whereas BoringSSL (`BIO_new_mem_buf` + `PEM_read_bio_X509` + `i2d_X509`)
     requires ~30–40 lines of C/C++ with manual `BIO_free`, `X509_free`,
     `OPENSSL_free`, and `ERR_clear_error()` cleanup plus extra checks to avoid
     silent block skipping.
3. **Maintenance Burden (Tertiary Metric)**:
   * Foundation requires **zero** build-system changes across
     [`Package.swift`](../Package.swift),
     [`FirebaseFirestoreInternal.podspec`](../FirebaseFirestoreInternal.podspec),
     and [`Firestore/core/CMakeLists.txt`](core/CMakeLists.txt), whereas
     BoringSSL requires exposing `BoringSSL-GRPC` / `openssl_grpc` headers and
     keeping version pins synchronized with `gRPC-Core`.

### Question

Given that Foundation's `NSScanner` + strict `NSData` (`options:0`) is
fail-closed against trailing/non-certificate blocks (unlike BoringSSL's
`PEM_read_bio_X509`), avoids manual C memory/error-queue management, and
requires zero build-system dependencies, which PEM-decoding approach should the
report's recommended combination favor for **Section B**?

### Options Presented

* **Option 1: FoundationNoDeps** (Recommended) — Recommend replacing the custom
  Base64/whitespace parser with Foundation's `NSScanner`,
  `NSCharacterSet.whitespaceAndNewlineCharacterSet`, and strict
  `[[NSData alloc] initWithBase64EncodedString:options:0]` (with zero
  build-system changes), while documenting BoringSSL's `PEM_read_bio_X509` (and
  its `PEM_R_NO_START_LINE` truncation pitfall) and macOS's `SecItemImport` as
  alternatives in Section B.
* **Option 2: BoringSslDep** — Recommend adding the `BoringSSL-GRPC` /
  `openssl_grpc` dependency and using `BIO_new_mem_buf` + `PEM_read_bio` /
  `PEM_read_bio_X509` + `i2d_X509` as the primary choice for Section B, with
  Foundation `NSData` as the alternative.

### Selection

**Option 1: FoundationNoDeps** — Recommend Foundation's `NSScanner` +
`NSCharacterSet.whitespaceAndNewlineCharacterSet` + strict
`[[NSData alloc] initWithBase64EncodedString:options:0]` as the primary choice
for Section B, while also detailing BoringSSL `PEM_read_bio_X509` and macOS
`SecItemImport` as alternatives.


