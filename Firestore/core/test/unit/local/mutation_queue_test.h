/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_MUTATION_QUEUE_TEST_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_MUTATION_QUEUE_TEST_H_

#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/local/mutation_queue.h"
#include "absl/strings/string_view.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

class MutationBatch;

}  // namespace model
namespace local {

class MutationQueue;
class Persistence;

using FactoryFunc = std::unique_ptr<Persistence> (*)();

/**
 * A test fixture for implementing tests of the MutationQueue interface.
 *
 * This is separate from MutationQueueTest below in order to make additional
 * implementation-specific tests.
 */
class MutationQueueTestBase : public testing::Test {
 public:
  explicit MutationQueueTestBase(std::unique_ptr<Persistence> persistence);
  virtual ~MutationQueueTestBase();

 protected:
  /**
   * Creates a new MutationBatch with the given key, the next batch ID and a set
   * of dummy mutations.
   */
  model::MutationBatch AddMutationBatch(absl::string_view key = "foo/bar");

  /**
   * Creates an array of batches containing `number` dummy MutationBatches.
   * Each has a new, larger batch_id.
   */
  std::vector<model::MutationBatch> CreateBatches(int number);

  /** Returns the number of mutation batches in the mutation queue. */
  size_t GetBatchCount();

  /**
   * Removes the first n entries from the given batches and returns them.
   *
   * @param n The number of batches to remove.
   * @param batches The container to mutate, removing entries from it.
   * @return A new vector containing all the entries that were removed from
   *     `batches`.
   */
  std::vector<model::MutationBatch> RemoveFirstBatches(
      size_t n, std::vector<model::MutationBatch>* batches);

  std::unique_ptr<Persistence> persistence_;
  MutationQueue* mutation_queue_ = nullptr;
};

/**
 * These are tests for any implementation of the MutationQueue interface.
 *
 * To test a specific implementation of MutationQueue:
 *
 * + Write a persistence factory function
 * + Call INSTANTIATE_TEST_SUITE_P(MyNewMutationQueueTest,
 *                                 MutationQueueTest,
 *                                 testing::Values(PersistenceFactory));
 */
class MutationQueueTest : public MutationQueueTestBase,
                          public testing::WithParamInterface<FactoryFunc> {
 public:
  // `GetParam()` must return a factory function.
  MutationQueueTest();
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_MUTATION_QUEUE_TEST_H_
