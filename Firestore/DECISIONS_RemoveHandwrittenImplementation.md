# Decisions: Implementing Removal of Handwritten String-Parsing Functions

This file documents the implementation design decisions made while applying the
`KeepBoth + FoundationNoDeps` strategy to
[`grpc_tls_credentials_provider_apple.h`](core/src/remote/grpc_tls_credentials_provider_apple.h),
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
and
[`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm).

---

## 1. Scope of `ExtractTlsHostName` (Initial Question)

### Context

Before implementing the `KeepBoth + FoundationNoDeps` changes in
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
there is an important scope decision on how much of
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
should remain at all. As shown in
`TlsChannelSecurityConnector::TlsChannelSecurityConnector`
(`tls_security_connector.cc`), gRPC's URI resolver **already** strips
`dns:///`, `ipv4:`, and `ipv6:` schemes, and `TlsChannelSecurityConnector`
**already** calls `SplitHostPort(target_name, &host, &port)` (stripping `:port`
and IPv6 `[...]` brackets) before populating `request->target_name()`. The only
reason
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
in PR `#16946` grew to over 120 lines (and ~100 lines even with
`NSURLComponents` + `inet_pton`) is that it re-implements gRPC resolver URI
scheme stripping (`dns://8.8.8.8:53/...`, `ipv4:...`, `ipv6:...`) and strict
port/bracket edge-case checks for inputs that
[`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
passes directly in unit tests.

### Question

How much of
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
should we keep when implementing `KeepBoth + FoundationNoDeps`?

### Options Presented

* **Option 1: CompactAuthority** (Recommended) — Replace
  [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
  with a compact ~30-line `NSURLComponents` + `inet_pton(AF_INET6, ...)` helper
  that handles authority/host strings (`host`, `host:port`, `[ipv6]:port`, and
  bare IPv6 with optional `%zone`), and drop the redundant `dns:///` / `ipv4:`
  / `ipv6:` resolver URI scheme parsing (updating the unit tests in
  [`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
  accordingly).
* **Option 2: DeleteExtractHost** — Delete
  [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.h)
  completely and rely on `TlsChannelSecurityConnector` having already stripped
  schemes, ports, and IPv6 brackets from `request->target_name()` (stripping
  only an optional `%zone` suffix in 3 lines, just like
  `grpc_ssl_host_matches_name`), and update direct unit-test callers of
  [`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.h)
  to pass bare host names.
* **Option 3: FullUriCompatibility** — Keep full `dns:///` / `ipv4:` / `ipv6:`
  URI scheme stripping on top of `NSURLComponents` + `inet_pton(AF_INET6, ...)`
  (~100 lines) so all existing `ExtractTlsHostName` URI test cases in
  [`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
  remain unchanged.

### Selection

Deferred pending a detailed pros-and-cons comparison of the three options
(resolved in Section 2).

---

## 2. Pros and Cons of `ExtractTlsHostName` Scope Options (Follow-Up Question)

### Context

Inside `gRPC-Core`, when [`GrpcConnection::CreateChannel`](core/src/remote/grpc_connection.cc)
calls `grpc::CreateCustomChannel(host, ...)`, gRPC's URI resolver first strips
any URI scheme (`dns:///`, `dns://8.8.8.8:53/`, `ipv4:`, `ipv6:`), and then
`TlsChannelSecurityConnector`'s constructor (`tls_security_connector.cc`) calls
`SplitHostPort(target_name, &host, &port)`—stripping `:port` and `[...]`
brackets—and stores the bare host in `target_name_`. However, if a caller sets
`grpc.ssl_target_name_override` (`args.SetSslTargetNameOverride(...)`),
`TlsChannelSecurityConnector` stores `overridden_target_name_` without running
`SplitHostPort`.

Comparing the three options across Security (primary), Code Complexity
(secondary), and Maintenance Burden (tertiary):

1. **Option 1 (`CompactAuthority`, ~35 lines)**:
   * **Pros**: Eliminates ~85 lines of redundant `dns:///` / `ipv4:` / `ipv6:`
     URI-scheme and manual port character parsing while still validating syntax
     (rejecting embedded NULs, control/whitespace chars, paths, and malformed
     IPv6 via `inet_pton`) and stripping `:port`, `[...]`, and `%zone` via
     `NSURLComponents` even when `SetSslTargetNameOverride` or unit tests pass
     `host:port` or `[::1]:443`.
   * **Cons**: Requires removing the 6 unit-test assertions in
     [`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
     that pass unsplit `dns:///` / `ipv4:` / `ipv6:` URI prefixes directly to
     `ExtractTlsHostName`.
2. **Option 2 (`DeleteExtractHost`, ~5 lines)**:
   * **Pros**: Removes `ExtractTlsHostName` completely.
   * **Cons**: Breaks if `SetSslTargetNameOverride` or direct callers pass
     `"host:443"` or `"[::1]"`, and performs no upfront validation against
     malformed target strings before calling `SecPolicyCreateSSL`.
3. **Option 3 (`FullUriCompatibility`, ~120 lines)**:
   * **Pros**: Zero changes to existing unit test cases in
     [`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm).
   * **Cons**: Leaves ~85 extra lines of string-slicing code in production
     [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
     solely to parse `dns:///` and `ipv4:`/`ipv6:` prefixes that never reach
     `Verify()` in production.

### Question

With those tradeoffs in mind, which scope for
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
should we implement?

### Options Presented

* **Option 1: CompactAuthority** (Recommended) — Implement the ~35-line
  `NSURLComponents` + `inet_pton(AF_INET6, ...)` authority parser (handling
  `host`, `host:port`, `[ipv6]:port`, and bare IPv6 with optional `%zone`),
  removing the redundant `dns:///` / `ipv4:` / `ipv6:` URI-scheme prefix
  parsing and updating the unit tests accordingly.
* **Option 2: DeleteExtractHost** — Delete
  [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.h)
  completely, strip only an optional `%zone` suffix inside
  [`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
  and update unit tests to pass bare host names.
* **Option 3: FullUriCompatibility** — Keep full `dns:///` / `ipv4:` / `ipv6:`
  URI scheme stripping on top of `NSURLComponents` + `inet_pton(AF_INET6, ...)`
  (~120 lines) so all existing `ExtractTlsHostName` URI test cases in
  [`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
  remain unchanged.

### Selection

**Option 1: CompactAuthority** — Replace
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
with the compact `NSURLComponents` + `inet_pton(AF_INET6, ...)` authority
parser and update the unit tests in
[`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
to remove the redundant `dns:`/`ipv4:`/`ipv6:` scheme prefix assertions.

---

## 3. Visibility of `ExtractTlsHostName` and `ParsePemCertificateChain`

### Context

In [`grpc_tls_credentials_provider_apple.h`](core/src/remote/grpc_tls_credentials_provider_apple.h),
`ExtractTlsHostName` and `ParsePemCertificateChain` were declared in the
internal header solely so
[`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
could unit-test them directly; no production code outside
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
calls them. With both functions now delegating to OS APIs (`NSURLComponents` +
`inet_pton` and `NSScanner` + `NSData`), we could either keep them in
[`grpc_tls_credentials_provider_apple.h`](core/src/remote/grpc_tls_credentials_provider_apple.h)
for direct unit testing or move them into the anonymous namespace inside
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm).

### Question

Should `ExtractTlsHostName` and `ParsePemCertificateChain` remain declared in
[`grpc_tls_credentials_provider_apple.h`](core/src/remote/grpc_tls_credentials_provider_apple.h)
for direct unit testing, or be moved into the anonymous namespace in
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)?

### Options Presented

* **Option 1: KeepInHeader** (Recommended) — Keep `ExtractTlsHostName` and
  `ParsePemCertificateChain` in
  [`grpc_tls_credentials_provider_apple.h`](core/src/remote/grpc_tls_credentials_provider_apple.h)
  (updating `ExtractTlsHostName`'s doc comment to reflect `CompactAuthority`)
  so the direct unit tests in
  [`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
  continue testing both helpers directly.
* **Option 2: PrivateHelpers** — Remove `ExtractTlsHostName` and
  `ParsePemCertificateChain` from
  [`grpc_tls_credentials_provider_apple.h`](core/src/remote/grpc_tls_credentials_provider_apple.h),
  move them into the anonymous namespace in
  [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
  and test their behavior through
  [`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.h).

### Selection

**Option 2: PrivateHelpers** — Removed `ExtractTlsHostName` and
`ParsePemCertificateChain` from
[`grpc_tls_credentials_provider_apple.h`](core/src/remote/grpc_tls_credentials_provider_apple.h),
making them private helpers in the anonymous namespace of
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
and testing their behavior through
[`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.h).

---

## 4. Handling Dotted-Quad IPv4-Mapped IPv6 Literals (`[::ffff:127.0.0.1]:443`)

### Context

While running the converted
[`ExtractTlsHostNameIpv6`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
unit test through
[`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
(under `PrivateHelpers`), we uncovered an interesting behavior in Apple's
`SecPolicyCreateSSL` on mixed dotted-quad IPv4-mapped IPv6 literals
(`"[::ffff:127.0.0.1]:443"`). Previously,
[`ExtractTlsHostNameIpv6`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
only asserted `ExtractTlsHostName("[::ffff:127.0.0.1]:443") == "::ffff:127.0.0.1"`
without passing that string to `SecPolicyCreateSSL`. When
`cf_host = "::ffff:127.0.0.1"` is evaluated by
`SecPolicyCreateSSL(/*server=*/true, cf_host)` against a leaf certificate
containing the 16-byte `iPAddress` SAN
`{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff, 127, 0, 0, 1}`, Apple's
`Security.framework` rejects `"::ffff:127.0.0.1"` with
`certificate name does not match input`, whereas it accepts the standard
colon-hex representation `"[::ffff:7f00:1]:443"` (`cf_host = "::ffff:7f00:1"`)
against the exact same certificate (with all 25/25 unit and loopback tests
passing).

Comparing the three options across Security (primary), Code Complexity
(secondary), and Maintenance Burden (tertiary):

1. **`TestHexIpv6`** (keep
   [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
   as-is and replace `"[::ffff:127.0.0.1]:443"` with `"[::ffff:7f00:1]:443"` in
   [`ExtractTlsHostNameIpv6`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)):
   * **Pros**:
     * **Security**: Fails closed via `SecPolicyCreateSSL` without introducing
       custom IPv6 string-rewriting logic in
       [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm).
     * **Code Complexity**: Zero lines added to
       [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm);
       changes only a single test literal in
       [`grpc_tls_credentials_provider_apple_test.mm`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm).
     * **Maintenance Burden**: Avoids maintaining custom IPv4-mapped IPv6
       reformatting for an esoteric notation where Apple's `SecPolicyCreateSSL`
       (which expects pure hex `::ffff:7f00:1`) and gRPC's `SslCheckCallHost`
       (which formats 16-byte SANs with `inet_ntop` as `::ffff:127.0.0.1`)
       already disagree.
   * **Cons**:
     * Passing mixed dotted-quad `"[::ffff:127.0.0.1]:443"` to
       [`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
       fails at `SecTrustEvaluateWithError` unless written in standard
       colon-hex form (`"[::ffff:7f00:1]:443"`).
2. **`CanonicalizeToHex`** (rewrite dotted-quad IPv6 literals using
   `struct in6_addr` into pure colon-hex groups inside
   [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)):
   * **Pros**:
     * **Direct Test Compatibility**: Allows
       `VerifyAppleTlsCertificateChain(pki.ServerChainPem(), "[::ffff:127.0.0.1]:443", anchors.get())`
       in
       [`ExtractTlsHostNameIpv6`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
       to succeed without changing the test vector.
   * **Cons**:
     * **Code Complexity**: Adds ~12 lines of custom IPv6 hex-formatting logic
       to
       [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
       running counter to our goal of eliminating handwritten string
       formatting.
     * **Maintenance Burden**: Rewriting the host string only helps
       `SecPolicyCreateSSL`; on a full gRPC channel under `KeepBoth`, gRPC's
       `ClientAuthFilter` (`check_call_host(true)`) still inspects the
       unrewritten channel authority.
3. **`RejectDottedIpv6`** (reject IPv6 literals containing `.` in
   [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
   and move `"[::ffff:127.0.0.1]:443"` to
   [`ExtractTlsHostNameEmptyAndMalformed`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)):
   * **Pros**:
     * **Error Attribution**: Rejects mixed dotted-quad IPv6 literals upfront in
       [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
       with `"Invalid or empty TLS target host name"` rather than failing inside
       `SecTrustEvaluateWithError`.
   * **Cons**:
     * **Code Complexity**: Adds an extra special-case filter on top of POSIX
       `inet_pton(AF_INET6, ...)` in
       [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm).

### Question

How would you like to handle mixed dotted-quad IPv4-mapped IPv6 literals like
`"[::ffff:127.0.0.1]:443"`?

### Options Presented

* **Option 1: TestHexIpv6** (Recommended) — Keep
  [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
  unchanged and update the test vector in
  [`ExtractTlsHostNameIpv6`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
  from `"[::ffff:127.0.0.1]:443"` to `"[::ffff:7f00:1]:443"`.
* **Option 2: CanonicalizeToHex** — Canonicalize dotted-quad IPv6 literals into
  colon-hex notation using `struct in6_addr` inside
  [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
  so `"[::ffff:127.0.0.1]:443"` is passed as `"::ffff:7f00:1"` to
  `SecPolicyCreateSSL`.
* **Option 3: RejectDottedIpv6** — Reject IPv6 literals containing `.` in
  [`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
  and move `"[::ffff:127.0.0.1]:443"` to
  [`ExtractTlsHostNameEmptyAndMalformed`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm).

### Selection

**Option 1: TestHexIpv6** — Kept
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
unchanged and updated the test vector in
[`ExtractTlsHostNameIpv6`](core/test/unit/remote/grpc_tls_credentials_provider_apple_test.mm)
from `"[::ffff:127.0.0.1]:443"` to `"[::ffff:7f00:1]:443"`.

---

## 5. Subchannel Pool Isolation vs. Connection Reuse (Review Finding 1)

### Context

In [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
a static singleton `GetDefaultAppleCertificateVerifier()` was originally
introduced to share a single stateless `CertificateVerifier` instance across
default channel credentials. However, gRPC's `TlsCredentials::cmp_impl`
compares options by verifier pointer equality (`options_.certificate_verifier()
== other.options_.certificate_verifier()`). Because the verifier pointer was
identical across all calls to `CreateDefaultTlsCredentials()`, gRPC's
`GlobalSubchannelPool` treated all channels targeting
`firestore.googleapis.com` as sharing the exact same subchannel key.

This broke [`GrpcConnection::RegisterConnectivityMonitor`](core/src/remote/grpc_connection.cc),
where Firestore calls `grpc_channel_.reset()` on network transitions (e.g.,
Wi-Fi to cellular handover) to drop dead sockets immediately. Under a shared
subchannel pool, if any in-flight RPC or asynchronous load-balancer teardown
still held a reference (or if multiple `Firestore` instances existed in the
process), the newly created channel reused the old subchannel on the dead
socket, hanging until TCP keepalive timed out (~30+ seconds). Prior to this
PR, BoringSSL's `SslCredentials` compared by pointer identity (`this == other`),
ensuring every channel received its own independent TCP connection.

### Question

How should we resolve subchannel pool isolation vs. connection reuse in
[`CreateAppleTlsCredentials`](core/src/remote/grpc_tls_credentials_provider_apple.mm)?

### Options Presented

* **Option 1: FreshVerifierPerChannel** (Recommended) — Drop
  `GetDefaultAppleCertificateVerifier()` and create a fresh
  `AppleSecTrustCertificateVerifier` instance in
  [`CreateAppleTlsCredentials`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
  restoring Firestore's dedicated channel connection model.
* **Option 2: LocalSubchannelPool** — Keep
  `GetDefaultAppleCertificateVerifier()` and add
  `args.SetInt(GRPC_ARG_USE_LOCAL_SUBCHANNEL_POOL, 1);` in
  [`GrpcConnection::CreateChannel`](core/src/remote/grpc_connection.cc).
* **Option 3: KeepSharedPool** — Keep `GetDefaultAppleCertificateVerifier()`
  and the shared `GlobalSubchannelPool` without changes.

### Selection

**Option 1: FreshVerifierPerChannel** — Dropped
`GetDefaultAppleCertificateVerifier()` and allocated a fresh
`AppleSecTrustCertificateVerifier` per channel credentials object in
[`CreateAppleTlsCredentials`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
ensuring each channel has a distinct subchannel key in `GlobalSubchannelPool`
and preserving immediate connection teardown on network transitions.

---

## 6. Asynchronous Verification vs. Synchronous EventEngine Thread Blocking (Review Finding 2)

### Context

In
[`AppleSecTrustCertificateVerifier::Verify`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
`SecTrustEvaluateWithError` is currently called synchronously on gRPC's
EventEngine handshake thread (`return true`).

Inside Apple's `Security.framework`, `SecTrustEvaluateWithError` performs
synchronous IPC to Apple's system `trustd` daemon. Furthermore, when
evaluating public certificates, `trustd` may perform network I/O to fetch
missing intermediate CA certificates via Authority Information Access (AIA)
URLs or check revocation via OCSP/CRL. Running this synchronously on gRPC's
EventEngine worker thread stalls that worker thread for the duration of the
IPC and network round-trips.

gRPC's `ExternalCertificateVerifier` supports non-blocking asynchronous
verification: when `Verify()` returns `false`, gRPC pauses the TLS handshake
until `callback(grpc::Status)` is invoked from any thread (gRPC's
`OnVerifyDone` establishes its own `grpc_core::ExecCtx` upon callback).

### Question

How should we resolve asynchronous verification vs. synchronous EventEngine
thread blocking in
[`AppleSecTrustCertificateVerifier::Verify`](core/src/remote/grpc_tls_credentials_provider_apple.mm)?

### Options Presented

* **Option 1: AsyncDispatchQueue** (Recommended) — Offload
  `VerifyAppleTlsCertificateChain` to GCD via
  `dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ...)`,
  invoke `callback(status)`, and `return false`.
* **Option 2: KeepSynchronous** — Keep synchronous execution (`return true`)
  and preserve the existing `TODO(dconeybe)`.

### Selection

**Option 2: KeepSynchronous** — Kept synchronous execution (`return true`) in
[`AppleSecTrustCertificateVerifier::Verify`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
and retained the existing `TODO(dconeybe)` for a future asynchronous migration.

---

## 7. Trust Anchor Snapshotting (`CFArrayCreateCopy` vs. `CFRetain`) (Review Finding 3)

### Context

In
[`AppleSecTrustCertificateVerifier`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
the constructor originally stored `anchor_certs_` by calling
`CFRetain(anchor_certs)`. Because CoreFoundation arrays are toll-free bridged
with Objective-C (`CFMutableArrayRef` / `NSMutableArray*`), a caller of the
public `CreateAppleTlsCredentials(CFArrayRef)` API can pass a mutable array.
If the caller subsequently mutates that array on their own thread after
channel creation while gRPC EventEngine worker threads concurrently read
`anchor_certs_` inside `SecTrustSetAnchorCertificates`, this introduces a
multi-threaded data race and potential use-after-free.

Using `CFArrayCreateCopy(kCFAllocatorDefault, anchor_certs)` creates an
immutable snapshot. In CoreFoundation, if the input array is already
immutable, `CFArrayCreateCopy` optimizes to an O(1) `CFRetain` with zero
allocation; if mutable, it creates an independent immutable copy.

### Question

How should we store `anchor_certs_` in
[`AppleSecTrustCertificateVerifier`](core/src/remote/grpc_tls_credentials_provider_apple.mm)?

### Options Presented

* **Option 1: SnapshotAnchorCopy** (Recommended) — Initialize `anchor_certs_`
  with `CFArrayCreateCopy(kCFAllocatorDefault, anchor_certs)` in
  [`AppleSecTrustCertificateVerifier`](core/src/remote/grpc_tls_credentials_provider_apple.mm).
* **Option 2: KeepRetainOnly** — Keep the existing `CFRetain` in
  [`AppleSecTrustCertificateVerifier`](core/src/remote/grpc_tls_credentials_provider_apple.mm).

### Selection

**Option 1: SnapshotAnchorCopy** — Initialized `anchor_certs_` with
`CFArrayCreateCopy(kCFAllocatorDefault, anchor_certs)` in
[`AppleSecTrustCertificateVerifier`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
ensuring immutable trust set isolation and thread safety.

---

## 8. Host Character Allowlist and IPv4 Canonicalization (Review Finding 4)

### Context

In
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
non-bracketed authority strings (`host` or `host:port`) are parsed using
`NSURLComponents`. In the code review, reviewers noted that RFC 3986 allows
sub-delimiters in hostnames (`*;!$&'()+=`) and BSD networking historically
accepts non-canonical IPv4 notations (such as leading-zero octal `010.0.0.1` or
shorthand `127.1`). While this represents a theoretical "parser differential"
between OS resolver path and certificate verification, in Firestore the target
hostname is configured by the developer (or defaults to
`firestore.googleapis.com`) rather than untrusted remote network input.

### Question

Should we add character allowlists (`[A-Za-z0-9.-_:]`) and numeric IPv4
canonicalization via `inet_pton(AF_INET, ...)` to
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)?

### Options Presented

* **Option 1: StrictHostValidation** (Recommended) — Add character allowlist
  `[A-Za-z0-9.-_:]` and `inet_pton(AF_INET)` canonicalization to eliminate any
  potential resolver-vs-verifier discrepancy.
* **Option 2: KeepNSURLComponentsOnly** — Keep the current ~35-line
  `NSURLComponents` implementation as-is without extra character filtering or
  IPv4 canonicalization logic.

### Selection

**Option 2: KeepNSURLComponentsOnly** — Retained the existing
`NSURLComponents` authority parser without adding extra character allowlist or
IPv4 canonicalization code, minimizing the amount of handwritten, brittle
string-parsing logic that must be maintained.

---

## 9. CoreFoundation Create/Copy Naming Rule (Review Finding 5)

### Context

In
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
the private helper that parses PEM text and returns a newly allocated, owned
`CFArrayRef` was named `ParsePemCertificateChain`.

According to Apple's CoreFoundation Memory Management Programming Guide,
functions that return an object with a retained (+1) reference count must
contain `Create` or `Copy` in their name. Functions without `Create` or `Copy`
are assumed by static analyzers (and developers) to follow the "Get Rule" (+0
unretained reference). Under Clang Static Analysis, callers releasing the
returned array (`util::SafeCFRelease(certs)`) could trigger false-positive
over-release diagnostics.

Renaming `ParsePemCertificateChain` to `CreateCertificateChainFromPem`
explicitly adheres to the CoreFoundation Create Rule.

### Question

Should we rename `ParsePemCertificateChain` in
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm)
to comply with the CoreFoundation Create Rule?

### Options Presented

* **Option 1: RenameToCreate** (Recommended) — Rename
  `ParsePemCertificateChain` to `CreateCertificateChainFromPem` in
  [`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm).
* **Option 2: KeepParseName** — Keep the name `ParsePemCertificateChain`
  without changes.

### Selection

**Option 1: RenameToCreate** — Renamed `ParsePemCertificateChain` to
`CreateCertificateChainFromPem` in
[`grpc_tls_credentials_provider_apple.mm`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
complying with Apple's CoreFoundation Create Rule.

---

## 10. Log Injection Hardening via `absl::CHexEscape` (Review Finding 6)

### Context

In
[`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
when `ExtractTlsHostName` rejected an invalid target, the raw `target_name` was
interpolated directly into the `grpc::Status` error message. Because the
strings rejected at this point can include malformed or adversarial inputs
containing embedded NULs, carriage returns, newlines, or terminal control
sequences, emitting them unescaped in status messages risks log forging / log
injection in client logs.

Wrapping `target_name` in `absl::CHexEscape(target_name)` from
`absl/strings/escaping.h` escapes newlines as `\n`, carriage returns as `\r`,
NULs as `\0`, and non-printable bytes as `\xHH`, ensuring safe, printable
single-line error messages.

### Question

Should we wrap rejected `target_name` strings in `absl::CHexEscape` in
[`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm)?

### Options Presented

* **Option 1: EscapeTargetInLog** (Recommended) — Wrap `target_name` in
  `absl::CHexEscape(target_name)` in
  [`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm).
* **Option 2: KeepRawTargetName** — Keep raw `target_name` in the error
  status string without escaping.

### Selection

**Option 1: EscapeTargetInLog** — Wrapped `target_name` in
`absl::CHexEscape(target_name)` in
[`VerifyAppleTlsCertificateChain`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
preventing log injection and newline forging.

---

## 11. Null-Safe `NSString` to `std::string` Conversion (Review Finding 7)

### Context

In
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
extracted host candidates were originally returned using
`candidate.UTF8String`, `ipv6_candidate.UTF8String`, and
`comps.host.UTF8String`. In Objective-C, `-[NSString UTF8String]` is nullable
and returns `NULL` if string encoding fails or if the receiver is `nil`. In
C++, constructing `std::string(const char*)` from a `nullptr` is undefined
behavior.

To prevent undefined behavior while avoiding writing new bespoke conversion
helpers, we evaluated using Firestore's existing, battle-tested utility
[`util::MakeString((__bridge CFStringRef)str)`](core/src/util/string_apple.h)
versus writing a new local `ToStdString(NSString*)` helper.

### Question

How should we perform null-safe `NSString*` to `std::string` conversion in
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm)?

### Options Presented

* **Option 1: ExistingMakeString** (Recommended) — Use the existing,
  battle-tested `util::MakeString((__bridge CFStringRef)str)` to convert
  `NSString*` to `std::string`, avoiding bespoke string-conversion code.
* **Option 2: BespokeToStdString** — Define a local 3-line
  `ToStdString(NSString*)` helper that inspects `str.UTF8String != nullptr`.

### Selection

**Option 1: ExistingMakeString** — Used Firestore's existing
`util::MakeString((__bridge CFStringRef)...)` utility in
[`ExtractTlsHostName`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
eliminating direct `std::string(candidate.UTF8String)` undefined behavior risks
without introducing bespoke helper functions.

---

## 12. Strict ASCII Whitespace in PEM Parsing (Review Finding 8)

### Context

In
[`CreateCertificateChainFromPem`](core/src/remote/grpc_tls_credentials_provider_apple.mm),
`NSScanner` previously skipped whitespace between certificates and stripped
whitespace from base64 blocks using Foundation's
`[NSCharacterSet whitespaceAndNewlineCharacterSet]`. Because
`whitespaceAndNewlineCharacterSet` encompasses all Unicode whitespace
categories (including non-breaking spaces U+00A0 and ideographic spaces
U+3000), it permissively accepted and stripped non-ASCII whitespace inside
base64 blocks and outside PEM boundaries.

Under RFC 7468 (Textual Encodings of PKIX Artifacts), PEM formatting is
strictly 7-bit ASCII consisting of spaces (` `), horizontal tabs (`\t`),
carriage returns (`\r`), and newlines (`\n`). Restricting `ws` to
`[NSCharacterSet characterSetWithCharactersInString:@" \t\r\n"]` ensures
RFC 7468 compliance and strict rejection of non-ASCII characters. An inline
comment documents this rationale so future maintainers understand why a custom
set of whitespace characters was specified.

### Question

Should we restrict PEM whitespace parsing to strict RFC 7468 ASCII whitespace
in
[`CreateCertificateChainFromPem`](core/src/remote/grpc_tls_credentials_provider_apple.mm)?

### Options Presented

* **Option 1: StrictAsciiWhitespace** (Recommended) — Use
  `[NSCharacterSet characterSetWithCharactersInString:@" \t\r\n"]` with an
  inline explanation of RFC 7468 ASCII whitespace requirements.
* **Option 2: KeepUnicodeWhitespace** — Keep
  `[NSCharacterSet whitespaceAndNewlineCharacterSet]`.

### Selection

**Option 1: StrictAsciiWhitespace** — Restricted `ws` to
`[NSCharacterSet characterSetWithCharactersInString:@" \t\r\n"]` and added an
inline comment documenting the RFC 7468 requirement for future readers.











