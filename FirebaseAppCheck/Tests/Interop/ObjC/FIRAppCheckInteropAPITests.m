// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppCheckInteropAPITests : NSObject
@end

@implementation FIRAppCheckInteropAPITests

- (void)usage {
  id<FIRAppCheckInterop> appCheckInterop;

  [appCheckInterop getTokenForcingRefresh:NO
                               completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                                 NSString *__unused token = tokenResult.token;
                                 NSError *__unused _Nullable error = tokenResult.error;
                               }];

  NSString *__unused tokenDidChangeNotificationName =
      [appCheckInterop tokenDidChangeNotificationName];

  NSString *__unused notificationTokenKey = [appCheckInterop notificationTokenKey];

  NSString *__unused notificationAppNameKey = [appCheckInterop notificationAppNameKey];

  if ([appCheckInterop respondsToSelector:@selector(getLimitedUseTokenWithCompletion:)]) {
    [appCheckInterop
        getLimitedUseTokenWithCompletion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
          NSString *__unused token = tokenResult.token;
          NSError *__unused _Nullable error = tokenResult.error;
        }];
  }
}

@end

NS_ASSUME_NONNULL_END
