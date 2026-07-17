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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRRecaptchaProviderFactory.h"

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRRecaptchaProvider.h"

@interface FIRRecaptchaProviderFactory ()
@property(nonatomic, copy) NSString *siteKey;
@end

@implementation FIRRecaptchaProviderFactory

- (nullable instancetype)initWithSiteKey:(NSString *)siteKey {
  self = [super init];
  if (self) {
    _siteKey = [siteKey copy];
  }
  return self;
}

- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(nonnull FIRApp *)app {
#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
  return [[FIRRecaptchaProvider alloc] initWithApp:app siteKey:self.siteKey];
#else
  return nil;
#endif
}

@end
