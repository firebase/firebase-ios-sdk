/*
 * Copyright 2017 Google
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

#import "Firestore/Source/Auth/FSTEmptyCredentialsProvider.h"

#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"

using firebase::firestore::auth::Token;
using firebase::firestore::auth::User;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTEmptyCredentialsProvider

- (void)getTokenForcingRefresh:(BOOL)forceRefresh
                    completion:(FSTVoidGetTokenResultBlock)completion {
  // Invalid token will force the GRPC fallback to use default settings.
  completion(Token::Invalid(), nil);
}

- (void)setUserChangeListener:(nullable FSTVoidUserBlock)block {
  // Since the user never changes, we just need to fire the initial event and don't need to hang
  // onto the block.
  if (block) {
    block(User::Unauthenticated());
  }
}

- (nullable FSTVoidUserBlock)userChangeListener {
  // TODO(mikelehen): Implementation omitted for convenience since it's not actually required.
  FSTFail(@"Not implemented.");
}

@end

NS_ASSUME_NONNULL_END
