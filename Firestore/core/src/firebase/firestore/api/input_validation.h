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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_INPUT_VALIDATION_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_INPUT_VALIDATION_H_

#include <string>

#include "Firestore/core/src/firebase/firestore/util/string_format.h"

namespace firebase {
namespace firestore {
namespace api {

namespace impl {

[[noreturn]] void ThrowIllegalState(const std::string& message);
[[noreturn]] void ThrowInvalidArgument(const std::string& message);

}  // namespace impl

/**
 * Throws an exception (or crashes, depending on platform) in response to API
 * usage errors. Avoids the lint warning you usually get when using @throw and
 * (unlike a function) doesn't trigger warnings about not all codepaths
 * returning a value.
 *
 * Exceptions should only be used for programmer errors made by consumers of the
 * SDK, e.g. invalid method arguments.
 *
 * For recoverable runtime errors, use NSError**.
 * For internal programming errors, use HARD_FAIL().
 */
template <typename... FA>
[[noreturn]] void ThrowInvalidArgument(const char* format, const FA&... args) {
  impl::ThrowInvalidArgument(util::StringFormat(format, args...));
}

/**
 * Throws an exception (or crashes, depending on platform) in response to API
 * usage errors. Avoids the lint warning you usually get when using @throw and
 * (unlike a function) doesn't trigger warnings about not all codepaths
 * returning a value.
 *
 * Exceptions should only be used for programmer errors made by consumers of the
 * SDK, e.g. invalid method arguments.
 *
 * For recoverable runtime errors, use NSError**.
 * For internal programming errors, use HARD_FAIL().
 */
template <typename... FA>
[[noreturn]] void ThrowIllegalState(const char* format, const FA&... args) {
  impl::ThrowIllegalState(util::StringFormat(format, args...));
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_INPUT_VALIDATION_H_
