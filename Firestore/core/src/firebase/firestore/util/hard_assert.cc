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

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

#include <cstdarg>
#include <stdexcept>
#include <string>

#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "absl/base/config.h"

namespace firebase {
namespace firestore {
namespace util {

ABSL_ATTRIBUTE_NORETURN void DefaultFailureHandler(const char* file,
                                                   const char* func,
                                                   const int line,
                                                   const std::string& message) {
  std::string failure =
      StringFormat("ASSERT: %s(%s) %s: %s", file, line, func, message);

#if ABSL_HAVE_EXCEPTIONS
  throw std::logic_error(failure);

#else
  fprintf(stderr, "%s\n", failure.c_str());
  std::terminate();
#endif
}

namespace {
FailureHandler failure_handler = DefaultFailureHandler;
}  // namespace

FailureHandler SetFailureHandler(FailureHandler callback) {
  FailureHandler previous = failure_handler;
  failure_handler = callback;
  return previous;
}

namespace internal {

void Fail(const char* file,
          const char* func,
          const int line,
          const std::string& message) {
  failure_handler(file, func, line, message);

  // It's expected that the failure handler above does not return. But if it
  // does, just terminate.
  std::terminate();
}

void Fail(const char* file,
          const char* func,
          const int line,
          const std::string& message,
          const char* condition) {
  std::string failure;
  if (message.empty()) {
    failure = condition;
  } else {
    failure = StringFormat("%s (expected %s)", message, condition);
  }
  Fail(file, func, line, failure);
}

}  // namespace internal
}  // namespace util
}  // namespace firestore
}  // namespace firebase
