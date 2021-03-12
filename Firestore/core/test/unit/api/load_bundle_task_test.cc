/*
 * Copyright 2021 Google LLC
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

#include <chrono>  // NOLINT(build/c++11)
#include <mutex>   // NOLINT(build/c++11)
#include <queue>
#include <thread>  // NOLINT(build/c++11)

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/api/load_bundle_task.h"
#include "Firestore/core/src/util/executor.h"
#include "Firestore/core/src/util/status.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace api {
namespace {

using util::Executor;

std::unique_ptr<util::Executor> CreateUserQueue() {
  return Executor::CreateSerial("Testing User Queue");
}

class LoadBundleTaskTest : public ::testing::Test {
 public:
  LoadBundleTaskTest() : task(CreateUserQueue()) {
  }

 protected:
  LoadBundleTask task;
};

// A very naive implementation of blocking queue, only blocks on `pop()` though.
template <typename T>
class BlockingQueue {
 public:
  bool empty() {
    std::lock_guard<std::mutex> lock(mutex_);
    return queue_.empty();
  }

  void push(T v) {
    std::lock_guard<std::mutex> lock(mutex_);
    queue_.push(v);
  }

  T pop() {
    while (true) {
      std::this_thread::sleep_for(std::chrono::milliseconds(5));
      std::lock_guard<std::mutex> lock(mutex_);
      if (!queue_.empty()) {
        auto result = queue_.front();
        queue_.pop();
        return result;
      }
    }
  }

 private:
  std::queue<T> queue_;
  mutable std::mutex mutex_;
};

LoadBundleTaskProgress SuccessProgress() {
  return {/*documents_loaded=*/2,
          /*total_documents=*/2,
          /*bytes_loaded=*/10,
          /*total_bytes=*/10, LoadBundleTaskState::kSuccess};
}

LoadBundleTaskProgress ErrorProgress() {
  return {/*documents_loaded=*/0,
          /*total_documents=*/0,
          /*bytes_loaded=*/0,
          /*total_bytes=*/0,
          LoadBundleTaskState::kError,
          util::Status(Error::kErrorDataLoss, "error message")};
}

LoadBundleTaskProgress Progress(uint32_t documents_loaded,
                                uint64_t bytes_loaded) {
  return {documents_loaded, /*total_documents=*/2, bytes_loaded,
          /*total_bytes=*/10, LoadBundleTaskState::kInProgress};
}

LoadBundleTaskProgress InitialProgress() {
  return Progress(/*documents_loaded=*/0, /*bytes_loaded=*/0);
}

TEST_F(LoadBundleTaskTest, SetSuccessTriggersObservers) {
  BlockingQueue<LoadBundleTaskProgress> queue;

  task.Observe([&](LoadBundleTaskProgress p) { queue.push(p); });
  task.Observe([&](LoadBundleTaskProgress p) { queue.push(p); });

  task.SetSuccess(SuccessProgress());

  EXPECT_EQ(SuccessProgress(), queue.pop());
  EXPECT_EQ(SuccessProgress(), queue.pop());
}

TEST_F(LoadBundleTaskTest, RemovesObserverByHandle) {
  BlockingQueue<int> queue;

  auto handle1 = task.Observe(
      [&](LoadBundleTaskProgress) { FAIL() << "Removed observer is called."; });
  task.RemoveObserver(handle1);

  task.Observe([&](LoadBundleTaskProgress p) {
    EXPECT_EQ(p, SuccessProgress());
    queue.push(1);
  });

  task.SetSuccess(SuccessProgress());

  EXPECT_EQ(1, queue.pop());
}

TEST_F(LoadBundleTaskTest, SetErrorTriggersObservers) {
  util::Status status(firestore::Error::kErrorDataLoss, "error message");
  LoadBundleTask task(CreateUserQueue());
  BlockingQueue<LoadBundleTaskProgress> queue;

  task.Observe([&](LoadBundleTaskProgress p) {
    EXPECT_EQ(p, ErrorProgress());
    queue.push(p);
  });
  task.Observe([&](LoadBundleTaskProgress p) {
    EXPECT_EQ(p, ErrorProgress());
    queue.push(p);
  });

  task.SetError(status);

  EXPECT_EQ(ErrorProgress(), queue.pop());
  EXPECT_EQ(ErrorProgress(), queue.pop());
}

TEST_F(LoadBundleTaskTest, UpdateProgressTriggersObservers) {
  BlockingQueue<LoadBundleTaskProgress> queue;
  auto progress = Progress(1, 5);
  task.Observe([&](LoadBundleTaskProgress p) {
    EXPECT_EQ(p, progress);
    queue.push(p);
  });
  task.Observe([&](LoadBundleTaskProgress p) {
    EXPECT_EQ(p, progress);
    queue.push(p);
  });

  task.UpdateProgress(progress);

  EXPECT_EQ(progress, queue.pop());
  EXPECT_EQ(progress, queue.pop());
}

TEST_F(LoadBundleTaskTest, RemovesAllObservers) {
  task.Observe(
      [&](LoadBundleTaskProgress) { FAIL() << "Removed observer is called."; });
  task.Observe(
      [&](LoadBundleTaskProgress) { FAIL() << "Removed observer is called."; });
  task.Observe(
      [&](LoadBundleTaskProgress) { FAIL() << "Removed observer is called."; });
  task.RemoveAllObservers();

  task.UpdateProgress(Progress(1, 5));
  task.SetError(util::Status(Error::kErrorDataLoss, "error message"));

  BlockingQueue<int> queue;
  task.Observe([&](LoadBundleTaskProgress p) {
    EXPECT_EQ(p, SuccessProgress());
    queue.push(1);
  });
  task.SetSuccess(SuccessProgress());

  EXPECT_EQ(1, queue.pop());
}

TEST_F(LoadBundleTaskTest, ProgressesFireInOrder) {
  BlockingQueue<int> queue;
  task.Observe([&](LoadBundleTaskProgress) { queue.push(1); });
  task.Observe([&](LoadBundleTaskProgress) { queue.push(2); });
  task.Observe([&](LoadBundleTaskProgress) { queue.push(3); });

  task.SetSuccess(SuccessProgress());

  EXPECT_EQ(1, queue.pop());
  EXPECT_EQ(2, queue.pop());
  EXPECT_EQ(3, queue.pop());
}

TEST_F(LoadBundleTaskTest, ProgressObserverCanAddObserver) {
  BlockingQueue<int> queue;

  task.Observe([&](LoadBundleTaskProgress) {
    queue.push(1);

    task.Observe([&](LoadBundleTaskProgress) { queue.push(2); });
  });

  task.UpdateProgress(SuccessProgress());
  EXPECT_EQ(1, queue.pop());

  task.UpdateProgress(SuccessProgress());
  EXPECT_EQ(1, queue.pop());
  EXPECT_EQ(2, queue.pop());
}

TEST_F(LoadBundleTaskTest, ProgressObserverCanRemoveObserver) {
  BlockingQueue<int> queue;

  LoadBundleTask::LoadBundleHandle handle1;
  LoadBundleTask::LoadBundleHandle handle2;
  handle1 = task.Observe([&](LoadBundleTaskProgress) {
    queue.push(1);
    task.RemoveObserver(handle1);

    handle2 = task.Observe([&](LoadBundleTaskProgress) {
      queue.push(2);
      // handle3
      task.Observe([&](LoadBundleTaskProgress) {
        queue.push(3);
        task.RemoveObserver(handle2);
      });
    });
  });

  // Running handle1, which registers handle2 and removes itself
  task.UpdateProgress(SuccessProgress());
  EXPECT_EQ(1, queue.pop());

  // Running handle2, which registers handle3
  task.UpdateProgress(SuccessProgress());
  EXPECT_EQ(2, queue.pop());

  // Running handle2 and handle3. handle2 registers another handle3, then
  // handle3 removes handle2.
  task.UpdateProgress(SuccessProgress());
  EXPECT_EQ(2, queue.pop());
  EXPECT_EQ(3, queue.pop());

  // Running two handle3
  task.UpdateProgress(SuccessProgress());
  EXPECT_EQ(3, queue.pop());
  EXPECT_EQ(3, queue.pop());
  EXPECT_TRUE(queue.empty());
}

TEST_F(LoadBundleTaskTest, ProgressObservesUntilSuccess) {
  BlockingQueue<LoadBundleTaskProgress> queue;
  task.Observe([&](LoadBundleTaskProgress p) { queue.push(p); });

  task.UpdateProgress(InitialProgress());
  EXPECT_EQ(InitialProgress(), queue.pop());

  task.UpdateProgress(Progress(2, 5));
  EXPECT_EQ(Progress(2, 5), queue.pop());

  task.SetSuccess(SuccessProgress());
  EXPECT_EQ(SuccessProgress(), queue.pop());

  EXPECT_TRUE(queue.empty());
}

TEST_F(LoadBundleTaskTest, ProgressObservesUntilError) {
  BlockingQueue<LoadBundleTaskProgress> queue;
  task.Observe([&](LoadBundleTaskProgress p) { queue.push(p); });

  task.UpdateProgress(InitialProgress());
  EXPECT_EQ(InitialProgress(), queue.pop());

  task.UpdateProgress(Progress(2, 5));
  EXPECT_EQ(Progress(2, 5), queue.pop());

  util::Status error_status(Error::kErrorDataLoss, "error message");
  task.SetError(error_status);
  auto expected = Progress(2, 5);
  expected.set_state(LoadBundleTaskState::kError);
  expected.set_error_status(error_status);
  EXPECT_EQ(expected, queue.pop());

  EXPECT_TRUE(queue.empty());
}

TEST_F(LoadBundleTaskTest, ProgressObservesInitialError) {
  BlockingQueue<LoadBundleTaskProgress> queue;
  task.Observe([&](LoadBundleTaskProgress p) { queue.push(p); });

  util::Status error_status(Error::kErrorDataLoss, "error message");
  task.SetError(error_status);

  EXPECT_EQ(ErrorProgress(), queue.pop());
  EXPECT_TRUE(queue.empty());
}

TEST_F(LoadBundleTaskTest, NoObserversAlsoWork) {
  // No way to observe, simple checking no crashing happens.
  EXPECT_NO_FATAL_FAILURE({
    task.UpdateProgress(InitialProgress());
    task.UpdateProgress(Progress(2, 5));
    task.SetSuccess(SuccessProgress());
    task.SetError(util::Status(Error::kErrorDataLoss, "error message"));
  });
}

TEST_F(LoadBundleTaskTest, SetLastObserverIsHonored) {
  BlockingQueue<int> queue;
  task.SetLastObserver([&](LoadBundleTaskProgress) { queue.push(1); });
  task.Observe([&](LoadBundleTaskProgress) { queue.push(2); });

  task.UpdateProgress(InitialProgress());
  EXPECT_EQ(2, queue.pop());
  EXPECT_EQ(1, queue.pop());

  task.UpdateProgress(Progress(2, 5));
  EXPECT_EQ(2, queue.pop());
  EXPECT_EQ(1, queue.pop());

  task.SetSuccess(SuccessProgress());
  EXPECT_EQ(2, queue.pop());
  EXPECT_EQ(1, queue.pop());

  EXPECT_TRUE(queue.empty());
}

}  // namespace
}  // namespace api
}  // namespace firestore
}  // namespace firebase
