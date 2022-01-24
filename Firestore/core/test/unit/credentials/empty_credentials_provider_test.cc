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

#include "Firestore/core/src/credentials/empty_credentials_provider.h"
#include "Firestore/core/src/credentials/credentials_fwd.h"

#include "Firestore/core/src/util/statusor.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace credentials {

TEST(EmptyAuthCredentialsProvider, GetToken) {
  EmptyAuthCredentialsProvider credentials_provider;
  credentials_provider.GetToken([](util::StatusOr<AuthToken> result) {
    EXPECT_TRUE(result.ok());
    const AuthToken& token = result.ValueOrDie();
    EXPECT_ANY_THROW(token.token());
    const User& user = token.user();
    EXPECT_EQ("", user.uid());
    EXPECT_FALSE(user.is_authenticated());
  });
}

TEST(EmptyAuthCredentialsProvider, SetListener) {
  EmptyAuthCredentialsProvider credentials_provider;
  credentials_provider.SetCredentialChangeListener([](User user) {
    EXPECT_EQ("", user.uid());
    EXPECT_FALSE(user.is_authenticated());
  });

  credentials_provider.SetCredentialChangeListener(nullptr);
}

TEST(EmptyCredentialsProvider, InvalidateToken) {
  EmptyAuthCredentialsProvider credentials_provider;
  credentials_provider.InvalidateToken();
  credentials_provider.GetToken(
      [](util::StatusOr<AuthToken> result) { EXPECT_TRUE(result.ok()); });
}

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase
