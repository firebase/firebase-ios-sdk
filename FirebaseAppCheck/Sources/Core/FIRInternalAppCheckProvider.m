/*
 * Copyright 2023 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/FIRInternalAppCheckProvider.h"

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckProvider.h"

@interface FIRInternalAppCheckProvider ()

@property(nonatomic, readonly) id<FIRAppCheckProvider> appCheckProvider;

@end

@implementation FIRInternalAppCheckProvider

- (instancetype)initWithAppCheckProvider:(id<FIRAppCheckProvider>)appCheckProvider {
  if (self = [super init]) {
    _appCheckProvider = appCheckProvider;
  }

  return self;
}

- (void)getTokenWithCompletion:(void (^)(GACAppCheckToken *_Nullable, NSError *_Nullable))handler {
  [self.appCheckProvider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        handler([token internalToken], error);
      }];
}

- (void)getLimitedUseTokenWithCompletion:(nonnull void (^)(GACAppCheckToken *_Nullable,
                                                           NSError *_Nullable))handler {
  if ([self.appCheckProvider respondsToSelector:@selector(getLimitedUseTokenWithCompletion:)]) {
    [self.appCheckProvider getLimitedUseTokenWithCompletion:^(FIRAppCheckToken *_Nullable token,
                                                              NSError *_Nullable error) {
      handler([token internalToken], error);
    }];
  } else {
    [self getTokenWithCompletion:handler];
  }
}

@end
