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

#include "Firestore/core/test/unit/remote/fake_credentials_provider.h"

#include <utility>

#include "Firestore/core/src/auth/empty_credentials_provider.h"
#include "Firestore/core/src/auth/token.h"
#include "Firestore/core/src/util/status.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::EmptyCredentialsProvider;
using auth::TokenListener;

void FakeCredentialsProvider::GetToken(TokenListener completion) {
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
    EmptyCredentialsProvider::GetToken(std::move(completion));
  }
}

void FakeCredentialsProvider::InvalidateToken() {
  observed_states_.push_back("InvalidateToken");
  EmptyCredentialsProvider::InvalidateToken();
}

void FakeCredentialsProvider::DelayGetToken() {
  delay_get_token_ = true;
}

void FakeCredentialsProvider::InvokeGetToken() {
  delay_get_token_ = false;
  EmptyCredentialsProvider::GetToken(std::move(delayed_token_listener_));
}

void FakeCredentialsProvider::FailGetToken() {
  fail_get_token_ = true;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
