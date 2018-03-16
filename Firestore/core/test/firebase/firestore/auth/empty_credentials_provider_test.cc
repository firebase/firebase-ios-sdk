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

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"

#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace auth {

TEST(EmptyCredentialsProvider, GetToken) {
  EmptyCredentialsProvider credentials_provider;
  credentials_provider.GetToken(
      /*force_refresh=*/true, [](util::StatusOr<Token> token) {
        EXPECT_TRUE(token.ok());
        EXPECT_FALSE(token.ValueOrDie().is_valid());
        const User& user = token.ValueOrDie().user();
        EXPECT_EQ("", user.uid());
        EXPECT_FALSE(user.is_authenticated());
        // TODO(rsgowman): the next two statements just test the implementation
        // of StatusOr, so aren't useful here anymore. However, I'm keeping them
        // for one more commit, since it will shortly not be possible for a
        // StatusOr<Token> to be ok() while the token itself is not is_valid()
        EXPECT_EQ(FirestoreErrorCode::Ok, token.status().code());
        EXPECT_EQ("", token.status().error_message());
      });
}

TEST(EmptyCredentialsProvider, SetListener) {
  EmptyCredentialsProvider credentials_provider;
  credentials_provider.SetUserChangeListener([](User user) {
    EXPECT_EQ("", user.uid());
    EXPECT_FALSE(user.is_authenticated());
  });

  credentials_provider.SetUserChangeListener(nullptr);
}

}  // namespace auth
}  // namespace firestore
}  // namespace firebase
