/*
 * Copyright 2019 Google
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

#import "FirebaseAuth/Sources/Backend/RPC/FIRStartPasskeyEnrollmentResponse.h"

/**
 @var kOptionsKey
 @brief The name of the field in the response JSON for CredentialCreationOptions.
 */
static const NSString *kOptionsKey = @"credentialCreationOptions";

/**
 @var kRpKey
 @brief The name of the field in the response JSON for Relying Party.
 */
static const NSString *kRpKey = @"rp";

/**
 @var kUserKey
 @brief The name of the field in the response JSON for User.
 */
static const NSString *kUserKey = @"user";

/**
 @var kIDKey
 @brief The name of the field in the response JSON for ids.
 */
static const NSString *kIDKey = @"id";

/**
 @var kChallengeKey
 @brief The name of the field in the response JSON for challenge.
 */
static const NSString *kChallengeKey = @"challenge";

@implementation FIRStartPasskeyEnrollmentResponse

- (BOOL)setWithDictionary:(nonnull NSDictionary *)dictionary
                    error:(NSError *__autoreleasing _Nullable *_Nullable)error {
  if (dictionary[kOptionsKey] == nil) {
    return NO;
  }
  if (dictionary[kOptionsKey][kRpKey] == nil || dictionary[kOptionsKey][kRpKey][kIDKey] == nil) {
    return NO;
  }

  if (dictionary[kOptionsKey][kUserKey] == nil ||
      dictionary[kOptionsKey][kUserKey][kIDKey] == nil) {
    return NO;
  }

  if (dictionary[kOptionsKey][kChallengeKey] == nil) {
    return NO;
  }

  _rpID = dictionary[kOptionsKey][kRpKey][kIDKey];
  _userID = dictionary[kOptionsKey][kUserKey][kIDKey];
  _challenge = dictionary[kOptionsKey][kChallengeKey];
  return YES;
}

@end
