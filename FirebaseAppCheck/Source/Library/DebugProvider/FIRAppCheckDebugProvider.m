/*
 * Copyright 2020 Google LLC
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

#import "FirebaseAppCheck/Source/Library/DebugProvider/Public/FIRAppCheckDebugProvider.h"

#import "FirebaseAppCheck/Source/Library/Core/Private/FIRAppCheckInternal.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kDebugTokenEnvKey = @"FIRAAppCheckDebugToken";
static NSString *const kDebugTokenUserDefaultsKey = @"FIRAAppCheckDebugToken";

@implementation FIRAppCheckDebugProvider

- (NSString *)currentDebugToken {
  NSString *envVariableValue = [[NSProcessInfo processInfo] environment][kDebugTokenEnvKey];
  if (envVariableValue.length > 0) {
    return envVariableValue;
  } else {
    return [self localDebugToken];
  }
}

- (NSString *)localDebugToken {
  return [self storedDebugToken] ?: [self generateAndStoreDebugToken];
}

- (nullable NSString *)storedDebugToken {
  return [[NSUserDefaults standardUserDefaults] stringForKey:kDebugTokenUserDefaultsKey];
}

- (void)storeDebugToken:(nullable NSString *)token {
  [[NSUserDefaults standardUserDefaults] setObject:token forKey:kDebugTokenUserDefaultsKey];
}

- (NSString *)generateAndStoreDebugToken {
  NSString *token = [NSUUID UUID].UUIDString;
  [self storeDebugToken:token];
  return token;
}

#pragma mark - FIRAppCheckProvider

- (void)getTokenWithCompletion:(FIRAppCheckTokenHandler)handler {
  // The client doesn't know the token expiration date. Use `+[NSDate distantFuture]` to disable
  // expiration validation for it.
  FIRAppCheckToken *token = [[FIRAppCheckToken alloc] initWithToken:[self currentDebugToken]
                                                     expirationDate:[NSDate distantFuture]];
  handler(token, nil);
}

@end

NS_ASSUME_NONNULL_END
