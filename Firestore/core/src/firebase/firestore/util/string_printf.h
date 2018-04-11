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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_STRING_PRINTF_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_STRING_PRINTF_H_

#include <cstdarg>
#include <string>

#include "absl/base/attributes.h"

namespace firebase {
namespace firestore {
namespace util {

/** Return a C++ string. */
std::string StringPrintf(const char* format, ...) ABSL_PRINTF_ATTRIBUTE(1, 2);

/** Append result to a supplied string. */
void StringAppendF(std::string* dst, const char* format, ...)
    ABSL_PRINTF_ATTRIBUTE(2, 3);

/**
 * Lower-level routine that takes a va_list and appends to a specified
 * string.  All other routines are just convenience wrappers around it.
 */
void StringAppendV(std::string* dst, const char* format, va_list ap);

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_STRING_PRINTF_H_
