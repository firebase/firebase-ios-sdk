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

#include "Firestore/core/src/credentials/credentials_provider.h"

#include "Firestore/core/src/util/statusor.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace credentials {

#define UNUSED(x) (void)(x)

TEST(CredentialsProvider, Typedef) {
  TokenListener<AuthToken> token_listener =
      [](util::StatusOr<AuthToken> token) { UNUSED(token); };
  EXPECT_NE(nullptr, token_listener);
  EXPECT_TRUE(token_listener);

  token_listener = nullptr;
  EXPECT_EQ(nullptr, token_listener);
  EXPECT_FALSE(token_listener);

  CredentialChangeListener<User> user_change_listener = [](User user) {
    UNUSED(user);
  };
  EXPECT_NE(nullptr, user_change_listener);
  EXPECT_TRUE(user_change_listener);

  user_change_listener = nullptr;
  EXPECT_EQ(nullptr, user_change_listener);
  EXPECT_FALSE(user_change_listener);
}

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase
