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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckAvailability.h"

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRDeviceCheckProvider.h"

#import <AppCheckCore/AppCheckCore.h>

#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckValidator.h"
#import "FirebaseAppCheck/Sources/Core/FIRHeartbeatLogger+AppCheck.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRDeviceCheckProvider ()

@property(nonatomic, readonly) GACDeviceCheckProvider *deviceCheckProvider;

@end

@implementation FIRDeviceCheckProvider

- (instancetype)initWithDeviceCheckProvider:(GACDeviceCheckProvider *)deviceCheckProvider {
  self = [super init];
  if (self) {
    _deviceCheckProvider = deviceCheckProvider;
  }
  return self;
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
  NSArray<NSString *> *missingOptionsFields =
      [FIRAppCheckValidator tokenExchangeMissingFieldsInOptions:app.options];
  if (missingOptionsFields.count > 0) {
    FIRLogError(kFIRLoggerAppCheck,
                kFIRLoggerAppCheckMessageDeviceCheckProviderIncompleteFIROptions,
                @"Cannot instantiate `FIRDeviceCheckProvider` for app: %@. The following "
                @"`FirebaseOptions` fields are missing: %@",
                app.name, [missingOptionsFields componentsJoinedByString:@", "]);
    return nil;
  }

  GACDeviceCheckProvider *deviceCheckProvider =
      [[GACDeviceCheckProvider alloc] initWithServiceName:app.name
                                             resourceName:app.resourceName
                                                   APIKey:app.options.APIKey
                                             requestHooks:@[ [app.heartbeatLogger requestHook] ]];

  return [self initWithDeviceCheckProvider:deviceCheckProvider];
}

#pragma mark - FIRAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable token,
                                         NSError *_Nullable error))handler {
  [self.deviceCheckProvider getTokenWithCompletion:^(GACAppCheckToken *_Nullable internalToken,
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
  [self.deviceCheckProvider
      getLimitedUseTokenWithCompletion:^(GACAppCheckToken *_Nullable internalToken,
                                         NSError *_Nullable error) {
        if (error) {
          handler(nil, error);
          return;
        }

        handler([[FIRAppCheckToken alloc] initWithInternalToken:internalToken], nil);
      }];
}

@end

NS_ASSUME_NONNULL_END
