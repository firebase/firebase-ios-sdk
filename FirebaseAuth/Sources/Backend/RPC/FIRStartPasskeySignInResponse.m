/*
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FirebaseAuth/Sources/Backend/RPC/FIRStartPasskeySignInResponse.h"

/**
 @var kOptionsKey
 @brief Parameters specified for the authenticator to sign a challenge.
 */
static const NSString *kOptionsKey = @"credentialRequestOptions";

/**
 @var kRpIdKey
 @brief The relying party identifier.
 */
static const NSString *kRpIdKey = @"rpId";

/**
 @var kChallengeKey
 @brief The name of the field in the response JSON for challenge.
 */
static const NSString *kChallengeKey = @"challenge";

@implementation FIRStartPasskeySignInResponse

- (BOOL)setWithDictionary:(nonnull NSDictionary *)dictionary
                    error:(NSError *__autoreleasing _Nullable *_Nullable)error {
  if (dictionary[kOptionsKey] == nil) {
    return NO;
  }
  if (dictionary[kOptionsKey][kRpIdKey] == nil) {
    return NO;
  }
  if (dictionary[kOptionsKey][kChallengeKey] == nil) {
    return NO;
  }

  _rpID = dictionary[kOptionsKey][kRpIdKey];
  _challenge = dictionary[kOptionsKey][kChallengeKey];
  return YES;
}

@end
