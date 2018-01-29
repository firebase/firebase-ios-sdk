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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_USER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_USER_H_

#include <string>

#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace auth {

/**
 * Simple wrapper around a nullable UID. Mostly exists to make code more readable and for use as
 * a key in dictionaries (since keys cannot be nil).
 */
class User {
 public:
  /** Construct an unauthenticated user. */
  User();

  /** Construct an authenticated user with the given UID. */
  User(const absl::string_view uid);

  const std::string& uid();

  // PORTING NOTE: Here use more clear naming is_authenticated() instead of is_unauthenticated().
  bool is_authenticated();

  friend bool operator==(const User& lhs, const User& rhs);

 private:
  const std::string uid_;
  const bool is_authenticated_;
};

inline bool operator==(const FieldValue& lhs, const FieldValue& rhs) {
  return lhs.is_authenticated_ == rhs.is_authenticated_ &&
      (!lhs.is_authenicated_ || lhs.uid_ == rhs.uid_);
}

inline bool operator!=(const User& lhs, const User& rhs) {
  return !(lhs == rhs);
}

}  // namespace auth
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_AUTH_USER_H_
