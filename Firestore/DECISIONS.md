# Decisions

This file documents the architectural, security, testing, and release decisions
made when migrating Firestore's gRPC TLS server certificate verification on
Apple platforms from an embedded root certificate bundle to Apple's
`Security.framework` (`SecTrust`).

---

## 1. Platform Seam for Default TLS Channel Credentials

### Context

[`GrpcConnection::CreateChannel`](core/src/remote/grpc_connection.cc)
previously called
[`LoadGrpcRootCertificate`](core/src/remote/grpc_root_certificate_finder.h) and
passed that static PEM bundle into `CreateSslCredentials`. Because Apple builds
now return `grpc::experimental::TlsCredentials` backed by a
`Security.framework` verifier (`.mm`) while non-Apple CMake builds
(Linux/Windows) continue returning `grpc::ChannelCredentials` from the embedded
bundle until their own native trust stores are added later, there were two ways
to structure this platform boundary.

### Question

How should we structure the platform seam for default TLS channel credentials
in [`Firestore/core/src/remote`](core/src/remote)?

### Options Presented

* **Provider** (Recommended) — Replace direct `LoadGrpcRootCertificate` usage
  in `GrpcConnection::CreateChannel` with a link-time platform factory (e.g.,
  [`CreateDefaultTlsCredentials()`](core/src/remote/grpc_tls_credentials_provider.h),
  implemented in an `*_apple.mm` file on Apple and a default `.cc` file on
  non-Apple), matching
  [`ConnectivityMonitor::Create`](core/src/remote/connectivity_monitor_apple.mm),
  keeping `#if __APPLE__` out of
  [`grpc_connection.cc`](core/src/remote/grpc_connection.cc), and giving future
  Linux/Windows native-trust implementations a clean drop-in seam.
* **Conditional** — Branch with `#if defined(__APPLE__)` directly inside
  `GrpcConnection::CreateChannel` to call an Apple-only helper from a `.mm`
  file and keep `LoadGrpcRootCertificate` in `#else`, requiring one fewer
  non-Apple `.cc` file in the `exclude_files` lists of
  [`FirebaseFirestoreInternal.podspec`](../FirebaseFirestoreInternal.podspec)
  and [`Package.swift`](../Package.swift) at the cost of platform `#ifdef`s in
  [`grpc_connection.cc`](core/src/remote/grpc_connection.cc).

### Selection

**Provider** — Implemented via
[`grpc_tls_credentials_provider.h`](core/src/remote/grpc_tls_credentials_provider.h),
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
and
[`grpc_tls_credentials_provider_embedded.cc`](core/src/remote/grpc_tls_credentials_provider_embedded.cc).

---

## 2. `GrpcConnection::UseTestCertificate()` on Apple Platforms (Initial Question)

### Context

In `GrpcConnection::CreateChannel`, `GrpcConnection::UseTestCertificate`
previously loaded a custom root PEM file into `CreateSslCredentials`, and the
initial design exploration noted leaving that test override on
`grpc::SslCredentials`. Codebase inspection showed zero callers or certificate
fixtures using `GrpcConnection::UseTestCertificate` anywhere in
`firebase-ios-sdk`. Routing custom test root PEMs on Apple through the new
provider (`SecTrustSetAnchorCertificates` +
`SecTrustSetAnchorCertificatesOnly`) would let `GrpcConnection` TLS loopback
tests exercise the production `grpc::experimental::TlsCredentials` + `SecTrust`
pipeline end-to-end, whereas keeping `grpc::SslCredentials` would avoid Apple
`SecTrust`'s stricter X.509 requirements (such as Subject Alternative Names and
leaf validity limits) if external C++/Unity tests ever passed legacy test certs
on macOS.

### Question

How should `GrpcConnection::UseTestCertificate` behave on Apple platforms?

### Options Presented

* **Unified** (Recommended) — Route `GrpcConnection::UseTestCertificate`
  through the same Apple `SecTrust` verifier using custom anchor certificates
  (`SecTrustSetAnchorCertificates` +
  `SecTrustSetAnchorCertificatesOnly(trust, true)`), unifying all Apple TLS
  channel creation onto one code path and allowing `GrpcConnection` tests to
  validate the real `SecTrust` handshake end-to-end.
* **Legacy** — Keep `GrpcConnection::UseTestCertificate` on
  `grpc::SslCredentials` so custom test PEMs continue to be verified by
  BoringSSL, and test the Apple `SecTrust` verifier via its own dedicated
  channel/verifier tests.

### Selection

Deferred pending historical investigation — requested background on why
`GrpcConnection::UseTestCertificate()` existed, whether it was used anywhere
across Firebase repositories, and whether it could be eliminated completely
(resolved in Section 3).

---

## 3. Eliminating `GrpcConnection::UseTestCertificate()` (Follow-Up Question)

### Context

Git history showed `GrpcConnection::UseTestCertificate` was added in 2018
solely to let integration tests talk to **Hexa**, an internal test server on
`localhost:8081` that used a self-signed certificate (`CAcert.pem` with target
name `"test_cert_2"`). In October 2020 (commit `ad2fed148` / PR `#6852`), Hexa
support and its sole call site in
[`FSTIntegrationTestCase.mm`](Example/Tests/Util/FSTIntegrationTestCase.mm)
were deleted in favor of the local Firestore Emulator (`localhost:8080` with
`sslEnabled = false`, which uses `GrpcConnection::UseInsecureChannel`).
Checking `firebase-ios-sdk`, `firebase-cpp-sdk`, `firebase-unity-sdk`, and the
quickstart repositories confirmed **zero callers** anywhere, and
[`grpc_connection.h`](core/src/remote/grpc_connection.h) is an internal C++
header rather than public SDK API.

### Question

How would you like to handle `GrpcConnection::UseTestCertificate()`?

### Options Presented

* **Option 1: Remove** (Recommended) — Delete the dead
  `GrpcConnection::UseTestCertificate` method and simplify `HostConfig` in a
  clean standalone commit, and instead accept optional custom anchor
  certificates directly on the internal Apple `SecTrust` verifier/credentials
  helper for unit and local gRPC TLS loopback tests.
* **Option 2: Unified** — Keep `GrpcConnection::UseTestCertificate` and route
  it through the new `Provider` seam (using `SecTrustSetAnchorCertificates` +
  `SecTrustSetAnchorCertificatesOnly` on Apple) so tests can also drive
  `GrpcConnection` itself against a local self-signed TLS server.
* **Option 3: Legacy** — Keep `GrpcConnection::UseTestCertificate` untouched on
  `grpc::SslCredentials` as it existed previously.

### Selection

**Option 1: Remove** — Removed `GrpcConnection::UseTestCertificate()`,
`HostConfig`, and `HostConfigMap` from
[`grpc_connection.h`](core/src/remote/grpc_connection.h) and
[`grpc_connection.cc`](core/src/remote/grpc_connection.cc), and added optional
`CFArrayRef anchor_certs` parameters on the internal Apple helpers in
[`grpc_tls_credentials_provider_apple.h`](core/src/remote/grpc_tls_credentials_provider_apple.h).

---

## 4. `SecTrust` Policy Configuration

### Context

Evaluating `SecTrustCreateWithCertificates` with only `SecPolicyCreateSSL` was
compared against attaching an explicit revocation policy via
`SecPolicyCreateRevocation` with `kSecRevocationNetworkAccessDisabled` or
disabling network fetches via `SecTrustSetNetworkFetchAllowed(trust, false)`.
Inspecting Apple's `SecPolicy.h` and `SecTrust.h` headers confirmed that
`SecPolicyCreateSSL` already enforces Apple's `Valid` Over-The-Air (`trustd`)
distrust database and default system revocation policies (matching
`URLSession`), while also allowing `trustd` to fetch a missing intermediate CA
via Authority Information Access (AIA) if a custom
[`FIRFirestoreSettings.host`](Source/Public/FirebaseFirestore/FIRFirestoreSettings.h)
server sends an incomplete chain. Adding `kSecRevocationNetworkAccessDisabled`
(or calling `SecTrustSetNetworkFetchAllowed` with `false`) suppresses all
`trustd` network access, including missing-intermediate AIA recovery.

### Question

Which `SecTrust` policy configuration should we use?

### Options Presented

* **Option 1: Default** (Recommended) — Pass only `SecPolicyCreateSSL`,
  matching `URLSession` and Apple's header guidance so `trustd` enforces
  `Valid` OTA revocations, Certificate Transparency, and missing-intermediate
  AIA recovery identically to the rest of `firebase-ios-sdk`.
* **Option 2: Cached** — Attach `SecPolicyCreateRevocation` with
  `kSecRevocationUseAnyAvailableMethod | kSecRevocationNetworkAccessDisabled`
  alongside `SecPolicyCreateSSL`, explicitly consulting `trustd`'s local
  OCSP/CRL cache with zero network access at the cost of disabling `trustd`
  missing-intermediate AIA fetching for misconfigured custom hosts.
* **Option 3: Strict** — Pass only `SecPolicyCreateSSL` and call
  `SecTrustSetNetworkFetchAllowed` with `false`, keeping default revocation
  evaluation while disallowing any `trustd` missing-intermediate network
  fetches.

### Selection

**Option 1: Default** — Passed `SecPolicyCreateSSL(/*server=*/true, cf_host)`
directly to `SecTrustCreateWithCertificates` in
[`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm).

---

## 5. `ExternalCertificateVerifier::Verify` Execution Mode

### Context

In `grpc::experimental::ExternalCertificateVerifier::Verify`, gRPC allows
verifiers to run either synchronously (`return true`) or asynchronously
(`return false`, invoking `callback` on another thread and supporting
`ExternalCertificateVerifier::Cancel`). Because **Default** allows `trustd` IPC
and missing-intermediate AIA network fetches, Apple also provides
`SecTrustEvaluateAsyncWithError` (available on iOS 13+ / macOS 10.15+), which
performs non-blocking XPC to `trustd` without tying up a GCD worker thread
while waiting on `trustd` or AIA I/O.

### Question

How should `ExternalCertificateVerifier::Verify` execute the `SecTrust`
evaluation?

### Options Presented

* **Option 1: AsyncXPC** (Recommended) — Return `false` from
  `ExternalCertificateVerifier::Verify`, `dispatch_async` onto a dedicated
  serial GCD queue, and call `SecTrustEvaluateAsyncWithError` so neither gRPC's
  EventEngine threads nor GCD worker threads block during `trustd` IPC or AIA
  fetches.
* **Option 2: AsyncBlocking** — Return `false` from
  `ExternalCertificateVerifier::Verify`, `dispatch_async` onto a concurrent GCD
  queue, and call synchronous `SecTrustEvaluateWithError`, trading simpler
  straight-line code for occupying a GCD thread per active handshake.
* **Option 3: Synchronous** — Call `SecTrustEvaluateWithError` inline inside
  `ExternalCertificateVerifier::Verify` and return `true`, avoiding async
  dispatch and cancellation tracking entirely at the cost of blocking gRPC's
  EventEngine thread during `trustd` IPC/AIA fetches.

### Selection

**Option 3: Synchronous (with `TODO` comment)** — Selected synchronous inline
execution via `SecTrustEvaluateWithError` (`return true` and no-op `Cancel()`),
with a prominent `TODO` comment in
[`AppleSecTrustCertificateVerifier::Verify`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
to convert to `SecTrustEvaluateAsyncWithError` or background queue dispatch so
`trustd` IPC cannot block gRPC's EventEngine threads.

---

## 6. `TlsCredentialsOptions::set_check_call_host` Configuration

### Context

In `grpcpp/security/tls_credentials_options.h`, gRPC enables `check_call_host`
by default, which runs BoringSSL's hostname matcher on every RPC call even
after `ExternalCertificateVerifier` validates the hostname during the handshake
via `SecPolicyCreateSSL`. Notably, gRPC's doc comment on
`TlsCredentialsOptions::set_check_call_host` gives conflicting signals: it
states *"This should be disabled if verifiers other than the host name verifier
is used"*, directly above *"Deprecated: This function will be removed in the
1.66 release"* (even though it remains present without a `[[deprecated]]`
attribute across gRPC `1.69.0` through `1.84.1+`).

### Question

How should we configure `TlsCredentialsOptions::set_check_call_host`?

### Options Presented

* **Option 1: Keep** (Recommended) — Leave `check_call_host` at gRPC's default
  (`true`) without calling `TlsCredentialsOptions::set_check_call_host`,
  avoiding any reliance on a doc-deprecated setter while keeping
  defense-in-depth hostname verification on every call.
* **Option 2: Disable** — Call `options.set_check_call_host(false)` so
  `SecPolicyCreateSSL` is the single source of truth for hostname/IP matching
  and gRPC skips redundant per-RPC checks, accepting the risk of removing that
  line if a future gRPC upgrade finally drops the setter.

### Selection

**Option 2: Disable (with inline rationale & deprecation note)** — Disabled
`check_call_host` via `options.set_check_call_host(false)` in
[`CreateAppleTlsCredentials`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
with a detailed inline comment explaining both why BoringSSL's per-RPC check is
redundant with `SecPolicyCreateSSL` and the uncertainty around gRPC's `1.66`
deprecation doc comment.

---

## 7. Automated and Live Test Verification Scope

### Context

For automated testing in
[`Firestore/core/test/unit/remote/CMakeLists.txt`](core/test/unit/remote/CMakeLists.txt)
and [`Firestore.xcodeproj`](Example/Firestore.xcodeproj/project.pbxproj), the
target hostname parser, PEM chain parser, and `SecTrustEvaluateWithError` logic
can be tested directly in memory, and an ephemeral in-process `grpc::Server` on
`127.0.0.1:0` can exercise the full gRPC TLS handshake through
`ExternalCertificateVerifier` offline using self-contained test certificates
and custom anchors. In addition to checked-in offline tests, a one-time local
live verification against `firestore.googleapis.com:443` can confirm default OS
trust works end-to-end against production Google Frontends.

### Question

What level of test verification would you like?

### Options Presented

* **Option 1: Comprehensive** (Recommended) — Add both direct unit tests (PEM
  chain parsing, malformed inputs, leaf/intermediate/hostname cases) and
  offline in-process `grpc::Server` TLS loopback tests (valid chain, untrusted
  root, wrong hostname, untrusted intermediate), plus run a local live smoke
  check against `firestore.googleapis.com:443` during verification.
* **Option 2: Loopback** — Add the offline direct unit tests and in-process
  `grpc::Server` TLS loopback tests, without running any live verification
  against `firestore.googleapis.com:443`.
* **Option 3: UnitOnly** — Add only direct in-memory unit tests for PEM parsing
  and `SecTrustEvaluateWithError` without spinning up an in-process
  `grpc::Server`.

### Selection

**Option 1: Comprehensive** — Added 23 self-contained unit and in-process
`grpc::Server` TLS loopback tests in
[`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
and verified a live `CreateDefaultTlsCredentials()` TLS connection (and
negative hostname-override check) against `firestore.googleapis.com:443`.

---

## 8. `Firestore/CHANGELOG.md` Entry

### Context

Looking at [`Firestore/CHANGELOG.md`](CHANGELOG.md), internal networking
architecture changes with user-visible security or binary-size impact—such as
the `NWPathMonitor` migration in `12.16.0` and the eMudhra root-store security
update (`#16930`)—each received an `# Unreleased` changelog bullet. Replacing
`grpc_root_certificates_generated.cc` on Apple platforms delegates TLS trust
evaluation to Apple's OS trust store (`Security.framework`) and reduces binary
size without changing public APIs.

### Question

Should we add an `# Unreleased` entry to
[`Firestore/CHANGELOG.md`](CHANGELOG.md) as part of this branch?

### Options Presented

* **Option 1: Add** (Recommended) — Add a `- [changed]` bullet under
  `# Unreleased` in [`Firestore/CHANGELOG.md`](CHANGELOG.md) noting that
  Firestore on Apple platforms now validates TLS server certificates using the
  system trust store (`Security.framework`) instead of an embedded root
  certificate bundle.
* **Option 2: Skip** — Leave [`Firestore/CHANGELOG.md`](CHANGELOG.md) untouched
  for now so changelog wording can be handled separately at PR/release time.

### Selection

**Option 1: Add** — Added the `- [changed]` entry under `# Unreleased` in
[`Firestore/CHANGELOG.md`](CHANGELOG.md).
