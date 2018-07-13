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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_HARD_ASSERT_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_HARD_ASSERT_H_

#include <string>

#include "Firestore/core/src/firebase/firestore/util/string_format.h"

#if defined(_MSC_VER)
#define FIRESTORE_FUNCTION_NAME __FUNCSIG__
#else
#define FIRESTORE_FUNCTION_NAME __PRETTY_FUNCTION__
#endif

/**
 * Fails the current function if the given condition is false.
 *
 * Unlike assert(3) or NSAssert, this macro is never compiled out.
 *
 * @param condition The condition to test.
 * @param format (optional) A format string suitable for util::StringFormat.
 * @param ... format arguments to pass to util::StringFormat.
 */
#define HARD_ASSERT(condition, ...)                                           \
  do {                                                                        \
    if (!(condition)) {                                                       \
      std::string _message =                                                  \
          firebase::firestore::util::StringFormat(__VA_ARGS__);               \
      firebase::firestore::util::internal::Fail(                              \
          __FILE__, FIRESTORE_FUNCTION_NAME, __LINE__, _message, #condition); \
    }                                                                         \
  } while (0)

/**
 * Unconditionally fails the current function.
 *
 * Unlike assert(3) or NSAssert, this macro is never compiled out.
 *
 * @param format A format string suitable for util::StringFormat.
 * @param ... format arguments to pass to util::StringFormat.
 */
#define HARD_FAIL(...)                                          \
  do {                                                          \
    std::string _failure =                                      \
        firebase::firestore::util::StringFormat(__VA_ARGS__);   \
    firebase::firestore::util::internal::Fail(                  \
        __FILE__, FIRESTORE_FUNCTION_NAME, __LINE__, _failure); \
  } while (0)

/**
 * Indicates an area of the code that cannot be reached (except possibly due to
 * undefined behaviour or other similar badness). The only reasonable thing to
 * do in these cases is to immediately abort.
 */
#define UNREACHABLE() abort()

namespace firebase {
namespace firestore {
namespace util {
namespace internal {

// A no-return helper function. To raise an assertion, use Macro instead.
ABSL_ATTRIBUTE_NORETURN void Fail(const char* file,
                                  const char* func,
                                  int line,
                                  const std::string& message);

ABSL_ATTRIBUTE_NORETURN void Fail(const char* file,
                                  const char* func,
                                  int line,
                                  const std::string& message,
                                  const char* condition);

}  // namespace internal
}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_HARD_ASSERT_H_
