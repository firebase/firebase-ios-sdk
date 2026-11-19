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
#include <mutex>
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

  /**
   * The bare host the channel connects to. gRPC strips the port and any IPv6
   * brackets before calling the verifier.
   */
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
 * The status delivered to gRPC when a pending verification is cancelled by
 * `ExternalCertificateVerifier::Cancel()`.
 */
grpc::Status TlsVerificationCancelledStatus();

/**
 * Tracks in-flight asynchronous TLS verifications for `AsyncTlsVerifier`, so
 * that each gRPC callback runs exactly once.
 *
 * Each verification is registered with `Start()`, then `FinishStart()` when
 * `Verify()` is about to return, and is resolved by whichever of `Complete()`
 * or `Cancel()` happens first. Later resolutions are ignored.
 *
 * - If `Complete()` runs before `FinishStart()` (an evaluator that completes
 *   inline), `FinishStart()` returns `true` with the status and the callback
 *   is dropped without being invoked, as gRPC requires.
 * - Otherwise the callback is invoked exactly once: by `Complete()` on the
 *   calling thread, or, for `Cancel()`, by the task it returns.
 *
 * Callbacks are invoked with no lock held and the tracker does not touch its
 * state afterwards, so a callback may call back into the tracker.
 *
 * Verifications are identified by a unique id rather than by the gRPC request
 * pointer: gRPC frees the request once the callback runs, so a later request
 * may reuse the address, and a late completion for the old verification must
 * not resolve the new one.
 *
 * Thread-safe. Held through `std::shared_ptr` so that evaluator completions
 * remain safe after the owning verifier is destroyed.

 */
class TlsAsyncVerificationTracker {
 public:
  using Id = uint64_t;
  using Request = grpc::experimental::TlsCustomVerificationCheckRequest;

  TlsAsyncVerificationTracker() = default;

  TlsAsyncVerificationTracker(const TlsAsyncVerificationTracker&) = delete;
  TlsAsyncVerificationTracker& operator=(const TlsAsyncVerificationTracker&) =
      delete;

  /**
   * Registers a new verification for `request`, which must not be null, and
   * returns its id. `request` is never dereferenced.
   */
  Id Start(const Request* request, TlsVerificationCallback callback);

  /**
   * Ends the synchronous part of `Verify()`. If verification `id` was already
   * completed, removes it, stores its status in `*sync_status`, and returns
   * `true`; the callback is dropped. Otherwise makes the verification
   * cancellable through its request and returns `false`.
   */
  bool FinishStart(Id id, grpc::Status* sync_status);

  /**
   * Resolves verification `id` with `status`. A no-op if `id` was already
   * resolved.
   */
  void Complete(Id id, grpc::Status status);

  /**
   * Resolves the verification for `request` with
   * `TlsVerificationCancelledStatus()` and returns a task that invokes its
   * callback. The caller must run the task on another thread: see
   * `AsyncTlsVerifier::Cancel()`.
   *
   * Returns an empty function if `request` has no verification that
   * `FinishStart()` made cancellable. `request` is only a lookup key and is
   * never dereferenced.
   */
  [[nodiscard]] std::function<void()> Cancel(const Request* request);

  /**
   * Drops every pending verification without invoking its callback. Later
   * calls to `Complete()` and `Cancel()` for them are no-ops.
   */
  void Abandon();

  /**
   * Returns the number of verifications that are not yet resolved. For tests
   * only.
   */
  size_t pending_count() const;

 private:
  struct Entry {
    const Request* request = nullptr;
    TlsVerificationCallback callback;
    // True until `FinishStart()` runs, i.e. while `Verify()` is still on the
    // stack and the callback must not be invoked.
    bool starting = true;
    // Set when `Complete()` runs while `starting` is true; `status` then holds
    // the result for `FinishStart()` to return synchronously.
    bool completed_inline = false;
    grpc::Status status;
  };

  mutable std::mutex mutex_;
  Id next_id_ = 1;
  std::unordered_map<Id, Entry> entries_;
  // Only verifications that `FinishStart()` made asynchronous; see `Cancel()`.
  std::unordered_map<const Request*, Id> ids_by_request_;
};

/**
 * An `ExternalCertificateVerifier` that runs certificate evaluation
 * asynchronously, off gRPC's threads.
 *
 * `Verify()` copies the request into a `TlsVerificationInput`, hands it to the
 * injected `Evaluator`, and returns without blocking. The evaluator must not
 * block either: it should schedule the work (for example on a dispatch queue
 * or worker thread) and invoke the completion it is given, from any thread,
 * once the evaluation is done. `Cancel()` resolves the verification with
 * `TlsVerificationCancelledStatus()` without blocking, but does not stop the
 * evaluator's work.
 *
 * The Apple verifier (`AppleSecTrustCertificateVerifier`) is built on this by
 * supplying an `Evaluator` that runs `SecTrust` evaluation.
 *
 * gRPC contract
 * -------------
 * gRPC never calls `Verify()` and `Cancel()` concurrently for the same
 * handshake. Within that contract, the implementation relies on and guarantees
 * the following:
 *
 * (a) The request pointer passed to `Cancel()` can be stale: gRPC may call
 *     `Cancel()` after the callback has run and the request has been freed.
 *     It is used only as a lookup key and is never dereferenced. If a newer
 *     request has reused the address, that verification fails with the
 *     cancelled status; this fails closed and gRPC retries the handshake.
 * (b) After `Cancel()`, the callback is still invoked, exactly once, with
 *     `TlsVerificationCancelledStatus()`. gRPC never finishes a cancelled
 *     handshake on its own; it waits for the callback, and would hang
 *     without it.
 * (c) The cancelled status is never delivered inline. gRPC calls `Cancel()`
 *     while holding its handshake lock, and the callback takes that lock, so
 *     delivery is handed to the `Scheduler`.
 * (d) If the evaluator completes while `Verify()` is still on the stack, the
 *     result is returned synchronously from `Verify()` and the callback is
 *     never invoked, since gRPC forbids invoking it on the calling thread
 *     before `Verify()` returns.
 * (e) Completions after the verification is resolved (late, duplicate, or
 *     after a cancel) are ignored.
 * (f) Completions after the verifier is destroyed are safe no-ops: they hold
 *     the tracker, not the verifier. Pending callbacks are dropped, because
 *     gRPC's callback refers to the verifier. gRPC keeps the verifier alive
 *     while verifications are pending, so nothing is waiting on them.
 */
class AsyncTlsVerifier
    : public grpc::experimental::ExternalCertificateVerifier {
 public:
  using Evaluator = std::function<void(TlsVerificationInput input,
                                       TlsVerificationCallback completion)>;

  /**
   * Runs `task` soon, on a thread other than the caller's, without blocking
   * the caller.
   */
  using Scheduler = std::function<void(std::function<void()> task)>;

  /**
   * Creates a verifier that evaluates with `evaluator` and delivers
   * cancellations with `scheduler`. Both are required.
   */
  AsyncTlsVerifier(Evaluator evaluator, Scheduler scheduler);
  ~AsyncTlsVerifier() override;

  AsyncTlsVerifier(const AsyncTlsVerifier&) = delete;
  AsyncTlsVerifier& operator=(const AsyncTlsVerifier&) = delete;

  bool Verify(grpc::experimental::TlsCustomVerificationCheckRequest* request,
              TlsVerificationCallback callback,
              grpc::Status* sync_status) override;

  void Cancel(
      grpc::experimental::TlsCustomVerificationCheckRequest* request) override;

 private:
  Evaluator evaluator_;
  Scheduler scheduler_;
  std::shared_ptr<TlsAsyncVerificationTracker> tracker_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_ASYNC_VERIFICATION_H_
