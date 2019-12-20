/*
 * Copyright 2018 Google
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

#import <FirebaseCore/FIRLogger.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMSDKModeManager.h"

NSString *FIRIAMDescriptonStringForSDKMode(FIRIAMSDKMode mode) {
  switch (mode) {
    case FIRIAMSDKModeTesting:
      return @"Testing Instance";
    case FIRIAMSDKModeRegular:
      return @"Regular";
    case FIRIAMSDKModeNewlyInstalled:
      return @"Newly Installed";
    default:
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM290003", @"Unknown sdk mode value %d",
                    (int)mode);
      return @"Unknown";
  }
}

@interface FIRIAMSDKModeManager ()
@property(nonatomic, nonnull, readonly) NSUserDefaults *userDefaults;
// Make it weak so that we don't depend on its existence to avoid circular reference.
@property(nonatomic, readonly, weak) id<FIRIAMTestingModeListener> testingModeListener;
@end

NSString *const kFIRIAMUserDefaultKeyForSDKMode = @"firebase-iam-sdk-mode";
NSString *const kFIRIAMUserDefaultKeyForServerFetchCount = @"firebase-iam-server-fetch-count";
NSInteger const kFIRIAMMaxFetchInNewlyInstalledMode = 5;

@implementation FIRIAMSDKModeManager {
  FIRIAMSDKMode _sdkMode;
  NSInteger _fetchCount;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
                 testingModeListener:(id<FIRIAMTestingModeListener>)testingModeListener {
  if (self = [super init]) {
    _userDefaults = userDefaults;
    _testingModeListener = testingModeListener;

    id modeEntry = [_userDefaults objectForKey:kFIRIAMUserDefaultKeyForSDKMode];
    if (modeEntry == nil) {
      // no entry yet, it's a newly installed sdk instance
      _sdkMode = FIRIAMSDKModeNewlyInstalled;

      // initialize the mode and fetch count in the persistent storage
      [_userDefaults setObject:[NSNumber numberWithInteger:_sdkMode]
                        forKey:kFIRIAMUserDefaultKeyForSDKMode];
      [_userDefaults setInteger:0 forKey:kFIRIAMUserDefaultKeyForServerFetchCount];
    } else {
      _sdkMode = [(NSNumber *)modeEntry integerValue];
      _fetchCount = [_userDefaults integerForKey:kFIRIAMUserDefaultKeyForServerFetchCount];
    }

    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM290001",
                @"SDK is in mode of %@ and has seen %d fetches.",
                FIRIAMDescriptonStringForSDKMode(_sdkMode), (int)_fetchCount);
  }
  return self;
}

// inform the manager that one more fetch is done. This is to allow
// the manager to potentially graduate from the newly installed mode.
- (void)registerOneMoreFetch {
  // we only care about the fetch count when sdk is in newly installed mode (so that it may
  // graduate from that after certain number of fetches).
  if (_sdkMode == FIRIAMSDKModeNewlyInstalled) {
    if (++_fetchCount >= kFIRIAMMaxFetchInNewlyInstalledMode) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM290002",
                  @"Coming out of newly installed mode since there have been %d fetches",
                  (int)_fetchCount);

      _sdkMode = FIRIAMSDKModeRegular;
      [_userDefaults setObject:[NSNumber numberWithInteger:_sdkMode]
                        forKey:kFIRIAMUserDefaultKeyForSDKMode];
    } else {
      [_userDefaults setInteger:_fetchCount forKey:kFIRIAMUserDefaultKeyForServerFetchCount];
    }
  }
}

- (void)becomeTestingInstance {
  _sdkMode = FIRIAMSDKModeTesting;
  [_userDefaults setObject:[NSNumber numberWithInteger:_sdkMode]
                    forKey:kFIRIAMUserDefaultKeyForSDKMode];

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM290004",
              @"Test mode enabled, notifying test mode listener.");
  [self.testingModeListener testingModeSwitchedOn];
}

// returns the current SDK mode
- (FIRIAMSDKMode)currentMode {
  return _sdkMode;
}
@end
