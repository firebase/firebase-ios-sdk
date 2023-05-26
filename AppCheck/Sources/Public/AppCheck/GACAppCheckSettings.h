/*
 * Copyright 2023 Google LLC
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

/// Policies (i.e., behavior) for the App Check token auto-refresh mechanism.
typedef NS_CLOSED_ENUM(NSInteger, GACAppCheckTokenAutoRefreshPolicy) {
  /// Token auto-refresh behavior is not configured; determining default behavior is delegated to
  /// `GACAppCheckSettings` subclasses.
  GACAppCheckTokenAutoRefreshPolicyUnspecified,

  /// Token auto-refresh is explicitly enabled.
  GACAppCheckTokenAutoRefreshPolicyEnabled,

  /// Token auto-refresh is explicitly disabled.
  GACAppCheckTokenAutoRefreshPolicyDisabled
};

/// A collection of App Check-wide settings and parameters.
@protocol GACAppCheckSettingsProtocol <NSObject>

/// If App Check token auto-refresh is enabled.
@property(nonatomic, assign) BOOL isTokenAutoRefreshEnabled;

@end

/// Handles storing and updating App Check-wide settings and parameters.
@interface GACAppCheckSettings : NSObject <GACAppCheckSettingsProtocol>

/// The configured policy (i.e., behavior) for the App Check token auto-refresh mechanism.
@property(nonatomic, assign) GACAppCheckTokenAutoRefreshPolicy tokenAutoRefreshPolicy;

/// The designated initializer.
/// - Parameters:
///   - userDefaults: An interface to the user’s defaults database.
///   - mainBundle: An interface to the main bundle for the executable.
///   - tokenAutoRefreshPolicyUserDefaultsKey: The user defaults key for the token auto-refresh
///   configuration value.
///   - tokenAutoRefreshPolicyInfoPListKey: The Info.plist key for the token auto-refresh
///   configuration value.
- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
                               mainBundle:(NSBundle *)mainBundle
    tokenAutoRefreshPolicyUserDefaultsKey:(NSString *)tokenAutoRefreshPolicyUserDefaultsKey
       tokenAutoRefreshPolicyInfoPListKey:(NSString *)tokenAutoRefreshPolicyInfoPListKey
    NS_DESIGNATED_INITIALIZER;

/// The designated initializer.
/// - Parameters:
///   - tokenAutoRefreshPolicyUserDefaultsKey: The user defaults key for the token auto-refresh
///   configuration value.
///   - tokenAutoRefreshPolicyInfoPListKey: The Info.plist key for the token auto-refresh
///   configuration value.
- (instancetype)
    initWitTokenAutoRefreshPolicyUserDefaultsKey:(NSString *)tokenAutoRefreshPolicyUserDefaultsKey
              tokenAutoRefreshPolicyInfoPListKey:(NSString *)tokenAutoRefreshPolicyInfoPListKey
    NS_SWIFT_NAME(init(tokenAutoRefreshPolicyUserDefaultsKey:tokenAutoRefreshPolicyInfoPListKey:));

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
