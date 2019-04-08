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

#include "Firestore/core/src/firebase/firestore/api/input_validation.h"

#include <cstdlib>
#include <stdexcept>

#include "Firestore/core/src/firebase/firestore/util/log.h"

namespace firebase {
namespace firestore {
namespace api {
namespace impl {

namespace {

template <typename T>
[[noreturn]] void Throw(const char* kind, const T& error) {
  LOG_ERROR("%s: %s", kind, error.what());
  std::abort();
}

}  // namespace

[[noreturn]] void ThrowIllegalState(const std::string& message) {
  Throw("Illegal state", std::logic_error(message));
}

[[noreturn]] void ThrowInvalidArgument(const std::string& message) {
  Throw("Invalid argument", std::invalid_argument(message));
}

}  // namespace impl
}  // namespace api
}  // namespace firestore
}  // namespace firebase
