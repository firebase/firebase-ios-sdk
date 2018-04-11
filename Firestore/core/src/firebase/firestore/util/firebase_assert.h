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

// To avoid naming-collision, this header is called firebase_assert.h instead
// of assert.h.

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_FIREBASE_ASSERT_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_FIREBASE_ASSERT_H_

#include <cstdlib>

#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "absl/base/attributes.h"

#define FIREBASE_EXPAND_STRINGIFY_(X) #X
#define FIREBASE_EXPAND_STRINGIFY(X) FIREBASE_EXPAND_STRINGIFY_(X)

// FIREBASE_ASSERT_* macros are not compiled out of release builds. They should
// be used for assertions that need to be propagated to end-users of SDKs.
// FIREBASE_DEV_ASSERT_* macros are compiled out of release builds, similar to
// the C assert() macro. They should be used for internal assertions that are
// only shown to SDK developers.

// Assert condition is true, if it's false log an assert with the specified
// expression as a string.
#define FIREBASE_ASSERT_WITH_EXPRESSION(condition, expression) \
  do {                                                         \
    if (!(condition)) {                                        \
      firebase::firestore::util::FailAssert(                   \
          __FILE__, __PRETTY_FUNCTION__, __LINE__,             \
          FIREBASE_EXPAND_STRINGIFY(expression));              \
    }                                                          \
  } while (0)

// Assert condition is true, if it's false log an assert with the specified
// expression as a string. Compiled out of release builds.
#if defined(NDEBUG)
#define FIREBASE_DEV_ASSERT_WITH_EXPRESSION(condition, expression) \
  { (void)(condition); }
#else
#define FIREBASE_DEV_ASSERT_WITH_EXPRESSION(condition, expression) \
  FIREBASE_ASSERT_WITH_EXPRESSION(condition, expression)
#endif  // defined(NDEBUG)

// Custom assert() implementation that is not compiled out in release builds.
#define FIREBASE_ASSERT(expression) \
  FIREBASE_ASSERT_WITH_EXPRESSION(expression, expression)

// Custom assert() implementation that is compiled out in release builds.
// Compiled out of release builds.
#define FIREBASE_DEV_ASSERT(expression) \
  FIREBASE_DEV_ASSERT_WITH_EXPRESSION(expression, expression)

// Assert condition is true otherwise display the specified expression,
// message and abort.
#define FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(condition, expression, ...) \
  do {                                                                      \
    if (!(condition)) {                                                     \
      firebase::firestore::util::LogError(                                  \
          FIREBASE_EXPAND_STRINGIFY(expression));                           \
      firebase::firestore::util::FailAssert(__FILE__, __PRETTY_FUNCTION__,  \
                                            __LINE__, __VA_ARGS__);         \
    }                                                                       \
  } while (0)

// Assert condition is true otherwise display the specified expression,
// message and abort. Compiled out of release builds.
#if defined(NDEBUG)
#define FIREBASE_DEV_ASSERT_MESSAGE_WITH_EXPRESSION(condition, expression, \
                                                    ...)                   \
  { (void)(condition); }
#else
#define FIREBASE_DEV_ASSERT_MESSAGE_WITH_EXPRESSION(condition, expression, \
                                                    ...)                   \
  FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(condition, expression, __VA_ARGS__)
#endif  // defined(NDEBUG)

// Assert expression is true otherwise display the specified message and
// abort.
#define FIREBASE_ASSERT_MESSAGE(expression, ...) \
  FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(expression, expression, __VA_ARGS__)

// Assert expression is true otherwise display the specified message and
// abort. Compiled out of release builds.
#define FIREBASE_DEV_ASSERT_MESSAGE(expression, ...)                  \
  FIREBASE_DEV_ASSERT_MESSAGE_WITH_EXPRESSION(expression, expression, \
                                              __VA_ARGS__)

// Indicates an area of the code that cannot be reached (except possibly due to
// undefined behaviour or other similar badness). The only reasonable thing to
// do in these cases is to immediately abort.
#define FIREBASE_UNREACHABLE() abort()

namespace firebase {
namespace firestore {
namespace util {

// A no-return helper function. To raise an assertion, use Macro instead.
ABSL_ATTRIBUTE_NORETURN void FailAssert(
    const char* file, const char* func, int line, const char* format, ...);

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_FIREBASE_ASSERT_H_
