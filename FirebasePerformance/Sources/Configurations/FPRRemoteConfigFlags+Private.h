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

#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"

#import "FirebaseRemoteConfig/Sources/Private/FIRRemoteConfig_Private.h"

NS_ASSUME_NONNULL_BEGIN

@class GULUserDefaults;

static NSString *const kFPRConfigPrefix = @"com.fireperf";

/** Interval at which the configurations can be fetched. Specified in seconds. */
static NSInteger const kFPRConfigFetchIntervalInSeconds = 12 * 60 * 60;

/** Interval after which the configurations can be fetched. Specified in seconds. */
static NSInteger const kFPRMinAppStartConfigFetchDelayInSeconds = 5;

/** This extension should only be used for testing. */
@interface FPRRemoteConfigFlags ()

/** @brief Instance of remote config used for firebase performance namespace. */
@property(nonatomic) FIRRemoteConfig *fprRemoteConfig;

/** @brief Last activated time of the configurations. */
@property(atomic, nullable) NSDate *lastFetchedTime;

/** @brief User defaults used for caching. */
@property(nonatomic) GULUserDefaults *userDefaults;

/** @brief Last activated time of the configurations. */
@property(nonatomic) NSDate *applicationStartTime;

/** @brief Number of seconds delayed until the first config is made during app start. */
@property(nonatomic) NSTimeInterval appStartConfigFetchDelayInSeconds;

/** @brief Status of the last remote config fetch. */
@property(nonatomic) FIRRemoteConfigFetchStatus lastFetchStatus;

/**
 * Creates an instance of FPRRemoteConfigFlags.
 *
 * @param config RemoteConfig object to be used for configuration management.
 * @return Instance of remote config.
 */
- (instancetype)initWithRemoteConfig:(FIRRemoteConfig *)config NS_DESIGNATED_INITIALIZER;

#pragma mark - Config fetch methods

/**
 * Gets and returns the string value for the provided remote config flag. If there are no values
 * returned from remote config, default value will be returned.
 * @param flagName Name of the flag for which the value needs to be fetched from RC.
 * @param defaultValue Default value that will be returned if no value is fetched from RC.
 *
 * @return string value for the flag from RC if available. Default value, otherwise.
 */
- (NSString *)getStringValueForFlag:(NSString *)flagName defaultValue:(NSString *)defaultValue;

/**
 * Gets and returns the int value for the provided remote config flag. If there are no values
 * returned from remote config, default value will be returned.
 * @param flagName Name of the flag for which the value needs to be fetched from RC.
 * @param defaultValue Default value that will be returned if no value is fetched from RC.
 *
 * @return Int value for the flag from RC if available. Default value, otherwise.
 */
- (int)getIntValueForFlag:(NSString *)flagName defaultValue:(int)defaultValue;

/**
 * Gets and returns the float value for the provided remote config flag. If there are no values
 * returned from remote config, default value will be returned.
 * @param flagName Name of the flag for which the value needs to be fetched from RC.
 * @param defaultValue Default value that will be returned if no value is fetched from RC.
 *
 * @return Float value for the flag from RC if available. Default value, otherwise.
 */
- (float)getFloatValueForFlag:(NSString *)flagName defaultValue:(float)defaultValue;

/**
 * Gets and returns the boolean value for the provided remote config flag. If there are no values
 * returned from remote config, default value will be returned.
 * @param flagName Name of the flag for which the value needs to be fetched from RC.
 * @param defaultValue Default value that will be returned if no value is fetched from RC.
 *
 * @return Bool value for the flag from RC if available. Default value, otherwise.
 */
- (BOOL)getBoolValueForFlag:(NSString *)flagName defaultValue:(BOOL)defaultValue;

/**
 * Caches the remote config values.
 */
- (void)cacheConfigValues;

/**
 * Reset (Clears) all the remote config keys and values that were cached.
 */
- (void)resetCache;

@end

NS_ASSUME_NONNULL_END
