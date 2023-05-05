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

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckSettings.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const kFIRAppCheckTokenAutoRefreshEnabledUserDefaultsPrefix =
    @"FIRAppCheckTokenAutoRefreshEnabled_";
NSString *const kFIRAppCheckTokenAutoRefreshEnabledInfoPlistKey =
    @"FirebaseAppCheckTokenAutoRefreshEnabled";

@interface FIRAppCheckSettings ()

@property(nonatomic, weak, readonly) FIRApp *firebaseApp;

@end

@implementation FIRAppCheckSettings

@dynamic isTokenAutoRefreshEnabled;

- (instancetype)initWithApp:(FIRApp *)firebaseApp
                userDefault:(NSUserDefaults *)userDefaults
                 mainBundle:(NSBundle *)mainBundle {
  self = [super initWithUserDefaults:userDefaults
                                 mainBundle:mainBundle
      tokenAutoRefreshPolicyUserDefaultsKey:[kFIRAppCheckTokenAutoRefreshEnabledUserDefaultsPrefix
                                                stringByAppendingString:firebaseApp.name]
         tokenAutoRefreshPolicyInfoPListKey:kFIRAppCheckTokenAutoRefreshEnabledInfoPlistKey];
  if (self) {
    _firebaseApp = firebaseApp;
  }
  return self;
}

- (BOOL)isTokenAutoRefreshEnabled {
  @synchronized(self) {
    GACAppCheckTokenAutoRefreshPolicy policy = self.tokenAutoRefreshPolicy;

    if (policy != GACAppCheckTokenAutoRefreshPolicyUnspecified) {
      return policy == GACAppCheckTokenAutoRefreshPolicyEnabled;
    }

    // Fallback to the global data collection flag.
    if (self.firebaseApp) {
      return self.firebaseApp.isDataCollectionDefaultEnabled;
    } else {
      // If `self.firebaseApp == nil`, then the app has been de-initialized. No auto-refresh in this
      // case.
      return NO;
    }
  }
}

- (void)setIsTokenAutoRefreshEnabled:(BOOL)isTokenAutoRefreshEnabled {
  @synchronized(self) {
    if (isTokenAutoRefreshEnabled) {
      self.tokenAutoRefreshPolicy = GACAppCheckTokenAutoRefreshPolicyEnabled;
    } else {
      self.tokenAutoRefreshPolicy = GACAppCheckTokenAutoRefreshPolicyDisabled;
    }
  }
}

@end

NS_ASSUME_NONNULL_END
