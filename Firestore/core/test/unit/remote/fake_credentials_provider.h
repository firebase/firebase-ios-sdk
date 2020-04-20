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
#include <vector>

#include "Firestore/core/src/auth/empty_credentials_provider.h"

namespace firebase {
namespace firestore {
namespace remote {

class FakeCredentialsProvider : public auth::EmptyCredentialsProvider {
 public:
  void GetToken(auth::TokenListener completion) override;
  void InvalidateToken() override;

  // `GetToken` will not invoke the completion immediately -- invoke it manually
  // using `InvokeGetToken`.
  void DelayGetToken();
  void InvokeGetToken();

  // Next call to `GetToken` will fail with error "Unknown".
  void FailGetToken();

  const std::vector<std::string>& observed_states() const {
    return observed_states_;
  }

 private:
  std::vector<std::string> observed_states_;
  bool fail_get_token_ = false;
  bool delay_get_token_ = false;
  auth::TokenListener delayed_token_listener_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_REMOTE_FAKE_CREDENTIALS_PROVIDER_H_
