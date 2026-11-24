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

#include <chrono>
#include <utility>

#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "absl/strings/escaping.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

constexpr std::chrono::seconds kSlowVerificationThreshold(5);

std::string ToString(grpc::string_ref ref) {
  return ref.empty() ? std::string() : std::string(ref.data(), ref.size());
}

void LogCancellation(TlsAsyncVerificationTracker::Id id,
                     const std::string& target_name,
                     std::chrono::steady_clock::duration elapsed) {
  long long ms =  // NOLINT(runtime/int)
      std::chrono::duration_cast<std::chrono::milliseconds>(elapsed).count();
  std::string escaped_target = absl::CHexEscape(target_name);
  if (elapsed >= kSlowVerificationThreshold) {
    LOG_WARN(
        "TLS certificate verification #%s for '%s' was cancelled after %s ms "
        "while still in flight",
        id, escaped_target, ms);
  } else {
    LOG_DEBUG(
        "TLS certificate verification #%s for '%s' was cancelled after %s ms",
        id, escaped_target, ms);
  }
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
    const Request* request,
    TlsVerificationCallback callback,
    std::string target_name) {
  HARD_ASSERT(request != nullptr, "TLS verification request must not be null");
  std::lock_guard<std::mutex> lock(mutex_);
  Id id = next_id_++;
  Entry& entry = entries_[id];
  entry.request = request;
  entry.callback = std::move(callback);
  entry.target_name = std::move(target_name);
  entry.started_at = std::chrono::steady_clock::now();
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

  if (entry.completed_inline) {
    // gRPC must not see the callback invoked as well.
    *sync_status = std::move(entry.status);
    dropped = std::move(entry.callback);
    entries_.erase(it);
    return true;
  }

  entry.starting = false;
  // Registered only now. gRPC never cancels a request while verifying it, so a
  // `Cancel()` that arrives while `Verify()` is still on the stack can only
  // carry a stale pointer from another handshake, and must not match.
  ids_by_request_[entry.request] = id;
  return false;
}

void TlsAsyncVerificationTracker::Complete(Id id, grpc::Status status) {
  TlsVerificationCallback callback;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = entries_.find(id);
    if (it == entries_.end() || it->second.completed_inline) {
      return;  // Already resolved.
    }
    Entry& entry = it->second;
    if (entry.starting) {
      // `FinishStart()` returns this result synchronously.
      entry.completed_inline = true;
      entry.status = std::move(status);
      return;
    }
    auto by_request = ids_by_request_.find(entry.request);
    if (by_request != ids_by_request_.end() && by_request->second == id) {
      ids_by_request_.erase(by_request);
    }
    callback = std::move(entry.callback);
    entries_.erase(it);
  }
  if (callback) {
    callback(std::move(status));
  }
}

std::function<void()> TlsAsyncVerificationTracker::Cancel(
    const Request* request) {
  TlsVerificationCallback callback;
  Id id = 0;
  std::string target_name;
  std::chrono::steady_clock::duration elapsed{};
  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto by_request = ids_by_request_.find(request);
    if (by_request == ids_by_request_.end()) {
      return {};
    }
    id = by_request->second;
    auto it = entries_.find(id);
    HARD_ASSERT(it != entries_.end(), "Cancel() found a resolved verification");
    callback = std::move(it->second.callback);
    target_name = std::move(it->second.target_name);
    elapsed = std::chrono::steady_clock::now() - it->second.started_at;
    entries_.erase(it);
    ids_by_request_.erase(by_request);
  }
  if (!callback) {
    return {};
  }
  return [callback = std::move(callback), id,
          target_name = std::move(target_name), elapsed] {
    LogCancellation(id, target_name, elapsed);
    callback(TlsVerificationCancelledStatus());
  };
}

void TlsAsyncVerificationTracker::Abandon() {
  // Destroyed after the lock is released, in case a callback's destructor
  // re-enters the tracker.
  std::unordered_map<Id, Entry> abandoned;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    abandoned.swap(entries_);
    ids_by_request_.clear();
  }
}

size_t TlsAsyncVerificationTracker::pending_count() const {
  std::lock_guard<std::mutex> lock(mutex_);
  size_t count = 0;
  for (const auto& entry : entries_) {
    if (!entry.second.completed_inline) {
      ++count;
    }
  }
  return count;
}

// --- AsyncTlsVerifier --------------------------------------------------------

AsyncTlsVerifier::AsyncTlsVerifier(Evaluator evaluator, Scheduler scheduler)
    : evaluator_(std::move(evaluator)),
      scheduler_(std::move(scheduler)),
      tracker_(std::make_shared<TlsAsyncVerificationTracker>()) {
  HARD_ASSERT(evaluator_ != nullptr, "AsyncTlsVerifier requires an evaluator");
  HARD_ASSERT(scheduler_ != nullptr, "AsyncTlsVerifier requires a scheduler");
}

AsyncTlsVerifier::~AsyncTlsVerifier() {
  // gRPC's callbacks refer to this verifier, so they must not run after it is
  // destroyed. gRPC keeps the verifier alive while verifications are pending,
  // so normally there is nothing to drop.
  tracker_->Abandon();
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

  TlsVerificationInput input = CopyVerificationInput(*request);
  TlsAsyncVerificationTracker::Id id =
      tracker_->Start(request, std::move(callback), input.target_name);

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
