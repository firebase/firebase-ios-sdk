/*
 * Copyright 2018 Google LLC
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

#ifndef FIRESTORE_CORE_TEST_UNIT_REMOTE_FAKE_CREDENTIALS_PROVIDER_H_
#define FIRESTORE_CORE_TEST_UNIT_REMOTE_FAKE_CREDENTIALS_PROVIDER_H_

#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/credentials/credentials_fwd.h"
#include "Firestore/core/src/credentials/empty_credentials_provider.h"

namespace firebase {
namespace firestore {
namespace remote {

template <class TokenType, class ValueType>
class FakeCredentialsProvider
    : public credentials::EmptyCredentialsProvider<TokenType, ValueType> {
 public:
  void GetToken(credentials::TokenListener<TokenType> completion) override {
    observed_states_.push_back("GetToken");

    if (delay_get_token_) {
      delayed_token_listener_ = completion;
      return;
    }

    if (fail_get_token_) {
      fail_get_token_ = false;
      if (completion) {
        completion(util::Status{Error::kErrorUnknown, ""});
      }
    } else {
      credentials::EmptyCredentialsProvider<TokenType, ValueType>::GetToken(
          std::move(completion));
    }
  }

  void InvalidateToken() override {
    observed_states_.push_back("InvalidateToken");
    credentials::EmptyCredentialsProvider<TokenType,
                                          ValueType>::InvalidateToken();
  }

  // `GetToken` will not invoke the completion immediately -- invoke it manually
  // using `InvokeGetToken`.
  void DelayGetToken() {
    delay_get_token_ = true;
  }

  void InvokeGetToken() {
    delay_get_token_ = false;
    credentials::EmptyCredentialsProvider<TokenType, ValueType>::GetToken(
        std::move(delayed_token_listener_));
  }

  // Next call to `GetToken` will fail with error "Unknown".
  void FailGetToken() {
    fail_get_token_ = true;
  }

  const std::vector<std::string>& observed_states() const {
    return observed_states_;
  }

 private:
  std::vector<std::string> observed_states_;
  bool fail_get_token_ = false;
  bool delay_get_token_ = false;
  credentials::TokenListener<TokenType> delayed_token_listener_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_REMOTE_FAKE_CREDENTIALS_PROVIDER_H_
