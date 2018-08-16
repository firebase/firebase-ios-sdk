/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/remote/grpc_queue.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

TEST(GrpcCompletionQueueTest, IsShuttingDown) {
  GrpcCompletionQueue queue;
  EXPECT_FALSE(queue.IsShutDown());
  queue.Shutdown();
  EXPECT_TRUE(queue.IsShutDown());
}

TEST(GrpcCompletionQueueTest, NextReturnsNullAfterShutdown) {
  GrpcCompletionQueue queue;
  queue.Shutdown();
  bool ok = false;
  EXPECT_EQ(queue.Next(&ok), nullptr);
}

TEST(GrpcCompletionQueueTest, CannotShutDownTwice) {
  GrpcCompletionQueue queue;
  EXPECT_NO_THROW(queue.Shutdown());
  EXPECT_ANY_THROW(queue.Shutdown());
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
