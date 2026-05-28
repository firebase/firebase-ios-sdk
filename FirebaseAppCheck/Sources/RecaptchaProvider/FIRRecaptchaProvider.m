/*
 * Copyright 2026 Google LLC
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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRRecaptchaProvider.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckAvailability.h"

#import <AppCheckCore/AppCheckCore.h>

#if SWIFT_PACKAGE
@import AppCheckRecaptchaEnterpriseProvider;
#elif __has_include(<AppCheckCore/AppCheckCore-Swift.h>)
#import <AppCheckCore/AppCheckCore-Swift.h>
#elif __has_include("AppCheckCore-Swift.h")
// If frameworks are not available, fall back to importing the header as it
// should be findable from a header search path pointing to the build
// directory. See #12611 for more context.
#import "AppCheckCore-Swift.h"
#endif

#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckValidator.h"
#import "FirebaseAppCheck/Sources/Core/FIRHeartbeatLogger+AppCheck.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

@interface FIRRecaptchaProvider ()

@property(nonatomic, readonly) id<GACAppCheckProvider> recaptchaProvider;

@end

@implementation FIRRecaptchaProvider

- (instancetype)initWithRecaptchaProvider:(id<GACAppCheckProvider>)recaptchaEnterpriseProvider {
  self = [super init];
  if (self) {
    _recaptchaProvider = recaptchaEnterpriseProvider;
  }
  return self;
}

- (nullable instancetype)initWithApp:(FIRApp *)app siteKey:(NSString *)siteKey {
  if (siteKey.length == 0) {
    FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageRecaptchaProviderIncompleteFIROptions,
                @"Cannot instantiate `%@` for app: %@. "
                @"`siteKey` is missing or empty.",
                NSStringFromClass([self class]), app.name);
    return nil;
  }
  NSArray<NSString *> *missingOptionsFields =
      [FIRAppCheckValidator tokenExchangeMissingFieldsInOptions:app.options];
  if (missingOptionsFields.count > 0) {
    FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageRecaptchaProviderIncompleteFIROptions,
                @"Cannot instantiate `%@` for app: %@. The following "
                @"`FirebaseOptions` fields are missing: %@",
                NSStringFromClass([self class]), app.name,
                [missingOptionsFields componentsJoinedByString:@", "]);
    return nil;
  }

  id heartbeatHook = [app.heartbeatLogger requestHook];
#if TARGET_OS_IOS
  GACRecaptchaEnterpriseProvider *recaptchaEnterpriseProvider =
      [[GACRecaptchaEnterpriseProvider alloc]
          initWithSiteKey:siteKey
             resourceName:app.resourceName
                   APIKey:app.options.APIKey
             requestHooks:heartbeatHook ? @[ heartbeatHook ] : @[]];

  return [self initWithRecaptchaProvider:recaptchaEnterpriseProvider];
#else
  return nil;
#endif
}

#pragma mark - FIRAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable token,
                                         NSError *_Nullable error))handler {
  [self.recaptchaProvider getTokenWithCompletion:^(GACAppCheckToken *_Nullable internalToken,
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
  [self.recaptchaProvider getLimitedUseTokenWithCompletion:^(
                              GACAppCheckToken *_Nullable internalToken, NSError *_Nullable error) {
    if (error) {
      handler(nil, error);
      return;
    }

    handler([[FIRAppCheckToken alloc] initWithInternalToken:internalToken], nil);
  }];
}

@end
