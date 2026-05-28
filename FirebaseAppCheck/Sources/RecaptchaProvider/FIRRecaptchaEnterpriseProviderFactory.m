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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRRecaptchaEnterpriseProviderFactory.h"

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheck.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRRecaptchaEnterpriseProvider.h"

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseCore/Sources/Public/FirebaseCore/FIROptions.h"

@interface FIRRecaptchaEnterpriseProviderFactory ()

@end

@implementation FIRRecaptchaEnterpriseProviderFactory

- (instancetype)init {
  self = [super init];
  return self;
}

- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(nonnull FIRApp *)app {
  NSString *siteKey = app.options.recaptchaSiteKey;
  if (siteKey.length == 0) {
    FIRLogError(kFIRLoggerAppCheck,
                kFIRLoggerAppCheckMessageRecaptchaEnterpriseProviderIncompleteFIROptions,
                @"Cannot instantiate `%@` for app: %@. "
                @"`recaptchaSiteKey` is missing or empty in Firebase app options.",
                NSStringFromClass([self class]), app.name);
    return nil;
  }
  return [[FIRRecaptchaEnterpriseProvider alloc] initWithApp:app siteKey:siteKey];
}

@end
