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

#include "Firestore/core/test/firebase/firestore/util/executor_test.h"

#include <memory>

#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

using internal::Executor;

namespace {

inline std::unique_ptr<Executor> ExecutorFactory() {
  return std::unique_ptr<Executor>(new internal::ExecutorLibdispatch());
}

}  // namespace

INSTANTIATE_TEST_CASE_P(ExecutorTestLibdispatch,
                        ExecutorTest,
                        ::testing::Values(ExecutorFactory));

}  // namespace util
}  // namespace firestore
}  // namespace firebase
