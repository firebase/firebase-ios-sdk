/*
 * Copyright 2019 Google
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

#import "FIRAppleAuthProvider.h"

#import "FIRAppleAuthCredential.h"
#import "FIRAuthExceptionUtils.h"

// FIRAppleAuthProviderID is defined in FIRAuthProvider.m.

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAppleAuthProvider

- (instancetype)init {
  [FIRAuthExceptionUtils raiseMethodNotImplementedExceptionWithReason:
   @"This class is not meant to be initialized."];
  return nil;
}

+ (FIRAuthCredential *)credentialWithAppleIDCredential:(ASAuthorizationAppleIDCredential *)credential API_AVAILABLE(ios(13.0)){
  return [[FIRAppleAuthCredential alloc] initWithAuthorizationCredential:credential];
}

+ (FIRAuthCredential *)credentialWithPasswordCredential: (ASPasswordCredential *)credential  API_AVAILABLE(ios(12.0)) {
  return [[FIRAppleAuthCredential alloc] initWithPasswordCredential: credential];
}

@end

NS_ASSUME_NONNULL_END
