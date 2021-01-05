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

#import "SharedTestUtilities/FIRAuthInteropFake.h"

#import "Interop/Auth/Public/FIRAuthInterop.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAuthInteropFake

- (instancetype)initWithToken:(nullable NSString *)token
                       userID:(nullable NSString *)userID
                        error:(nullable NSError *)error {
  self = [super init];
  if (self) {
    _token = [token copy];
    _userID = [userID copy];
    _error = [error copy];
  }
  return self;
}

- (void)getTokenForcingRefresh:(BOOL)forceRefresh withCallback:(FIRTokenCallback)callback {
  callback(self.token, self.error);
}

- (nullable NSString *)getUserID {
  return _userID;
}

@end

NS_ASSUME_NONNULL_END
