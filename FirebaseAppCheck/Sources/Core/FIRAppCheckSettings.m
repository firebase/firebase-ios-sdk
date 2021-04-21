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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const kFIRAppCheckTokenAutoRefreshEnabledUserDefaultsPrefix =
    @"FIRAppCheckTokenAutoRefreshEnabled_";
NSString *const kFIRAppCheckTokenAutoRefreshEnabledInfoPlistKey =
    @"FirebaseAppCheckTokenAutoRefreshEnabled";

@interface FIRAppCheckSettings ()

@property(nonatomic, weak, readonly) FIRApp *firebaseApp;
@property(nonatomic, readonly) NSUserDefaults *userDefaults;
@property(nonatomic, readonly) NSBundle *mainBundle;
@property(nonatomic, readonly) NSString *userDefaultKey;

@property(nonatomic, nullable) NSNumber *isTokenAutoRefreshEnabledNumber;
@end

@implementation FIRAppCheckSettings

@synthesize isTokenAutoRefreshEnabled = _isTokenAutoRefreshEnabled;

- (instancetype)initWithApp:(FIRApp *)firebaseApp
                userDefault:(NSUserDefaults *)userDefaults
                 mainBundle:(NSBundle *)mainBundle {
  self = [super init];
  if (self) {
    _firebaseApp = firebaseApp;
    _userDefaults = userDefaults;
    _mainBundle = mainBundle;
    _userDefaultKey = [kFIRAppCheckTokenAutoRefreshEnabledUserDefaultsPrefix
        stringByAppendingString:firebaseApp.name];
  }
  return self;
}

- (BOOL)isTokenAutoRefreshEnabled {
  @synchronized(self) {
    if (self.isTokenAutoRefreshEnabledNumber != nil) {
      // Return value form the in-memory cache to avoid accessing the user default or bundle when
      // not required.
      return self.isTokenAutoRefreshEnabledNumber.boolValue;
    }

    // Check user defaults for a value set during the previous launch.
    NSNumber *isTokenAutoRefreshEnabledNumber =
        [self.userDefaults objectForKey:self.userDefaultKey];

    // Check Info.plist if no user defaults value found.
    if (isTokenAutoRefreshEnabledNumber == nil) {
      isTokenAutoRefreshEnabledNumber = [self.mainBundle
          objectForInfoDictionaryKey:kFIRAppCheckTokenAutoRefreshEnabledInfoPlistKey];
    }

    if (isTokenAutoRefreshEnabledNumber != nil) {
      // Update in-memory cache.
      self.isTokenAutoRefreshEnabledNumber = isTokenAutoRefreshEnabledNumber;
      // Return the value.
      return isTokenAutoRefreshEnabledNumber.boolValue;
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
    self.isTokenAutoRefreshEnabledNumber = @(isTokenAutoRefreshEnabled);
    [self.userDefaults setObject:self.isTokenAutoRefreshEnabledNumber forKey:self.userDefaultKey];
  }
}

@end

NS_ASSUME_NONNULL_END
