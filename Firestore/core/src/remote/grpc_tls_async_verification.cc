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

#include "Firestore/core/src/remote/grpc_tls_async_verification.h"

#include <thread>
#include <utility>
#include <vector>

#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

std::string ToString(grpc::string_ref ref) {
  return ref.empty() ? std::string() : std::string(ref.data(), ref.size());
}

}  // namespace

TlsVerificationInput CopyVerificationInput(
    const grpc::experimental::TlsCustomVerificationCheckRequest& request) {
  grpc::string_ref chain = request.peer_cert_full_chain();
  if (chain.empty()) {
    chain = request.peer_cert();
  }
  return TlsVerificationInput{ToString(chain), ToString(request.target_name())};
}

grpc::Status TlsVerificationCancelledStatus() {
  return grpc::Status(grpc::StatusCode::CANCELLED,
                      "TLS certificate verification was cancelled");
}

// --- TlsAsyncVerificationTracker ---------------------------------------------

TlsAsyncVerificationTracker::Id TlsAsyncVerificationTracker::Start(
    const Request* request, TlsVerificationCallback callback) {
  std::lock_guard<std::mutex> lock(mutex_);
  Id id = next_id_++;
  Entry& entry = entries_[id];
  entry.request = request;
  entry.callback = std::move(callback);
  if (request != nullptr) {
    // gRPC never has two pending verifications for the same request object:
    // a mapping for this address can only be left over from a verification
    // that was resolved (resolution erases it), so overwriting is safe.
    ids_by_request_[request] = id;
  }
  return id;
}

bool TlsAsyncVerificationTracker::FinishStart(Id id,
                                              grpc::Status* sync_status) {
  HARD_ASSERT(sync_status != nullptr, "sync_status must not be null");
  // Declared before the lock so that it is destroyed after the lock is
  // released, in case the callback's destructor re-enters the tracker.
  TlsVerificationCallback dropped;
  std::lock_guard<std::mutex> lock(mutex_);
  auto it = entries_.find(id);
  HARD_ASSERT(it != entries_.end(),
              "FinishStart() called for an unknown verification");
  Entry& entry = it->second;
  HARD_ASSERT(entry.starting, "FinishStart() called twice");
  if (!entry.resolved) {
    entry.starting = false;
    return false;
  }

  // Resolved while `Verify()` was still on the stack: report the result
  // synchronously. gRPC must not see the callback invoked as well.
  *sync_status = std::move(entry.status);
  dropped = std::move(entry.callback);
  entries_.erase(it);
  return true;
}

TlsAsyncVerificationTracker::Invocation
TlsAsyncVerificationTracker::ResolveLocked(Id id, grpc::Status status) {
  auto it = entries_.find(id);
  if (it == entries_.end()) {
    return {};
  }
  Entry& entry = it->second;
  if (entry.resolved) {
    // Already resolved while `Verify()` is still on the stack; first wins.
    return {};
  }

  if (entry.request != nullptr) {
    auto by_request = ids_by_request_.find(entry.request);
    if (by_request != ids_by_request_.end() && by_request->second == id) {
      ids_by_request_.erase(by_request);
    }
    entry.request = nullptr;
  }

  if (entry.starting) {
    // `FinishStart()` reports this result synchronously.
    entry.resolved = true;
    entry.status = std::move(status);
    return {};
  }

  Invocation invocation{std::move(entry.callback), std::move(status)};
  entries_.erase(it);
  return invocation;
}

void TlsAsyncVerificationTracker::Run(Invocation invocation) {
  if (invocation.callback) {
    invocation.callback(std::move(invocation.status));
  }
}

void TlsAsyncVerificationTracker::Complete(Id id, grpc::Status status) {
  Invocation invocation;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    invocation = ResolveLocked(id, std::move(status));
  }
  Run(std::move(invocation));
}

std::function<void()> TlsAsyncVerificationTracker::Cancel(
    const Request* request) {
  if (request == nullptr) {
    return {};
  }
  Invocation invocation;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    // gRPC may call Cancel() with a stale pointer that races the callback
    // (see the gRPC verifier contract). If the address was already reused by
    // a newer verification, that one is cancelled early. This fails closed
    // (the handshake fails and is retried) and matches gRPC's own
    // pointer-keyed bookkeeping, so it is harmless.
    auto it = ids_by_request_.find(request);
    if (it == ids_by_request_.end()) {
      return {};
    }
    invocation = ResolveLocked(it->second, TlsVerificationCancelledStatus());
  }
  if (!invocation.callback) {
    return {};
  }
  // The task owns the callback; it never touches the tracker.
  return [invocation = std::move(invocation)]() mutable {
    Run(std::move(invocation));
  };
}

void TlsAsyncVerificationTracker::CancelAll() {
  std::vector<Invocation> invocations;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<Id> ids;
    ids.reserve(entries_.size());
    for (const auto& entry : entries_) {
      ids.push_back(entry.first);
    }
    for (Id id : ids) {
      invocations.push_back(
          ResolveLocked(id, TlsVerificationCancelledStatus()));
    }
  }
  for (Invocation& invocation : invocations) {
    Run(std::move(invocation));
  }
}

size_t TlsAsyncVerificationTracker::pending_count() const {
  std::lock_guard<std::mutex> lock(mutex_);
  size_t count = 0;
  for (const auto& entry : entries_) {
    if (!entry.second.resolved) {
      ++count;
    }
  }
  return count;
}

// --- AsyncTlsVerifier
// ---------------------------------------------------------

AsyncTlsVerifier::AsyncTlsVerifier(Evaluator evaluator, Scheduler scheduler)
    : evaluator_(std::move(evaluator)),
      scheduler_(std::move(scheduler)),
      tracker_(std::make_shared<TlsAsyncVerificationTracker>()) {
  HARD_ASSERT(evaluator_ != nullptr, "AsyncTlsVerifier requires an evaluator");
  if (!scheduler_) {
    // Cancellations are rare, so a thread per cancellation is acceptable. The
    // thread is detached and may still be running during static destruction
    // at process exit; the task only touches the gRPC callback it owns.
    scheduler_ = [](std::function<void()> task) {
      std::thread(std::move(task)).detach();
    };
  }
}

AsyncTlsVerifier::~AsyncTlsVerifier() {
  // gRPC keeps the verifier alive while verifications are pending, so this is
  // normally a no-op. If verifications are somehow still pending (only
  // possible when the verifier is used directly, as in tests), resolve them
  // rather than dropping callbacks that someone is waiting on. This runs
  // inline: deferring would let callbacks outlive the verifier they belong to.
  tracker_->CancelAll();
}

bool AsyncTlsVerifier::Verify(
    grpc::experimental::TlsCustomVerificationCheckRequest* request,
    TlsVerificationCallback callback,
    grpc::Status* sync_status) {
  HARD_ASSERT(sync_status != nullptr,
              "TLS synchronous verification status output must not be null");
  if (request == nullptr) {
    *sync_status =
        grpc::Status(grpc::StatusCode::UNAUTHENTICATED,
                     "TLS custom verification check request must not be null");
    return true;
  }

  // Copy before registering: once the verification is registered it can be
  // cancelled, after which gRPC may free `request`.
  TlsVerificationInput input = CopyVerificationInput(*request);
  TlsAsyncVerificationTracker::Id id =
      tracker_->Start(request, std::move(callback));

  // The completion holds the tracker, not the verifier, so it stays safe to
  // call after the verifier is destroyed.
  std::shared_ptr<TlsAsyncVerificationTracker> tracker = tracker_;
  evaluator_(std::move(input), [tracker, id](grpc::Status status) {
    tracker->Complete(id, std::move(status));
  });

  return tracker_->FinishStart(id, sync_status);
}

void AsyncTlsVerifier::Cancel(
    grpc::experimental::TlsCustomVerificationCheckRequest* request) {
  // gRPC holds its handshake lock here, and the callback takes it, so deliver
  // the cancellation on another thread rather than inline.
  std::function<void()> deliver = tracker_->Cancel(request);
  if (deliver) {
    scheduler_(std::move(deliver));
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
