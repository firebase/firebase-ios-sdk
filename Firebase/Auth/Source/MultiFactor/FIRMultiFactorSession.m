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

#import "FIRMultiFactorSession.h"
#import "FIRMultiFactorSession+Internal.h"

#import "FIRAuth.h"
#import "FIRUser_Internal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRMultiFactorSession

#pragma mark - Private

- (instancetype)initWithIDToken:(NSString *)idToken {
  self = [super init];
  if (self) {
    _idToken = idToken;
  }
  return self;
}

#pragma mark - Internal

+ (FIRMultiFactorSession *)sessionForCurrentUser {
  FIRUser *currentUser = [[FIRAuth auth] currentUser];
  NSString *idToken = currentUser.rawAccessToken;
  FIRMultiFactorSession *session = [[FIRMultiFactorSession alloc] initWithIDToken:idToken];
  return session;
}

@end

NS_ASSUME_NONNULL_END
