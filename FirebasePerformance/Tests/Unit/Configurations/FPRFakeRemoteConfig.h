// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

#import "FirebaseRemoteConfig/Sources/Private/FIRRemoteConfig_Private.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"

NS_ASSUME_NONNULL_BEGIN

// This is a fake Remote Config class to manipulate the inputs.
@interface FPRFakeRemoteConfig : NSObject

/** @brief Last config fetch time. */
@property(nonatomic, nullable) NSDate *lastFetchTime;

/** @brief Last config fetch status. */
@property(nonatomic) FIRRemoteConfigFetchStatus lastFetchStatus;

/**
 * @brief Config status for the upcoming fetch call. This will be used in the response when calling
 * fetch.
 */
@property(assign) FIRRemoteConfigFetchAndActivateStatus fetchStatus;

/** @brief Different configurations values that needs to be stored and returned. */
@property(nonatomic) NSMutableDictionary<NSString *, FIRRemoteConfigValue *> *configValues;

/**
 * Fake fetch call for fetching configs. Calling this method will just call the completionHandler.
 *
 * @param completionHandler Completion handler to be invoked.
 */
- (void)fetchAndActivateWithCompletionHandler:
    (nullable FIRRemoteConfigFetchAndActivateCompletion)completionHandler;

/**
 * Fake to fetch the config value for a provided key.
 *
 * @param key Key for which the value is fetched.
 * @return Configuration value as specified.
 */
- (FIRRemoteConfigValue *)configValueForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
