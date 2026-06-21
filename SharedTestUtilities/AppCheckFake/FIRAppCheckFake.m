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

#import "SharedTestUtilities/AppCheckFake/FIRAppCheckFake.h"

#import "SharedTestUtilities/AppCheckFake/FIRAppCheckTokenResultFake.h"

@implementation FIRAppCheckFake

- (instancetype)init {
  self = [super init];
  if (self) {
    _tokenResult = [[FIRAppCheckTokenResultFake alloc] initWithToken:@"fake_valid_token" error:nil];
    _limitedUseTokenResult =
        [[FIRAppCheckTokenResultFake alloc] initWithToken:@"fake_limited_use_valid_token"
                                                    error:nil];
  }
  return self;
}

- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(nonnull FIRAppCheckTokenHandlerInterop)handler {
  dispatch_async(dispatch_get_main_queue(), ^{
    handler(self.tokenResult);
  });
}

- (void)getLimitedUseTokenWithCompletion:(FIRAppCheckTokenHandlerInterop)handler {
  dispatch_async(dispatch_get_main_queue(), ^{
    handler(self.limitedUseTokenResult);
  });
}

- (nonnull NSString *)notificationAppNameKey {
  return @"AppCheckFakeAppNameNotificationKey";
}

- (nonnull NSString *)notificationTokenKey {
  return @"AppCheckFakeTokenNotificationKey";
}

- (nonnull NSString *)tokenDidChangeNotificationName {
  return @"AppCheckFakeTokenDidChangeNotification";
}

@end
