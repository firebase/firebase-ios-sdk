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

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"

NS_ASSUME_NONNULL_BEGIN

/** List of gauges the gauge manager controls. */
typedef NS_OPTIONS(NSUInteger, FPRConfigurationSource) {
  FPRConfigurationSourceNone = 0,
  FPRConfigurationSourceRemoteConfig = (1 << 1),
};

/** This extension should only be used for testing. */
@interface FPRConfigurations ()

/** @brief Different configuration sources managed by the object. */
@property(nonatomic) FPRConfigurationSource sources;

/** @brief Instance of remote config flags. */
@property(nonatomic) FPRRemoteConfigFlags *remoteConfigFlags;

/** @brief The class to use when FIRApp is referenced. */
@property(nonatomic) Class FIRAppClass;

/** @brief User defaults used for user preference config fetches . */
@property(nonatomic) NSUserDefaults *userDefaults;

/** @brief The main bundle identifier used by config system. */
@property(nonatomic) NSString *mainBundleIdentifier;

/** @brief The infoDictionary provided by the main bundle. */
@property(nonatomic) NSDictionary<NSString *, id> *infoDictionary;

/** @brief Configurations update queue. */
@property(nonatomic) dispatch_queue_t updateQueue;

/**
 * Creates an instance of the FPRConfigurations class with the specified sources.
 *
 * @param source Source that needs to be enabled for fetching configurations.
 * @return Instance of FPRConfiguration.
 */
- (instancetype)initWithSources:(FPRConfigurationSource)source NS_DESIGNATED_INITIALIZER;

/**
 * Returns the list of SDK versions that are disabled. SDK Versions are ';' separated. If no
 * versions are disabled, an empty set is returned.
 *
 * @return The set of disabled SDK versions.
 */
- (nonnull NSSet<NSString *> *)sdkDisabledVersions;

/**
 * Resets this class by changing the onceToken back to 0, allowing a new singleton to be created,
 * while the old one is dealloc'd. This should only be used for testing.
 */
+ (void)reset;

@end

NS_ASSUME_NONNULL_END
