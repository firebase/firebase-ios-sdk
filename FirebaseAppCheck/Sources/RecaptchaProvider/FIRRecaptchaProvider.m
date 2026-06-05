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
#import "FirebaseAppCheck/Sources/RecaptchaProvider/FIRRecaptchaProvider+Internal.h"

#import <AppCheckCore/AppCheckCore.h>

#if SWIFT_PACKAGE
@import AppCheckRecaptchaProvider;
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

@interface FIRRecaptchaProvider ()

@property(nonatomic, readonly) id<GACAppCheckProvider> recaptchaProvider;

- (instancetype)initWithRecaptchaProvider:(id<GACAppCheckProvider>)recaptchaProvider;

@end

@implementation FIRRecaptchaProvider

+ (BOOL)isSupported {
  // TODO(ncooke3): This implementation should also take into account
  // OS versions based on whether we decorate the APIs with OS constraints.
#if TARGET_OS_IOS || TARGET_OS_VISION
  return [GACRecaptchaProvider isRecaptchaEnterpriseSDKLinked];
#else
  return NO;
#endif
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
  // 1. Validate options and raise exceptions on invalid configuration
  NSString *siteKey = app.options.recaptchaSiteKey;
  if (siteKey.length == 0) {
    NSString *message = [NSString
        stringWithFormat:
            @"Cannot instantiate `RecaptchaProvider` for app: %@. "
            @"`FirebaseOptions.recaptchaSiteKey` "
            @"is missing or empty. "
            @"Please ensure you have added `RECAPTCHA_SITE_KEY` to your `GoogleService-Info.plist` "
            @"or set `recaptchaSiteKey` on `FirebaseOptions` programmatically.",
            app.name];
    FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageRecaptchaProviderMissingSiteKey, @"%@",
                message);
    [NSException raise:NSInvalidArgumentException format:@"%@", message];
  }
  NSArray<NSString *> *missingOptionsFields =
      [FIRAppCheckValidator tokenExchangeMissingFieldsInOptions:app.options];
  if (missingOptionsFields.count > 0) {
    FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageRecaptchaProviderIncompleteFIROptions,
                @"Cannot instantiate `RecaptchaProvider` for app: %@. The following "
                @"`FirebaseOptions` fields are "
                @"missing: %@. "
                @"Please ensure your `GoogleService-Info.plist` is complete or these fields are "
                @"set on `FirebaseOptions` programmatically.",
                app.name, [missingOptionsFields componentsJoinedByString:@", "]);
    return nil;
  }

  // 2. Validate SDK Linkage
#if TARGET_OS_IOS || TARGET_OS_VISION
  if (![FIRRecaptchaProvider isSupported]) {
    NSString *message = [NSString
        stringWithFormat:
            @"Cannot instantiate `RecaptchaProvider` for app: %@. The reCAPTCHA Enterprise SDK "
            @"is "
            @"not linked. "
            @"Please ensure you have installed the `FirebaseAppCheck` package along with "
            @"the underlying reCAPTCHA Enterprise dependency. "
            @"See "
            @"https://cloud.google.com/recaptcha/docs/instrument-ios-apps#prepare-environment "
            @"for details.",
            app.name];
    FIRLogError(kFIRLoggerAppCheck,
                kFIRLoggerAppCheckMessageRecaptchaProviderMissingRecaptchaEnterpriseSDK, @"%@",
                message);
    [NSException raise:NSInternalInconsistencyException format:@"%@", message];
  }

  id heartbeatHook = [app.heartbeatLogger requestHook];
  GACRecaptchaProvider *recaptchaProvider =
      [[GACRecaptchaProvider alloc] initWithSiteKey:siteKey
                                       resourceName:app.resourceName
                                             APIKey:app.options.APIKey
                                       requestHooks:heartbeatHook ? @[ heartbeatHook ] : @[]];

  return [self initWithRecaptchaProvider:recaptchaProvider];
#else
  return nil;
#endif
}

- (instancetype)initWithRecaptchaProvider:(id<GACAppCheckProvider>)recaptchaProvider {
  self = [super init];
  if (self) {
    _recaptchaProvider = recaptchaProvider;
  }
  return self;
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
