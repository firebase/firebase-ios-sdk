/*
 * Copyright 2017 Google LLC
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

#include "Firestore/core/src/util/random_access_queue.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(RandomAccessQueueTest, PushBackBasicFunctionality) {
  RandomAccessQueue<int> queue;

  EXPECT_TRUE(queue.push_back(10));
  EXPECT_EQ(queue.front(), 10);

  EXPECT_TRUE(queue.push_back(20));
  EXPECT_EQ(queue.front(), 10);

  EXPECT_FALSE(queue.push_back(10));
  EXPECT_FALSE(queue.push_back(20));
  EXPECT_EQ(queue.front(), 10);

  queue.pop_front();
  EXPECT_TRUE(queue.push_back(10));
  EXPECT_EQ(queue.front(), 20);

  queue.pop_front();
  EXPECT_EQ(queue.front(), 10);
}

TEST(RandomAccessQueueTest, PushBackOfRemovedElementInTheMiddle) {
  RandomAccessQueue<int> queue;

  EXPECT_TRUE(queue.push_back(10));
  EXPECT_TRUE(queue.push_back(20));
  EXPECT_TRUE(queue.push_back(30));

  EXPECT_TRUE(queue.remove(20));
  EXPECT_TRUE(queue.push_back(20));
  EXPECT_EQ(queue.front(), 10);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 30);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 20);
  queue.pop_front();
  EXPECT_TRUE(queue.empty());
}

TEST(RandomAccessQueueTest, PushBackOfRemovedElementInFront) {
  RandomAccessQueue<int> queue;

  EXPECT_TRUE(queue.push_back(10));
  EXPECT_TRUE(queue.push_back(20));
  EXPECT_TRUE(queue.push_back(30));

  EXPECT_TRUE(queue.remove(10));
  EXPECT_TRUE(queue.push_back(10));
  EXPECT_EQ(queue.front(), 20);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 30);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 10);
  queue.pop_front();
  EXPECT_TRUE(queue.empty());
}

TEST(RandomAccessQueueTest, PushBackOfRemovedElementInBack) {
  RandomAccessQueue<int> queue;

  EXPECT_TRUE(queue.push_back(10));
  EXPECT_TRUE(queue.push_back(20));
  EXPECT_TRUE(queue.push_back(30));

  EXPECT_TRUE(queue.remove(30));
  EXPECT_TRUE(queue.push_back(30));
  EXPECT_EQ(queue.front(), 10);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 20);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 30);
  queue.pop_front();
  EXPECT_TRUE(queue.empty());
}

TEST(RandomAccessQueueTest, FrontReturnsLeastRecentlyPushedElement) {
}

TEST(RandomAccessQueueTest, PopFrontRemovesLeastRecentlyPushedElement) {
}

TEST(RandomAccessQueueTest, PopFrontRemovesInterspersedRemovedElements) {
}

TEST(RandomAccessQueueTest, RemoveOfNonPresentElementDoesNothing) {
}

TEST(RandomAccessQueueTest, RemoveOfPresentElementRemovesIt) {
}

TEST(RandomAccessQueueTest, RemoveOfLastElementRemovesIt) {
}

TEST(RandomAccessQueueTest, EmptyReturnsTrueIfAndOnlyIfEmpty) {
}

TEST(RandomAccessQueueTest, ContainsReturnsTrueIfAndOnlyIfElementIsPresent) {
}

TEST(RandomAccessQueueTest, KeysReturnsTheListOfKeysInInsertionOrder) {
}

TEST(RandomAccessQueueTest, KeysSkipsRemovedElements) {
}

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
