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

#include "Firestore/core/src/firebase/firestore/util/exception.h"

#include <cstdlib>
#include <stdexcept>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

const char* ExceptionName(Exception exception) {
  switch (exception) {
    case Exception::AssertionFailure:
      return "FIRESTORE INTERNAL ASSERTION FAILED";
    case Exception::IllegalState:
      return "Illegal state";
    case Exception::InvalidArgument:
      return "Invalid argument";
  }
  UNREACHABLE();
}

ABSL_ATTRIBUTE_NORETURN void DefaultThrowHandler(Exception type,
                                                 const char* file,
                                                 const char* func,
                                                 int line,
                                                 const std::string& message) {
  std::string what = absl::StrCat(ExceptionName(type), ": ");
  if (file && func) {
    absl::StrAppend(&what, file, "(", line, ") ", func, ": ");
  }
  absl::StrAppend(&what, message);

#if ABSL_HAVE_EXCEPTIONS
  switch (type) {
    case Exception::AssertionFailure:
      throw FirestoreError(what);
    case Exception::IllegalState:
      throw std::logic_error(what);
    case Exception::InvalidArgument:
      throw std::invalid_argument(what);
  }
#else
  LOG_ERROR("%s", what);
  std::terminate();
#endif

  UNREACHABLE();
}

ThrowHandler throw_handler = DefaultThrowHandler;

}  // namespace

ThrowHandler SetThrowHandler(ThrowHandler handler) {
  ThrowHandler previous = throw_handler;
  throw_handler = handler;
  return previous;
}

ABSL_ATTRIBUTE_NORETURN void Throw(Exception exception,
                                   const char* file,
                                   const char* func,
                                   int line,
                                   const std::string& message) {
  throw_handler(exception, file, func, line, message);

  // It's expected that the throw handler above does not return. If it does,
  // just terminate.
  std::terminate();
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
