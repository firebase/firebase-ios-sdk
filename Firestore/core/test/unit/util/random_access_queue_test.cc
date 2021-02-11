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

#include "Firestore/core/src/util/random_access_queue.h"

#include <utility>
#include <vector>

#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

using testing::ElementsAre;

TEST(RandomAccessQueueTest, CopyConstructor) {
  RandomAccessQueue<int> queue1;
  queue1.push_back(1);
  queue1.push_back(2);
  queue1.push_back(3);
  queue1.remove(2);
  RandomAccessQueue<int> queue2(queue1);
  EXPECT_THAT(queue1.elements(), ElementsAre(1, 3));
  EXPECT_THAT(queue2.elements(), ElementsAre(1, 3));
  queue1.remove(1);
  queue2.remove(3);
  EXPECT_THAT(queue1.elements(), ElementsAre(3));
  EXPECT_THAT(queue2.elements(), ElementsAre(1));
  EXPECT_TRUE(queue1.contains(3));
  EXPECT_FALSE(queue1.contains(1));
  EXPECT_TRUE(queue2.contains(1));
  EXPECT_FALSE(queue2.contains(3));
}

TEST(RandomAccessQueueTest, CopyOperator) {
  RandomAccessQueue<int> queue1;
  queue1.push_back(1);
  queue1.push_back(2);
  queue1.push_back(3);
  queue1.remove(2);
  RandomAccessQueue<int> queue2(queue1);
  queue2.push_back(10);
  queue2.push_back(11);
  queue2.push_back(12);
  queue2.remove(11);
  RandomAccessQueue<int>& copy_result = (queue2 = queue1);
  EXPECT_EQ(&copy_result, &queue2);
  EXPECT_THAT(queue1.elements(), ElementsAre(1, 3));
  EXPECT_THAT(queue2.elements(), ElementsAre(1, 3));
  queue1.remove(1);
  queue2.remove(3);
  EXPECT_THAT(queue1.elements(), ElementsAre(3));
  EXPECT_THAT(queue2.elements(), ElementsAre(1));
  EXPECT_TRUE(queue1.contains(3));
  EXPECT_FALSE(queue1.contains(1));
  EXPECT_TRUE(queue2.contains(1));
  EXPECT_FALSE(queue2.contains(3));
}

TEST(RandomAccessQueueTest, MoveConstructor) {
  RandomAccessQueue<int> queue1;
  queue1.push_back(1);
  queue1.push_back(2);
  queue1.push_back(3);
  queue1.remove(2);
  RandomAccessQueue<int> queue2(std::move(queue1));
  EXPECT_THAT(queue2.elements(), ElementsAre(1, 3));
  queue2.remove(3);
  EXPECT_THAT(queue2.elements(), ElementsAre(1));
  EXPECT_TRUE(queue2.contains(1));
  EXPECT_FALSE(queue2.contains(3));
}

TEST(RandomAccessQueueTest, MoveOperator) {
  RandomAccessQueue<int> queue1;
  queue1.push_back(1);
  queue1.push_back(2);
  queue1.push_back(3);
  queue1.remove(2);
  RandomAccessQueue<int> queue2(queue1);
  queue2.push_back(10);
  queue2.push_back(11);
  queue2.push_back(12);
  queue2.remove(11);
  RandomAccessQueue<int>& move_result = (queue2 = std::move(queue1));
  EXPECT_EQ(&move_result, &queue2);
  EXPECT_THAT(queue2.elements(), ElementsAre(1, 3));
  queue2.remove(3);
  EXPECT_THAT(queue2.elements(), ElementsAre(1));
  EXPECT_TRUE(queue2.contains(1));
  EXPECT_FALSE(queue2.contains(3));
}

TEST(RandomAccessQueueTest, ElementsShouldReturnEmptyIfQueueIsEmpty) {
  RandomAccessQueue<int> queue;
  std::vector<int> elements = queue.elements();
  EXPECT_EQ(elements, std::vector<int>());
}

TEST(RandomAccessQueueTest, ElementsShouldReturnThePushedElementsInOrder) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  std::vector<int> elements = queue.elements();
  EXPECT_EQ(elements, std::vector<int>({1, 2, 3, 4, 5}));
}

TEST(RandomAccessQueueTest,
     ElementsShouldReturnRePushedElementsInTheirOriginalPosition) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.push_back(3);
  queue.push_back(1);
  std::vector<int> elements = queue.elements();
  EXPECT_EQ(elements, std::vector<int>({1, 2, 3, 4, 5}));
}

TEST(RandomAccessQueueTest,
     ElementsShouldExcludeRemovedElementsInTheReturnedList) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.remove(2);
  queue.remove(4);
  std::vector<int> elements = queue.elements();
  EXPECT_EQ(elements, std::vector<int>({1, 3, 5}));
}

TEST(RandomAccessQueueTest,
     ElementsShouldIncludeRemovedThenPushedElementsInTheReturnedList) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.remove(2);
  queue.remove(4);
  queue.push_back(2);
  queue.push_back(4);
  std::vector<int> elements = queue.elements();
  EXPECT_EQ(elements, std::vector<int>({1, 3, 5, 2, 4}));
}

TEST(RandomAccessQueueTest, EmptyShouldReturnTrueOnANewlyCreatedQueue) {
  RandomAccessQueue<int> queue;
  EXPECT_TRUE(queue.empty());
}

TEST(RandomAccessQueueTest, EmptyShouldReturnFalseAfterTheFirstElementIsAdded) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  EXPECT_FALSE(queue.empty());
}

TEST(RandomAccessQueueTest, EmptyShouldReturnTrueAfterTheOnlyElementIsRemoved) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.remove(1);
  EXPECT_TRUE(queue.empty());
}

TEST(RandomAccessQueueTest, EmptyShouldReturnTrueAfterAllElementsAreRemoved) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  EXPECT_FALSE(queue.empty());
  queue.remove(1);
  EXPECT_FALSE(queue.empty());
  queue.remove(3);
  EXPECT_FALSE(queue.empty());
  queue.remove(2);
  EXPECT_TRUE(queue.empty());
}

TEST(RandomAccessQueueTest, EmptyShouldReturnFalseAfterAnElementIsReAdded) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.remove(2);
  queue.remove(1);
  EXPECT_TRUE(queue.empty());
  queue.push_back(1);
  EXPECT_FALSE(queue.empty());
}

TEST(RandomAccessQueueTest, ContainsShouldReturnFalseOnANewlyCreatedQueue) {
  RandomAccessQueue<int> queue;
  EXPECT_FALSE(queue.contains(0));
  EXPECT_FALSE(queue.contains(1));
}

TEST(RandomAccessQueueTest,
     ContainsShouldReturnCorrectValueWhenQueueContainsOneElement) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  EXPECT_TRUE(queue.contains(1));
  EXPECT_FALSE(queue.contains(2));
}

TEST(RandomAccessQueueTest, ContainsShouldReturnFalseForRemovedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  EXPECT_TRUE(queue.contains(1));
  EXPECT_TRUE(queue.contains(2));
  EXPECT_TRUE(queue.contains(3));
  queue.remove(1);
  EXPECT_FALSE(queue.contains(1));
  EXPECT_TRUE(queue.contains(2));
  EXPECT_TRUE(queue.contains(3));
  queue.remove(3);
  EXPECT_FALSE(queue.contains(1));
  EXPECT_TRUE(queue.contains(2));
  EXPECT_FALSE(queue.contains(3));
  queue.remove(2);
  EXPECT_FALSE(queue.contains(1));
  EXPECT_FALSE(queue.contains(2));
  EXPECT_FALSE(queue.contains(3));
}

TEST(RandomAccessQueueTest, ContainsShouldReturnTrueForReAddedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.remove(2);
  EXPECT_FALSE(queue.contains(2));
  queue.push_back(2);
  EXPECT_TRUE(queue.contains(2));
  queue.remove(2);
  EXPECT_FALSE(queue.contains(2));
  queue.push_back(2);
  EXPECT_TRUE(queue.contains(2));
}

TEST(RandomAccessQueueTest, RemoveReturnsFalseOnNewlyCreatedQueue) {
  RandomAccessQueue<int> queue;
  EXPECT_FALSE(queue.remove(0));
  EXPECT_FALSE(queue.remove(1));
}

TEST(RandomAccessQueueTest, RemoveReturnsTrueForOnlyElement) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  EXPECT_TRUE(queue.remove(1));
}

TEST(RandomAccessQueueTest, RemoveReturnsTrueForAllElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  EXPECT_TRUE(queue.remove(1));
  EXPECT_TRUE(queue.remove(5));
  EXPECT_TRUE(queue.remove(3));
  EXPECT_TRUE(queue.remove(4));
  EXPECT_TRUE(queue.remove(2));
}

TEST(RandomAccessQueueTest, RemoveReturnsTrueForReAddedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  EXPECT_TRUE(queue.remove(1));
  EXPECT_TRUE(queue.remove(3));
  EXPECT_TRUE(queue.remove(5));
  queue.push_back(1);
  queue.push_back(5);
  EXPECT_TRUE(queue.remove(1));
  EXPECT_FALSE(queue.remove(3));
  EXPECT_TRUE(queue.remove(5));
}

TEST(RandomAccessQueueTest, RemoveHasNoEffectOnNewlyCreatedQueue) {
  RandomAccessQueue<int> queue;
  queue.remove(0);
  queue.remove(1);
  EXPECT_THAT(queue.elements(), ElementsAre());
}

TEST(RandomAccessQueueTest, RemoveRemovesTheOnlyElement) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.remove(1);
  EXPECT_THAT(queue.elements(), ElementsAre());
}

TEST(RandomAccessQueueTest, RemoveRemovesAllElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.remove(1);
  EXPECT_THAT(queue.elements(), ElementsAre(2, 3, 4, 5));
  queue.remove(5);
  EXPECT_THAT(queue.elements(), ElementsAre(2, 3, 4));
  queue.remove(3);
  EXPECT_THAT(queue.elements(), ElementsAre(2, 4));
  queue.remove(4);
  EXPECT_THAT(queue.elements(), ElementsAre(2));
  queue.remove(2);
  EXPECT_THAT(queue.elements(), ElementsAre());
}

TEST(RandomAccessQueueTest, RemoveRemovesReAddedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.remove(1);
  queue.remove(3);
  queue.remove(5);
  queue.push_back(1);
  queue.push_back(5);
  EXPECT_THAT(queue.elements(), ElementsAre(2, 4, 1, 5));
  queue.remove(1);
  EXPECT_THAT(queue.elements(), ElementsAre(2, 4, 5));
  queue.remove(3);
  EXPECT_THAT(queue.elements(), ElementsAre(2, 4, 5));
  queue.remove(5);
  EXPECT_THAT(queue.elements(), ElementsAre(2, 4));
}

TEST(RandomAccessQueueTest, PopFrontRemovesTheOnlyElement) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre());
}

TEST(RandomAccessQueueTest, PopFrontRemovesTheAddedElementsInOrder) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre(2, 3, 4, 5));
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre(3, 4, 5));
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre(4, 5));
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre(5));
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre());
}

TEST(RandomAccessQueueTest, PopFrontExcludesRemovedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.remove(2);
  queue.remove(4);
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre(3, 5));
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre(5));
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre());
}

TEST(RandomAccessQueueTest, PopFrontIncludesReAddedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.remove(2);
  queue.remove(4);
  queue.push_back(2);
  queue.push_back(4);
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre(3, 5, 2, 4));
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre(5, 2, 4));
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre(2, 4));
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre(4));
  queue.pop_front();
  EXPECT_THAT(queue.elements(), ElementsAre());
}

TEST(RandomAccessQueueTest, FrontReturnsTheOnlyElement) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  EXPECT_EQ(queue.front(), 1);
}

TEST(RandomAccessQueueTest, FrontReturnsTheNewFrontAfterPopFront) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  EXPECT_EQ(queue.front(), 1);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 2);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 3);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 4);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 5);
}

TEST(RandomAccessQueueTest, FrontSkipsRemovedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.remove(1);
  queue.remove(3);
  queue.remove(5);
  EXPECT_EQ(queue.front(), 2);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 4);
}

TEST(RandomAccessQueueTest, FrontIncludesReAddedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.remove(1);
  queue.remove(3);
  queue.remove(5);
  queue.push_back(1);
  queue.push_back(3);
  queue.push_back(5);
  EXPECT_EQ(queue.front(), 2);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 4);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 1);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 3);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 5);
}

TEST(RandomAccessQueueTest,
     FrontRespectsOriginalPositionOfMultiplyAddedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(1);
  queue.push_back(2);
  queue.push_back(3);
  queue.push_back(4);
  queue.push_back(5);
  queue.push_back(1);
  queue.push_back(3);
  queue.push_back(5);
  EXPECT_EQ(queue.front(), 1);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 2);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 3);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 4);
  queue.pop_front();
  EXPECT_EQ(queue.front(), 5);
}

TEST(RandomAccessQueueTest, PushBackReturnsTrueForEachNewElement) {
  RandomAccessQueue<int> queue;
  EXPECT_TRUE(queue.push_back(0));
  EXPECT_TRUE(queue.push_back(1));
  EXPECT_TRUE(queue.push_back(2));
}

TEST(RandomAccessQueueTest, PushBackReturnsFalseForExistingElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(0);
  queue.push_back(1);
  queue.push_back(2);
  EXPECT_FALSE(queue.push_back(0));
  EXPECT_FALSE(queue.push_back(1));
  EXPECT_FALSE(queue.push_back(2));
}

TEST(RandomAccessQueueTest, PushBackReturnsTrueForRemovedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(0);
  queue.push_back(1);
  queue.push_back(2);
  queue.remove(0);
  queue.remove(2);
  EXPECT_TRUE(queue.push_back(0));
  EXPECT_FALSE(queue.push_back(1));
  EXPECT_TRUE(queue.push_back(2));
}

TEST(RandomAccessQueueTest, PushBackReturnsFalseForReAddedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(0);
  queue.push_back(1);
  queue.push_back(2);
  queue.remove(0);
  queue.remove(2);
  queue.push_back(0);
  queue.push_back(2);
  EXPECT_FALSE(queue.push_back(0));
  EXPECT_FALSE(queue.push_back(1));
  EXPECT_FALSE(queue.push_back(2));
}

TEST(RandomAccessQueueTest, PushBackAddsEachNewElement) {
  RandomAccessQueue<int> queue;
  queue.push_back(0);
  EXPECT_THAT(queue.elements(), ElementsAre(0));
  queue.push_back(1);
  EXPECT_THAT(queue.elements(), ElementsAre(0, 1));
  queue.push_back(2);
  EXPECT_THAT(queue.elements(), ElementsAre(0, 1, 2));
}

TEST(RandomAccessQueueTest, PushBackDoesNotChangeQueueIfElementExists) {
  RandomAccessQueue<int> queue;
  queue.push_back(0);
  queue.push_back(1);
  queue.push_back(2);
  EXPECT_THAT(queue.elements(), ElementsAre(0, 1, 2));
  queue.push_back(0);
  EXPECT_THAT(queue.elements(), ElementsAre(0, 1, 2));
  queue.push_back(1);
  EXPECT_THAT(queue.elements(), ElementsAre(0, 1, 2));
  queue.push_back(2);
  EXPECT_THAT(queue.elements(), ElementsAre(0, 1, 2));
}

TEST(RandomAccessQueueTest, PushBackCorrectlyAddsRemovedElementsToTheBack) {
  RandomAccessQueue<int> queue;
  queue.push_back(0);
  queue.push_back(1);
  queue.push_back(2);
  queue.remove(0);
  queue.remove(2);
  EXPECT_THAT(queue.elements(), ElementsAre(1));
  queue.push_back(0);
  EXPECT_THAT(queue.elements(), ElementsAre(1, 0));
  queue.push_back(2);
  EXPECT_THAT(queue.elements(), ElementsAre(1, 0, 2));
}

TEST(RandomAccessQueueTest, PushBackDoesNotChangeQueueForReAddedElements) {
  RandomAccessQueue<int> queue;
  queue.push_back(0);
  queue.push_back(1);
  queue.push_back(2);
  queue.remove(0);
  queue.remove(2);
  queue.push_back(0);
  queue.push_back(2);
  EXPECT_THAT(queue.elements(), ElementsAre(1, 0, 2));
  EXPECT_FALSE(queue.push_back(0));
  EXPECT_THAT(queue.elements(), ElementsAre(1, 0, 2));
  EXPECT_FALSE(queue.push_back(1));
  EXPECT_THAT(queue.elements(), ElementsAre(1, 0, 2));
  EXPECT_FALSE(queue.push_back(2));
  EXPECT_THAT(queue.elements(), ElementsAre(1, 0, 2));
}

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
