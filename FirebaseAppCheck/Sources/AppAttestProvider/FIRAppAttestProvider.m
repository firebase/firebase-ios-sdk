/*
 * Copyright 2021 Google LLC
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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppAttestProvider.h"

#import <AppCheckCore/AppCheckCore.h>

#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRHeartbeatLogger+AppCheck.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppAttestProvider ()

@property(nonatomic, readonly) GACAppAttestProvider *appAttestProvider;

@end

@implementation FIRAppAttestProvider

- (instancetype)initWithAppAttestProvider:(GACAppAttestProvider *)appAttestProvider {
  self = [super init];
  if (self) {
    _appAttestProvider = appAttestProvider;
  }
  return self;
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
  GACAppAttestProvider *appAttestProvider =
      [[GACAppAttestProvider alloc] initWithServiceName:app.name
                                           resourceName:app.resourceName
                                                baseURL:nil
                                                 APIKey:app.options.APIKey
                                    keychainAccessGroup:app.options.appGroupID
                                           requestHooks:@[ [app.heartbeatLogger requestHook] ]];

  return [self initWithAppAttestProvider:appAttestProvider];
}

#pragma mark - FIRAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable, NSError *_Nullable))handler {
  [self.appAttestProvider getTokenWithCompletion:^(GACAppCheckToken *_Nullable internalToken,
                                                   NSError *_Nullable error) {
    if (error) {
      handler(nil, error);
      return;
    }

    handler([[FIRAppCheckToken alloc] initWithInternalToken:internalToken], nil);
  }];
}

- (void)getLimitedUseTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable,
                                                   NSError *_Nullable))handler {
  [self.appAttestProvider getLimitedUseTokenWithCompletion:^(
                              GACAppCheckToken *_Nullable internalToken, NSError *_Nullable error) {
    if (error) {
      handler(nil, error);
      return;
    }

    handler([[FIRAppCheckToken alloc] initWithInternalToken:internalToken], nil);
  }];
}

@end

NS_ASSUME_NONNULL_END
