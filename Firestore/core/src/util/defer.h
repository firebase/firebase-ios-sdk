/*
 * Copyright 2020 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_UTIL_DEFER_H_
#define FIRESTORE_CORE_SRC_UTIL_DEFER_H_

#include <utility>

namespace firebase {
namespace firestore {
namespace util {

template <typename Action>
class Deferred;

/**
 * Creates a deferred action that will be destroyed at the close of the lexical
 * scope containing the result of this function call. This is useful for
 * performing ad-hoc RAII-style actions, without having to create the wrapper
 * class. For example:
 *
 *     FILE* file = fopen(filename, "rb");
 *     auto cleanup = defer([&] {
 *       if (file) {
 *         fclose(file);
 *       }
 *     });
 *
 * @param action a callable object; usually a lambda. Even if exceptions are
 *     enabled, when `action` is invoked it must not throw. This is similar to
 *     the restriction that exists on destructors generally.
 */
template <typename Action>
Deferred<Action> defer(Action&& action) {
  return Deferred<Action>(std::forward<Action>(action));
}

/**
 * Storage for a deferred action. The `action` is invoked during the destructor
 * of the `Deferred`.
 */
template <typename Action>
class Deferred {
 public:
  explicit Deferred(Action&& action) : action_(std::move(action)) {
  }

  ~Deferred() {
    action_();
  }

 private:
  Action action_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_DEFER_H_
