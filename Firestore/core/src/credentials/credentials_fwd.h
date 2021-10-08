/*
 * Copyright 2021 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_CREDENTIALS_CREDENTIALS_FWD_H_
#define FIRESTORE_CORE_SRC_CREDENTIALS_CREDENTIALS_FWD_H_

#include <string>

namespace firebase {
namespace firestore {
namespace credentials {

class AuthToken;

template <class TokenType, class ValueType>
class CredentialsProvider;

template <class TokenType, class ValueType>
class EmptyCredentialsProvider;

class User;

using AuthCredentialsProvider = CredentialsProvider<AuthToken, User>;
using AppCheckCredentialsProvider =
    CredentialsProvider<std::string, std::string>;

using EmptyAuthCredentialsProvider = EmptyCredentialsProvider<AuthToken, User>;
using EmptyAppCheckCredentialsProvider =
    EmptyCredentialsProvider<std::string, std::string>;

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CREDENTIALS_CREDENTIALS_FWD_H_
