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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSInteger const kFIRIAMMaxFetchInNewlyInstalledMode;

/**
 * At runtime a FIAM SDK client can function in one of the following modes:
 *  1 Regular. This SDK client instance will conform to regular fetch minimal interval time policy.
 *  2 Newly installed. This is a mode a newly installed SDK stays in until the first
 *    kFIRIAMMaxFetchInNewlyInstalledMode fetches have finished. In this mode, there is no
 *    minimal time interval between fetches: a fetch would be triggered as long as the app goes
 *    into foreground state.
 *  3 Testing Instance. This app instance is targeted for test on device feature for fiam. When
 *    it's in this mode, no minimal time interval between fetches is applied. SDK turns itself
 *    into this mode on seeing test-on-client messages are returned in fetch responses.
 */

typedef NS_ENUM(NSInteger, FIRIAMSDKMode) {
  FIRIAMSDKModeRegular,
  FIRIAMSDKModeTesting,
  FIRIAMSDKModeNewlyInstalled
};

// turn the sdk mode enum integer value into a descriptive string
NSString *FIRIAMDescriptonStringForSDKMode(FIRIAMSDKMode mode);

extern NSString *const kFIRIAMUserDefaultKeyForSDKMode;
extern NSString *const kFIRIAMUserDefaultKeyForServerFetchCount;
extern NSInteger const kFIRIAMMaxFetchInNewlyInstalledMode;

@protocol FIRIAMTestingModeListener <NSObject>
// Triggered when the current app switches into testing mode from a using testing mode
- (void)testingModeSwitchedOn;
@end

// A class for tracking and updating the SDK mode. The tracked mode related info is persisted
// so that it can be restored beyond app restarts
@interface FIRIAMSDKModeManager : NSObject

- (instancetype)init NS_UNAVAILABLE;

// having NSUserDefaults as passed-in to help with unit testing
- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
                 testingModeListener:(id<FIRIAMTestingModeListener>)testingModeListener;

// returns the current SDK mode
- (FIRIAMSDKMode)currentMode;

// turn the current SDK into 'Testing Instance' mode.
- (void)becomeTestingInstance;
// inform the manager that one more fetch is done. This is to allow
// the manager to potentially graduate from the newly installed mode.
- (void)registerOneMoreFetch;

@end
NS_ASSUME_NONNULL_END
