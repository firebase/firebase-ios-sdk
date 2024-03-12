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

#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeyEnrollmentResponse.h"

/**
 @var kIDTokenKey
 @brief The name of the field in the response JSON for id token.
 */
static const NSString *kIdTokenKey = @"idToken";

/**
 @var kRefreshTokenKey
 @brief The name of the field in the response JSON for refresh token.
 */
static const NSString *kRefreshTokenKey = @"refreshToken";

@implementation FIRFinalizePasskeyEnrollmentResponse

- (BOOL)setWithDictionary:(nonnull NSDictionary *)dictionary
                    error:(NSError *__autoreleasing _Nullable *_Nullable)error {
  if (dictionary[kIdTokenKey] == nil) {
    return NO;
  }
  if (dictionary[kRefreshTokenKey] == nil) {
    return NO;
  }

  _idToken = dictionary[kIdTokenKey];
  _refreshToken = dictionary[kRefreshTokenKey];
  return YES;
}

@end
