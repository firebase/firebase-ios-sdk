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

#ifndef FIRESTORE_CORE_SRC_CREDENTIALS_EMPTY_CREDENTIALS_PROVIDER_H_
#define FIRESTORE_CORE_SRC_CREDENTIALS_EMPTY_CREDENTIALS_PROVIDER_H_

#include "Firestore/core/src/credentials/credentials_provider.h"

namespace firebase {
namespace firestore {
namespace credentials {

/** `EmptyCredentialsProvider` always yields an empty token. */
template <class TokenType, class ValueType>
class EmptyCredentialsProvider
    : public CredentialsProvider<TokenType, ValueType> {
 public:
  void GetToken(TokenListener<TokenType> completion) override {
    if (completion) {
      // Unauthenticated token will force the GRPC fallback to use default
      // settings.
      completion(TokenType{});
    }
  }

  void SetCredentialChangeListener(
      CredentialChangeListener<ValueType> change_listener) override {
    if (change_listener) {
      change_listener(ValueType{});
    }
  }
};

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CREDENTIALS_EMPTY_CREDENTIALS_PROVIDER_H_
