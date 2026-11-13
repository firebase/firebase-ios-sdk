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

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <deque>
#include <memory>
#include <mutex>
#include <random>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "Firestore/core/src/util/warnings.h"
#include "gtest/gtest.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpc/credentials.h"
#include "grpc/grpc.h"
#include "grpcpp/security/tls_certificate_verifier.h"
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using grpc::experimental::CertificateVerifier;
using grpc::experimental::ExternalCertificateVerifier;
using grpc::experimental::TlsCustomVerificationCheckRequest;

constexpr auto kTimeout = std::chrono::seconds(10);

// A gRPC verification request whose strings live in mutable buffers owned by
// the test, so tests can check that verifiers copy rather than alias them.
class FakeRequest {
 public:
  FakeRequest(std::string pem_chain,
              std::string target_name,
              std::string peer_cert = "")
      : pem_chain_(std::move(pem_chain)),
        target_name_(std::move(target_name)),
        peer_cert_(std::move(peer_cert)) {
    std::memset(&c_request_, 0, sizeof(c_request_));
    c_request_.target_name = target_name_.c_str();
    c_request_.peer_info.peer_cert_full_chain =
        pem_chain_.empty() ? nullptr : pem_chain_.c_str();
    c_request_.peer_info.peer_cert =
        peer_cert_.empty() ? nullptr : peer_cert_.c_str();
  }

  FakeRequest() : FakeRequest("chain", "example.com:443") {
  }

  FakeRequest(const FakeRequest&) = delete;
  FakeRequest& operator=(const FakeRequest&) = delete;

  TlsCustomVerificationCheckRequest* get() {
    return &request_;
  }

  // Overwrites every byte of the strings the request points at, then frees
  // them.
  void ScribbleAndFree() {
    std::fill(pem_chain_.begin(), pem_chain_.end(), 'X');
    std::fill(target_name_.begin(), target_name_.end(), 'Y');
    std::fill(peer_cert_.begin(), peer_cert_.end(), 'Z');
    c_request_.target_name = nullptr;
    c_request_.peer_info.peer_cert_full_chain = nullptr;
    c_request_.peer_info.peer_cert = nullptr;
    std::string().swap(pem_chain_);
    std::string().swap(target_name_);
    std::string().swap(peer_cert_);
  }

 private:
  std::string pem_chain_;
  std::string target_name_;
  std::string peer_cert_;
  grpc_tls_custom_verification_check_request c_request_;
  TlsCustomVerificationCheckRequest request_{&c_request_};
};

// Records invocations of a verification callback.
class CallbackRecorder {
 public:
  TlsVerificationCallback AsCallback() {
    return [this](grpc::Status status) { Record(std::move(status)); };
  }

  void Record(grpc::Status status) {
    std::lock_guard<std::mutex> lock(mutex_);
    ++count_;
    last_status_ = std::move(status);
    last_thread_ = std::this_thread::get_id();
    cv_.notify_all();
  }

  bool WaitForCount(int expected) {
    std::unique_lock<std::mutex> lock(mutex_);
    return cv_.wait_for(lock, kTimeout, [&] { return count_ >= expected; });
  }

  int count() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return count_;
  }

  grpc::Status last_status() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return last_status_;
  }

  std::thread::id last_thread() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return last_thread_;
  }

 private:
  mutable std::mutex mutex_;
  std::condition_variable cv_;
  int count_ = 0;
  grpc::Status last_status_;
  std::thread::id last_thread_;
};

// A scheduler that holds tasks until the test runs them.
class ManualScheduler {
 public:
  AsyncTlsVerifier::Scheduler AsScheduler() {
    return [this](std::function<void()> task) {
      std::lock_guard<std::mutex> lock(mutex_);
      tasks_.push_back(std::move(task));
    };
  }

  size_t size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return tasks_.size();
  }

  // Runs all pending tasks on a new thread.
  void RunAllOnOtherThread() {
    std::vector<std::function<void()>> tasks;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      tasks.swap(tasks_);
    }
    std::thread thread([&] {
      for (auto& task : tasks) task();
    });
    thread.join();
  }

 private:
  mutable std::mutex mutex_;
  std::vector<std::function<void()>> tasks_;
};

// An evaluator that parks every completion so the test decides when (and on
// which thread) evaluations finish.
class ParkingEvaluator {
 public:
  AsyncTlsVerifier::Evaluator AsEvaluator() {
    return
        [this](TlsVerificationInput input, TlsVerificationCallback completion) {
          std::lock_guard<std::mutex> lock(mutex_);
          inputs_.push_back(std::move(input));
          completions_.push_back(std::move(completion));
        };
  }

  size_t size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return completions_.size();
  }

  TlsVerificationInput input(size_t i) const {
    std::lock_guard<std::mutex> lock(mutex_);
    return inputs_.at(i);
  }

  TlsVerificationCallback completion(size_t i) const {
    std::lock_guard<std::mutex> lock(mutex_);
    return completions_.at(i);
  }

 private:
  mutable std::mutex mutex_;
  std::vector<TlsVerificationInput> inputs_;
  std::vector<TlsVerificationCallback> completions_;
};

grpc::Status Unauthenticated(const std::string& message = "bad chain") {
  return grpc::Status(grpc::StatusCode::UNAUTHENTICATED, message);
}

void ExpectStatusEq(const grpc::Status& expected, const grpc::Status& actual) {
  EXPECT_EQ(expected.error_code(), actual.error_code());
  EXPECT_EQ(expected.error_message(), actual.error_message());
}

// Checks for the cancellation status explicitly, so a fail-open implementation
// (one reporting OK on cancel) cannot pass by also returning OK from
// `TlsVerificationCancelledStatus()`.
void ExpectCancelled(const grpc::Status& actual) {
  EXPECT_EQ(actual.error_code(), grpc::StatusCode::CANCELLED);
  EXPECT_EQ(actual.error_message(),
            TlsVerificationCancelledStatus().error_message());
}

// Runs `fn` on a new thread and waits for it.
template <typename F>
void RunOnOtherThread(F&& fn) {
  std::thread thread(std::forward<F>(fn));
  thread.join();
}

// --- CopyVerificationInput ---------------------------------------------------

TEST(TlsAsyncVerificationTest, CopyVerificationInputCopiesChainAndTarget) {
  FakeRequest request("full-chain-pem", "firestore.googleapis.com:443",
                      "leaf-pem");

  TlsVerificationInput input = CopyVerificationInput(*request.get());

  EXPECT_EQ(input.pem_chain, "full-chain-pem");
  EXPECT_EQ(input.target_name, "firestore.googleapis.com:443");
}

TEST(TlsAsyncVerificationTest,
     CopyVerificationInputFallsBackToPeerCertWhenFullChainIsEmpty) {
  FakeRequest request(/*pem_chain=*/"", "example.com", "leaf-pem");

  TlsVerificationInput input = CopyVerificationInput(*request.get());

  EXPECT_EQ(input.pem_chain, "leaf-pem");
  EXPECT_EQ(input.target_name, "example.com");
}

TEST(TlsAsyncVerificationTest, CopyVerificationInputOwnsItsBytes) {
  FakeRequest request("full-chain-pem", "example.com:443");

  TlsVerificationInput input = CopyVerificationInput(*request.get());
  request.ScribbleAndFree();

  EXPECT_EQ(input.pem_chain, "full-chain-pem");
  EXPECT_EQ(input.target_name, "example.com:443");
}

// --- TlsAsyncVerificationTracker
// ----------------------------------------------

TEST(TlsAsyncVerificationTrackerTest, CompleteAfterFinishStartInvokesCallback) {
  TlsAsyncVerificationTracker tracker;
  FakeRequest request;
  CallbackRecorder recorder;

  auto id = tracker.Start(request.get(), recorder.AsCallback());
  grpc::Status sync_status;
  EXPECT_FALSE(tracker.FinishStart(id, &sync_status));
  EXPECT_EQ(recorder.count(), 0);
  EXPECT_EQ(tracker.pending_count(), 1u);

  RunOnOtherThread([&] { tracker.Complete(id, Unauthenticated()); });

  EXPECT_EQ(recorder.count(), 1);
  ExpectStatusEq(Unauthenticated(), recorder.last_status());
  EXPECT_EQ(tracker.pending_count(), 0u);
}

TEST(TlsAsyncVerificationTrackerTest, SecondCompleteIsIgnored) {
  TlsAsyncVerificationTracker tracker;
  FakeRequest request;
  CallbackRecorder recorder;

  auto id = tracker.Start(request.get(), recorder.AsCallback());
  grpc::Status sync_status;
  ASSERT_FALSE(tracker.FinishStart(id, &sync_status));

  tracker.Complete(id, grpc::Status::OK);
  tracker.Complete(id, Unauthenticated());

  EXPECT_EQ(recorder.count(), 1);
  EXPECT_TRUE(recorder.last_status().ok());
}

TEST(TlsAsyncVerificationTrackerTest,
     CompleteBeforeFinishStartIsReportedSynchronously) {
  TlsAsyncVerificationTracker tracker;
  FakeRequest request;
  CallbackRecorder recorder;

  auto id = tracker.Start(request.get(), recorder.AsCallback());
  tracker.Complete(id, Unauthenticated("inline"));

  grpc::Status sync_status;
  EXPECT_TRUE(tracker.FinishStart(id, &sync_status));
  ExpectStatusEq(Unauthenticated("inline"), sync_status);
  EXPECT_EQ(recorder.count(), 0);
  EXPECT_EQ(tracker.pending_count(), 0u);

  // Nothing is left to resolve.
  tracker.Complete(id, grpc::Status::OK);
  EXPECT_FALSE(tracker.Cancel(request.get()));
  EXPECT_EQ(recorder.count(), 0);
}

TEST(TlsAsyncVerificationTrackerTest,
     CancelThenCompleteDeliversCancelledStatusOnce) {
  TlsAsyncVerificationTracker tracker;
  FakeRequest request;
  CallbackRecorder recorder;

  auto id = tracker.Start(request.get(), recorder.AsCallback());
  grpc::Status sync_status;
  ASSERT_FALSE(tracker.FinishStart(id, &sync_status));

  std::function<void()> deliver = tracker.Cancel(request.get());
  ASSERT_TRUE(deliver);
  // Cancel() resolves immediately but never invokes the callback itself.
  EXPECT_EQ(recorder.count(), 0);
  EXPECT_EQ(tracker.pending_count(), 0u);

  // A completion that races the delivery loses.
  tracker.Complete(id, grpc::Status::OK);
  EXPECT_EQ(recorder.count(), 0);

  RunOnOtherThread(deliver);
  EXPECT_EQ(recorder.count(), 1);
  ExpectCancelled(recorder.last_status());

  tracker.Complete(id, grpc::Status::OK);
  EXPECT_EQ(recorder.count(), 1);
  ExpectCancelled(recorder.last_status());
}

TEST(TlsAsyncVerificationTrackerTest, CompleteThenCancelIsNoOp) {
  TlsAsyncVerificationTracker tracker;
  FakeRequest request;
  CallbackRecorder recorder;

  auto id = tracker.Start(request.get(), recorder.AsCallback());
  grpc::Status sync_status;
  ASSERT_FALSE(tracker.FinishStart(id, &sync_status));

  tracker.Complete(id, grpc::Status::OK);
  EXPECT_FALSE(tracker.Cancel(request.get()));

  EXPECT_EQ(recorder.count(), 1);
  EXPECT_TRUE(recorder.last_status().ok());
}

TEST(TlsAsyncVerificationTrackerTest,
     CancelBeforeFinishStartIsReportedSynchronously) {
  TlsAsyncVerificationTracker tracker;
  FakeRequest request;
  CallbackRecorder recorder;

  auto id = tracker.Start(request.get(), recorder.AsCallback());
  EXPECT_FALSE(tracker.Cancel(request.get()));

  grpc::Status sync_status;
  EXPECT_TRUE(tracker.FinishStart(id, &sync_status));
  ExpectCancelled(sync_status);
  EXPECT_EQ(recorder.count(), 0);
}

TEST(TlsAsyncVerificationTrackerTest, CancelOfUnknownRequestIsNoOp) {
  TlsAsyncVerificationTracker tracker;
  FakeRequest pending;
  FakeRequest unknown;
  CallbackRecorder recorder;

  auto id = tracker.Start(pending.get(), recorder.AsCallback());
  grpc::Status sync_status;
  ASSERT_FALSE(tracker.FinishStart(id, &sync_status));

  EXPECT_FALSE(tracker.Cancel(unknown.get()));
  EXPECT_FALSE(tracker.Cancel(nullptr));

  EXPECT_EQ(recorder.count(), 0);
  EXPECT_EQ(tracker.pending_count(), 1u);
}

TEST(TlsAsyncVerificationTrackerTest,
     StaleCompletionDoesNotResolveRequestAtReusedAddress) {
  TlsAsyncVerificationTracker tracker;
  FakeRequest request;
  CallbackRecorder first;
  CallbackRecorder second;
  grpc::Status sync_status;

  auto first_id = tracker.Start(request.get(), first.AsCallback());
  ASSERT_FALSE(tracker.FinishStart(first_id, &sync_status));
  std::function<void()> deliver = tracker.Cancel(request.get());
  ASSERT_TRUE(deliver);
  deliver();
  ASSERT_EQ(first.count(), 1);

  // gRPC frees the request after the callback; a new request may reuse the
  // address.
  auto second_id = tracker.Start(request.get(), second.AsCallback());
  ASSERT_FALSE(tracker.FinishStart(second_id, &sync_status));
  EXPECT_NE(first_id, second_id);

  // The first evaluation finishes late.
  tracker.Complete(first_id, grpc::Status::OK);
  EXPECT_EQ(first.count(), 1);
  EXPECT_EQ(second.count(), 0);
  EXPECT_EQ(tracker.pending_count(), 1u);

  tracker.Complete(second_id, Unauthenticated());
  EXPECT_EQ(second.count(), 1);
  ExpectStatusEq(Unauthenticated(), second.last_status());
}

TEST(TlsAsyncVerificationTrackerTest, CallbackMayReenterTracker) {
  TlsAsyncVerificationTracker tracker;
  FakeRequest request;
  FakeRequest other;
  CallbackRecorder other_recorder;
  int calls = 0;
  size_t pending_seen_in_callback = 99;
  std::function<void()> deliver_other;

  auto id = tracker.Start(request.get(), [&](grpc::Status) {
    ++calls;
    pending_seen_in_callback = tracker.pending_count();
    deliver_other = tracker.Cancel(other.get());
  });
  grpc::Status sync_status;
  ASSERT_FALSE(tracker.FinishStart(id, &sync_status));
  auto other_id = tracker.Start(other.get(), other_recorder.AsCallback());
  ASSERT_FALSE(tracker.FinishStart(other_id, &sync_status));

  tracker.Complete(id, grpc::Status::OK);

  EXPECT_EQ(calls, 1);
  EXPECT_EQ(pending_seen_in_callback, 1u);
  EXPECT_EQ(tracker.pending_count(), 0u);
  ASSERT_TRUE(deliver_other);
  deliver_other();
  EXPECT_EQ(other_recorder.count(), 1);
}

TEST(TlsAsyncVerificationTrackerTest, CancelAllResolvesEveryPendingRequest) {
  TlsAsyncVerificationTracker tracker;
  FakeRequest a;
  FakeRequest b;
  CallbackRecorder recorder_a;
  CallbackRecorder recorder_b;
  grpc::Status sync_status;

  auto id_a = tracker.Start(a.get(), recorder_a.AsCallback());
  ASSERT_FALSE(tracker.FinishStart(id_a, &sync_status));
  auto id_b = tracker.Start(b.get(), recorder_b.AsCallback());
  ASSERT_FALSE(tracker.FinishStart(id_b, &sync_status));

  tracker.CancelAll();

  EXPECT_EQ(recorder_a.count(), 1);
  EXPECT_EQ(recorder_b.count(), 1);
  ExpectCancelled(recorder_a.last_status());
  ExpectCancelled(recorder_b.last_status());
  EXPECT_EQ(tracker.pending_count(), 0u);

  tracker.Complete(id_a, grpc::Status::OK);
  EXPECT_EQ(recorder_a.count(), 1);
}

TEST(TlsAsyncVerificationTrackerTest, CancelledStatusIsNotOk) {
  grpc::Status status = TlsVerificationCancelledStatus();
  EXPECT_FALSE(status.ok());
  EXPECT_EQ(status.error_code(), grpc::StatusCode::CANCELLED);
  EXPECT_FALSE(status.error_message().empty());
}

// --- AsyncTlsVerifier
// ---------------------------------------------------------

TEST(AsyncTlsVerifierTest,
     VerifyReturnsFalseAndCallbackRunsWithEvaluatorStatus) {
  ParkingEvaluator evaluator;
  AsyncTlsVerifier verifier(evaluator.AsEvaluator());
  FakeRequest request;
  CallbackRecorder recorder;

  grpc::Status sync_status;
  EXPECT_FALSE(
      verifier.Verify(request.get(), recorder.AsCallback(), &sync_status));
  ASSERT_EQ(evaluator.size(), 1u);
  EXPECT_EQ(recorder.count(), 0);

  RunOnOtherThread(
      [&] { evaluator.completion(0)(Unauthenticated("untrusted root")); });

  EXPECT_EQ(recorder.count(), 1);
  ExpectStatusEq(Unauthenticated("untrusted root"), recorder.last_status());
}

TEST(AsyncTlsVerifierTest, VerifySucceedsAsynchronously) {
  ParkingEvaluator evaluator;
  AsyncTlsVerifier verifier(evaluator.AsEvaluator());
  FakeRequest request;
  CallbackRecorder recorder;

  grpc::Status sync_status;
  ASSERT_FALSE(
      verifier.Verify(request.get(), recorder.AsCallback(), &sync_status));
  ASSERT_EQ(evaluator.size(), 1u);
  RunOnOtherThread([&] { evaluator.completion(0)(grpc::Status::OK); });

  EXPECT_EQ(recorder.count(), 1);
  EXPECT_TRUE(recorder.last_status().ok());
}

TEST(AsyncTlsVerifierTest, EvaluatorSeesCopiedInputAfterRequestIsFreed) {
  ParkingEvaluator evaluator;
  AsyncTlsVerifier verifier(evaluator.AsEvaluator());
  FakeRequest request("full-chain-pem", "example.com:443", "leaf-pem");
  CallbackRecorder recorder;

  grpc::Status sync_status;
  ASSERT_FALSE(
      verifier.Verify(request.get(), recorder.AsCallback(), &sync_status));
  request.ScribbleAndFree();

  ASSERT_EQ(evaluator.size(), 1u);
  TlsVerificationInput input = evaluator.input(0);
  EXPECT_EQ(input.pem_chain, "full-chain-pem");
  EXPECT_EQ(input.target_name, "example.com:443");
  evaluator.completion(0)(grpc::Status::OK);
}

TEST(AsyncTlsVerifierTest, InlineCompletionIsReturnedSynchronously) {
  AsyncTlsVerifier verifier(
      [](TlsVerificationInput, TlsVerificationCallback completion) {
        completion(Unauthenticated("inline"));
      });
  FakeRequest request;
  CallbackRecorder recorder;

  grpc::Status sync_status;
  EXPECT_TRUE(
      verifier.Verify(request.get(), recorder.AsCallback(), &sync_status));
  ExpectStatusEq(Unauthenticated("inline"), sync_status);
  EXPECT_EQ(recorder.count(), 0);
  EXPECT_EQ(verifier.tracker()->pending_count(), 0u);
}

TEST(AsyncTlsVerifierTest, NullRequestFailsSynchronously) {
  int evaluations = 0;
  AsyncTlsVerifier verifier(
      [&](TlsVerificationInput, TlsVerificationCallback) { ++evaluations; });
  CallbackRecorder recorder;

  grpc::Status sync_status;
  EXPECT_TRUE(verifier.Verify(nullptr, recorder.AsCallback(), &sync_status));
  EXPECT_EQ(sync_status.error_code(), grpc::StatusCode::UNAUTHENTICATED);
  EXPECT_EQ(evaluations, 0);
  EXPECT_EQ(recorder.count(), 0);
}

TEST(AsyncTlsVerifierTest, CancelInFlightDeliversCancelledStatusOnce) {
  ParkingEvaluator evaluator;
  ManualScheduler scheduler;
  AsyncTlsVerifier verifier(evaluator.AsEvaluator(), scheduler.AsScheduler());
  FakeRequest request;
  CallbackRecorder recorder;

  grpc::Status sync_status;
  ASSERT_FALSE(
      verifier.Verify(request.get(), recorder.AsCallback(), &sync_status));

  // gRPC calls Cancel() with its handshake lock held and the callback takes
  // that lock, so Cancel() must hand delivery to the scheduler.
  verifier.Cancel(request.get());
  EXPECT_EQ(recorder.count(), 0);
  ASSERT_EQ(scheduler.size(), 1u);

  scheduler.RunAllOnOtherThread();
  EXPECT_EQ(recorder.count(), 1);
  ExpectCancelled(recorder.last_status());

  // The evaluation finishes later; gRPC must not hear about it.
  ASSERT_EQ(evaluator.size(), 1u);
  RunOnOtherThread([&] { evaluator.completion(0)(grpc::Status::OK); });
  EXPECT_EQ(recorder.count(), 1);
  ExpectCancelled(recorder.last_status());
}

TEST(AsyncTlsVerifierTest, CompleteThenCancelIsNoOp) {
  ParkingEvaluator evaluator;
  AsyncTlsVerifier verifier(evaluator.AsEvaluator());
  FakeRequest request;
  CallbackRecorder recorder;

  grpc::Status sync_status;
  ASSERT_FALSE(
      verifier.Verify(request.get(), recorder.AsCallback(), &sync_status));
  ASSERT_EQ(evaluator.size(), 1u);
  evaluator.completion(0)(grpc::Status::OK);
  verifier.Cancel(request.get());

  EXPECT_EQ(recorder.count(), 1);
  EXPECT_TRUE(recorder.last_status().ok());
}

TEST(AsyncTlsVerifierTest, DefaultSchedulerDeliversCancelOnAnotherThread) {
  ParkingEvaluator evaluator;
  AsyncTlsVerifier verifier(evaluator.AsEvaluator());
  FakeRequest request;
  CallbackRecorder recorder;
  // Stands in for gRPC's handshake lock, which is held across Cancel() and
  // which the callback acquires.
  std::mutex handshake_mutex;
  const std::thread::id cancelling_thread = std::this_thread::get_id();

  grpc::Status sync_status;
  ASSERT_FALSE(verifier.Verify(
      request.get(),
      [&](grpc::Status status) {
        if (std::this_thread::get_id() == cancelling_thread) {
          // Delivered inside Cancel(): taking the lock here would
          // self-deadlock, as it would in gRPC. Record it so the test fails
          // instead of hanging.
          recorder.Record(std::move(status));
          return;
        }
        {
          // Blocks until the cancelling thread releases the lock.
          std::lock_guard<std::mutex> lock(handshake_mutex);
        }
        // Must be the last access to test state: the test may return as soon
        // as it observes the record.
        recorder.Record(std::move(status));
      },
      &sync_status));

  {
    std::lock_guard<std::mutex> lock(handshake_mutex);
    verifier.Cancel(request.get());
  }

  ASSERT_TRUE(recorder.WaitForCount(1));
  EXPECT_NE(recorder.last_thread(), cancelling_thread);
  ExpectCancelled(recorder.last_status());
}

TEST(AsyncTlsVerifierTest, CancelOfUnknownRequestSchedulesNothing) {
  ParkingEvaluator evaluator;
  ManualScheduler scheduler;
  AsyncTlsVerifier verifier(evaluator.AsEvaluator(), scheduler.AsScheduler());
  FakeRequest request;

  verifier.Cancel(request.get());
  verifier.Cancel(nullptr);

  EXPECT_EQ(scheduler.size(), 0u);
}

TEST(AsyncTlsVerifierTest, DestroyingVerifierMidFlightIsSafe) {
  ParkingEvaluator evaluator;
  FakeRequest request;
  CallbackRecorder recorder;

  auto verifier = std::make_unique<AsyncTlsVerifier>(evaluator.AsEvaluator());
  grpc::Status sync_status;
  ASSERT_FALSE(
      verifier->Verify(request.get(), recorder.AsCallback(), &sync_status));
  verifier.reset();

  // Pending callbacks are resolved rather than dropped, so the handshake that
  // owns them can finish.
  EXPECT_EQ(recorder.count(), 1);
  ExpectCancelled(recorder.last_status());

  // A completion that arrives after destruction must not touch freed memory.
  ASSERT_EQ(evaluator.size(), 1u);
  RunOnOtherThread([&] { evaluator.completion(0)(grpc::Status::OK); });
  EXPECT_EQ(recorder.count(), 1);
}

// Drives `AsyncTlsVerifier` through gRPC's own C/C++ verifier plumbing
// (`ExternalCertificateVerifier::Create` and `CertificateVerifier`), which is
// how TLS credentials call it.
class AsyncTlsVerifierThroughGrpcTest : public testing::Test {
 protected:
  void SetUp() override {
    grpc_init();
  }
  void TearDown() override {
    grpc_shutdown();
  }
};

TEST_F(AsyncTlsVerifierThroughGrpcTest, AsyncCompletionReachesGrpcCallback) {
  ParkingEvaluator evaluator;
  std::shared_ptr<CertificateVerifier> verifier =
      ExternalCertificateVerifier::Create<AsyncTlsVerifier>(
          evaluator.AsEvaluator());
  FakeRequest request;
  CallbackRecorder recorder;

  grpc::Status sync_status;
  EXPECT_FALSE(
      verifier->Verify(request.get(), recorder.AsCallback(), &sync_status));
  ASSERT_EQ(evaluator.size(), 1u);

  RunOnOtherThread([&] { evaluator.completion(0)(Unauthenticated()); });

  ASSERT_TRUE(recorder.WaitForCount(1));
  EXPECT_EQ(recorder.count(), 1);
  ExpectStatusEq(Unauthenticated(), recorder.last_status());
}

TEST_F(AsyncTlsVerifierThroughGrpcTest, CancelReachesGrpcCallbackOnce) {
  ParkingEvaluator evaluator;
  std::shared_ptr<CertificateVerifier> verifier =
      ExternalCertificateVerifier::Create<AsyncTlsVerifier>(
          evaluator.AsEvaluator());
  FakeRequest request;
  CallbackRecorder recorder;

  grpc::Status sync_status;
  ASSERT_FALSE(
      verifier->Verify(request.get(), recorder.AsCallback(), &sync_status));
  verifier->Cancel(request.get());

  ASSERT_TRUE(recorder.WaitForCount(1));
  EXPECT_EQ(recorder.last_status().error_code(), grpc::StatusCode::CANCELLED);

  ASSERT_EQ(evaluator.size(), 1u);
  RunOnOtherThread([&] { evaluator.completion(0)(grpc::Status::OK); });
  EXPECT_EQ(recorder.count(), 1);
  EXPECT_EQ(recorder.last_status().error_code(), grpc::StatusCode::CANCELLED);

  // The completion holds no reference that keeps a stale request alive.
  verifier.reset();
}

TEST_F(AsyncTlsVerifierThroughGrpcTest, InlineCompletionIsSynchronous) {
  std::shared_ptr<CertificateVerifier> verifier =
      ExternalCertificateVerifier::Create<AsyncTlsVerifier>(
          [](TlsVerificationInput, TlsVerificationCallback completion) {
            completion(Unauthenticated("inline"));
          });
  FakeRequest request;
  CallbackRecorder recorder;

  grpc::Status sync_status;
  EXPECT_TRUE(
      verifier->Verify(request.get(), recorder.AsCallback(), &sync_status));
  ExpectStatusEq(Unauthenticated("inline"), sync_status);
  EXPECT_EQ(recorder.count(), 0);
}

// --- Stress
// -------------------------------------------------------------------

// Many threads start verifications while worker threads complete them
// (sometimes twice) and the starting threads cancel some of them, in random
// order. Every verification must be resolved exactly once: either
// synchronously through `Verify()`'s return value or through its callback.
TEST(AsyncTlsVerifierStressTest, EveryVerificationResolvesExactlyOnce) {
  constexpr int kRequesterThreads = 6;
  constexpr int kRequestsPerThread = 300;
  constexpr int kWorkerThreads = 3;
  constexpr int kTotal = kRequesterThreads * kRequestsPerThread;

  // Work for the worker threads: either an evaluation to complete or a
  // scheduled cancellation delivery.
  struct Work {
    TlsVerificationCallback completion;
    std::function<void()> task;
  };
  std::mutex queue_mutex;
  std::condition_variable queue_cv;
  std::deque<Work> queue;
  bool done_producing = false;
  auto push = [&](Work work) {
    std::lock_guard<std::mutex> lock(queue_mutex);
    queue.push_back(std::move(work));
    queue_cv.notify_one();
  };

  std::atomic<int> inline_counter{0};
  AsyncTlsVerifier verifier(
      [&](TlsVerificationInput input, TlsVerificationCallback completion) {
        // Roughly one in eight evaluations completes inline.
        if (inline_counter.fetch_add(1) % 8 == 0) {
          completion(input.target_name == "fail" ? Unauthenticated()
                                                 : grpc::Status::OK);
          return;
        }
        push(Work{std::move(completion), nullptr});
      },
      [&](std::function<void()> task) {
        push(Work{nullptr, std::move(task)});
      });

  std::vector<std::unique_ptr<FakeRequest>> requests;
  std::vector<std::unique_ptr<std::atomic<int>>> resolutions;
  for (int i = 0; i < kTotal; ++i) {
    requests.push_back(std::make_unique<FakeRequest>(
        "chain", i % 3 == 0 ? "fail" : "example.com"));
    resolutions.push_back(std::make_unique<std::atomic<int>>(0));
  }

  std::vector<std::thread> workers;
  for (int w = 0; w < kWorkerThreads; ++w) {
    workers.emplace_back([&, w] {
      std::mt19937 rng(1000 + w);
      while (true) {
        Work work;
        {
          std::unique_lock<std::mutex> lock(queue_mutex);
          queue_cv.wait(lock, [&] { return !queue.empty() || done_producing; });
          if (queue.empty()) return;
          work = std::move(queue.front());
          queue.pop_front();
        }
        if (rng() % 4 == 0) std::this_thread::yield();
        if (work.task) {
          work.task();
          continue;
        }
        work.completion(rng() % 2 == 0 ? grpc::Status::OK : Unauthenticated());
        if (rng() % 5 == 0) work.completion(grpc::Status::OK);  // Duplicate.
      }
    });
  }

  std::atomic<int> async_resolutions{0};
  std::atomic<int> async_cancellations{0};
  // gRPC forbids invoking the callback from inside Verify() or Cancel().
  // Requester threads flag those calls; callbacks count violations.
  static thread_local bool inside_grpc_call = false;
  std::atomic<int> callbacks_inside_grpc_call{0};
  std::vector<std::thread> requesters;
  for (int t = 0; t < kRequesterThreads; ++t) {
    requesters.emplace_back([&, t] {
      std::mt19937 rng(t);
      for (int j = 0; j < kRequestsPerThread; ++j) {
        int i = t * kRequestsPerThread + j;
        std::atomic<int>* resolved = resolutions[i].get();
        grpc::Status sync_status;
        inside_grpc_call = true;
        bool is_sync = verifier.Verify(
            requests[i]->get(),
            [&, resolved](grpc::Status status) {
              if (inside_grpc_call) ++callbacks_inside_grpc_call;
              ++*resolved;
              ++async_resolutions;
              if (status.error_code() == grpc::StatusCode::CANCELLED) {
                ++async_cancellations;
              }
            },
            &sync_status);
        inside_grpc_call = false;
        if (is_sync) ++*resolved;
        if (rng() % 3 == 0) {
          if (rng() % 2 == 0) std::this_thread::yield();
          inside_grpc_call = true;
          verifier.Cancel(requests[i]->get());
          inside_grpc_call = false;
        }
      }
    });
  }

  for (auto& thread : requesters) thread.join();
  {
    std::lock_guard<std::mutex> lock(queue_mutex);
    done_producing = true;
    queue_cv.notify_all();
  }
  for (auto& thread : workers) thread.join();

  for (int i = 0; i < kTotal; ++i) {
    EXPECT_EQ(resolutions[i]->load(), 1) << "request " << i;
  }
  EXPECT_EQ(verifier.tracker()->pending_count(), 0u);
  // The interleavings above must actually have exercised the asynchronous
  // completion and cancellation paths.
  EXPECT_GT(async_resolutions.load(), 0);
  EXPECT_GT(async_cancellations.load(), 0);
  EXPECT_EQ(callbacks_inside_grpc_call.load(), 0);
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
