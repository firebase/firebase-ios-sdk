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

#include "Firestore/core/src/credentials/auth_token.h"

#include <utility>

#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace credentials {

AuthToken::AuthToken() : token_{}, user_{User::Unauthenticated()} {
}

AuthToken::AuthToken(std::string token, User user)
    : token_{std::move(token)}, user_{std::move(user)} {
}

const std::string& AuthToken::token() const {
  HARD_ASSERT(user_.is_authenticated());
  return token_;
}

const AuthToken& AuthToken::Unauthenticated() {
  static const AuthToken kUnauthenticatedToken{};
  return kUnauthenticatedToken;
}

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase
