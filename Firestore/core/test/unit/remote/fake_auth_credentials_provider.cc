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

#include "Firestore/core/test/unit/remote/fake_auth_credentials_provider.h"

#include <utility>

#include "Firestore/core/src/credentials/auth_token.h"
#include "Firestore/core/src/credentials/empty_credentials_provider.h"
#include "Firestore/core/src/util/status.h"

namespace firebase {
namespace firestore {
namespace remote {

using credentials::EmptyAuthCredentialsProvider;
using credentials::TokenListener;

void FakeAuthCredentialsProvider::GetToken(
    TokenListener<credentials::AuthToken> completion) {
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
    EmptyAuthCredentialsProvider::GetToken(std::move(completion));
  }
}

void FakeAuthCredentialsProvider::DelayGetToken() {
  delay_get_token_ = true;
}

void FakeAuthCredentialsProvider::InvokeGetToken() {
  delay_get_token_ = false;
  EmptyAuthCredentialsProvider::GetToken(std::move(delayed_token_listener_));
}

void FakeAuthCredentialsProvider::FailGetToken() {
  fail_get_token_ = true;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
