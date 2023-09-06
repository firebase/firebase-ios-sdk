/*
 * Copyright 2023 Google
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

#include "thread_safe_memoizer.h"

namespace firebase {
namespace firestore {
namespace core {

template <typename T>
ThreadSafeMemoizer<T>::~ThreadSafeMemoizer() {
  // Call `std::call_once` in order to synchronize with the "active" invocation
  // of `memoize()`. Without this synchronization, there is a data race between
  // this destructor, which "reads" `filters_` to destroy it, and the write to
  // `filters_` done by the "active" invocation of `memoize()`.
  std::call_once(once_, [&]() {});
}

template <typename T>
const std::vector<T>& ThreadSafeMemoizer<T>::memoize(
    std::function<std::vector<T>()> func) {
  std::call_once(once_, [&]() { filters_ = func(); });
  return filters_;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
