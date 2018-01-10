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

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

#include <stdarg.h>

#include <exception>
#include <string>

#include <absl/base/config.h>

#include "Firestore/core/src/firebase/firestore/util/string_printf.h"

namespace firebase {
namespace firestore {
namespace util {

void FailAssert(const char* file,
                const char* func,
                const int line,
                const char* format,
                ...) {
  std::string message;
  StringAppendF(&message, "ASSERT: %s(%d) %s: ", file, line, func);

  va_list args;
  va_start(args, format);
  StringAppendV(&message, format, args);
  va_end(args);

#if ABSL_HAVE_EXCEPTIONS
  throw std::logic_error(message);

#else
  fprintf(stderr, "%s\n", message.c_str());
  std::terminate();
#endif
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
