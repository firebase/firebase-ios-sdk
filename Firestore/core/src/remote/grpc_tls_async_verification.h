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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_ASYNC_VERIFICATION_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_ASYNC_VERIFICATION_H_

#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>  // NOLINT(build/c++11)
#include <string>
#include <unordered_map>

#include "Firestore/core/src/util/warnings.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/security/tls_certificate_verifier.h"
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {

/**
 * An owned copy of the parts of a `TlsCustomVerificationCheckRequest` that a
 * platform certificate evaluator needs.
 *
 * gRPC only guarantees that the request (and the `string_ref`s it hands out)
 * stays valid until the verification callback runs, and a cancelled or late
 * evaluation can outlive that. Copying synchronously inside `Verify()` means
 * evaluators never touch gRPC-owned memory.
 */
struct TlsVerificationInput {
  /** The PEM-encoded peer chain, leaf first. */
  std::string pem_chain;

  /** The channel's target name (`host`, `host:port`, or `[ipv6]:port`). */
  std::string target_name;
};

/**
 * Copies the verification input out of `request`. Uses
 * `peer_cert_full_chain()`, falling back to `peer_cert()` when the full chain
 * is empty.
 */
TlsVerificationInput CopyVerificationInput(
    const grpc::experimental::TlsCustomVerificationCheckRequest& request);

/** The callback type gRPC passes to `ExternalCertificateVerifier::Verify()`. */
using TlsVerificationCallback = std::function<void(grpc::Status)>;

/**
 * The status delivered to gRPC when a pending verification is cancelled,
 * either by gRPC (`ExternalCertificateVerifier::Cancel()`) or because the
 * verifier is destroyed while evaluations are still pending.
 */
grpc::Status TlsVerificationCancelledStatus();

/**
 * Tracks in-flight asynchronous TLS verifications so that each gRPC callback
 * runs exactly once, no matter how completion, cancellation, and destruction
 * interleave across threads.
 *
 * Each verification goes through `Start()`, then `FinishStart()`, and is
 * resolved by whichever of `Complete()`, `Cancel()`, or `CancelAll()` happens
 * first. Later resolutions of the same verification are ignored.
 *
 * - If the verification is resolved before `FinishStart()` (for example, an
 *   evaluator that completes inline, or a cancel that races `Verify()`),
 *   `FinishStart()` returns `true` with the result and the callback is never
 *   invoked. This honors gRPC's rule that the callback must not run on the
 *   calling thread before `Verify()` returns.
 * - Otherwise `FinishStart()` returns `false` and the callback is invoked
 *   exactly once, on the thread that resolves the verification.
 *
 * Callbacks are always invoked with no lock held, so a callback may safely
 * call back into the tracker.
 *
 * Verifications are identified by a unique id rather than by the gRPC request
 * pointer: gRPC frees the request once the callback runs, so a later request
 * may reuse the same address, and a late completion for the old verification
 * must not resolve the new one.
 *
 * Thread-safe. Hold it through `std::shared_ptr` so that evaluator completions
 * that arrive after the owning verifier is destroyed remain safe.
 */
class TlsAsyncVerificationTracker {
 public:
  using Id = uint64_t;
  using Request = grpc::experimental::TlsCustomVerificationCheckRequest;

  TlsAsyncVerificationTracker() = default;
  ~TlsAsyncVerificationTracker() = default;

  TlsAsyncVerificationTracker(const TlsAsyncVerificationTracker&) = delete;
  TlsAsyncVerificationTracker& operator=(const TlsAsyncVerificationTracker&) =
      delete;

  /**
   * Registers a new pending verification for `request` and returns its id.
   * `request` is used only as the lookup key for `Cancel()`; it is never
   * dereferenced.
   */
  Id Start(const Request* request, TlsVerificationCallback callback);

  /**
   * Ends the synchronous part of `Verify()`. If verification `id` was already
   * resolved, removes it, stores its status in `*sync_status`, and returns
   * `true` (the callback is dropped without being invoked). Otherwise marks it
   * asynchronous and returns `false`.
   */
  bool FinishStart(Id id, grpc::Status* sync_status);

  /**
   * Resolves verification `id` with `status`. A no-op if `id` was already
   * resolved.
   */
  void Complete(Id id, grpc::Status status);

  /**
   * Resolves the pending verification for `request` with
   * `TlsVerificationCancelledStatus()`. A no-op if there is none.
   */
  void Cancel(const Request* request);

  /**
   * Resolves every pending verification with
   * `TlsVerificationCancelledStatus()`.
   */
  void CancelAll();

  /** Returns the number of verifications that are not yet resolved. */
  size_t pending_count() const;

 private:
  struct Entry {
    const Request* request = nullptr;
    TlsVerificationCallback callback;
    // True until `FinishStart()` runs, i.e. while `Verify()` is still on the
    // stack and the callback must not be invoked.
    bool starting = true;
    // Set when the verification is resolved while `starting` is true.
    bool resolved = false;
    grpc::Status status;
  };

  // A callback and the status to invoke it with, once the lock is released.
  struct Invocation {
    TlsVerificationCallback callback;
    grpc::Status status;
  };

  // Resolves `id` with `status`. Returns the invocation to run after the lock
  // is released; its callback is empty if there is nothing to invoke.
  Invocation ResolveLocked(Id id, grpc::Status status);

  // Invokes `invocation.callback`, if any. Must be called with no lock held.
  static void Run(Invocation invocation);

  mutable std::mutex mutex_;
  Id next_id_ = 1;
  std::unordered_map<Id, Entry> entries_;
  std::unordered_map<const Request*, Id> ids_by_request_;
};

/**
 * An `ExternalCertificateVerifier` that runs certificate evaluation
 * asynchronously off gRPC's threads.
 *
 * `Verify()` copies the request into a `TlsVerificationInput`, hands it to the
 * injected `Evaluator`, and returns without blocking. The evaluator must not
 * block either: it should schedule the work (for example on a dispatch queue
 * or worker thread) and invoke the completion it is given, from any thread,
 * once the evaluation is done. Calling the completion more than once, or after
 * the verification was cancelled or the verifier destroyed, is safe; only the
 * first resolution reaches gRPC.
 *
 * `Cancel()` and destruction resolve pending verifications with
 * `TlsVerificationCancelledStatus()` and do not stop the evaluator's work;
 * its eventual completion is ignored.
 *
 * Platform verifiers (Apple `SecTrust`, Windows CryptoAPI) are built by
 * supplying an `Evaluator`.
 */
class AsyncTlsVerifier
    : public grpc::experimental::ExternalCertificateVerifier {
 public:
  using Evaluator = std::function<void(TlsVerificationInput input,
                                       TlsVerificationCallback completion)>;

  explicit AsyncTlsVerifier(Evaluator evaluator);
  ~AsyncTlsVerifier() override;

  AsyncTlsVerifier(const AsyncTlsVerifier&) = delete;
  AsyncTlsVerifier& operator=(const AsyncTlsVerifier&) = delete;

  bool Verify(grpc::experimental::TlsCustomVerificationCheckRequest* request,
              TlsVerificationCallback callback,
              grpc::Status* sync_status) override;

  void Cancel(
      grpc::experimental::TlsCustomVerificationCheckRequest* request) override;

  /** Exposed for tests. */
  const std::shared_ptr<TlsAsyncVerificationTracker>& tracker() const {
    return tracker_;
  }

 private:
  Evaluator evaluator_;
  std::shared_ptr<TlsAsyncVerificationTracker> tracker_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_ASYNC_VERIFICATION_H_
