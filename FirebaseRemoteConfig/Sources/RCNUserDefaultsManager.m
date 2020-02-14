/*
 * Copyright 2019 Google
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

#import "FirebaseRemoteConfig/Sources/RCNUserDefaultsManager.h"
#import <FirebaseCore/FIRLogger.h>
#import <FirebaseRemoteConfig/FIRRemoteConfig.h>

static NSString *const kRCNGroupPrefix = @"group";
static NSString *const kRCNGroupSuffix = @"firebase";
static NSString *const kRCNUserDefaultsKeyNamelastETag = @"lastETag";
static NSString *const kRCNUserDefaultsKeyNamelastETagUpdateTime = @"lastETagUpdateTime";
static NSString *const kRCNUserDefaultsKeyNameLastSuccessfulFetchTime = @"lastSuccessfulFetchTime";
static NSString *const kRCNUserDefaultsKeyNamelastFetchStatus = @"lastFetchStatus";
static NSString *const kRCNUserDefaultsKeyNameIsClientThrottled =
    @"isClientThrottledWithExponentialBackoff";
static NSString *const kRCNUserDefaultsKeyNameThrottleEndTime = @"throttleEndTime";
static NSString *const kRCNUserDefaultsKeyNamecurrentThrottlingRetryInterval =
    @"currentThrottlingRetryInterval";

@interface RCNUserDefaultsManager () {
  /// User Defaults instance for this bundleID. NSUserDefaults is guaranteed to be thread-safe.
  NSUserDefaults *_userDefaults;
  /// The suite name for this user defaults instance. It is a combination of a prefix and the
  /// bundleID. This is because you cannot use just the bundleID of the current app as the suite
  /// name when initializing user defaults.
  NSString *_userDefaultsSuiteName;
  /// The FIRApp that this instance is scoped within.
  NSString *_firebaseAppName;
  /// The Firebase Namespace that this instance is scoped within.
  NSString *_firebaseNamespace;
  /// The bundleID of the app. In case of an extension, this will be the bundleID of the parent app.
  NSString *_bundleIdentifier;
}

@end

@implementation RCNUserDefaultsManager

#pragma mark Initializers.

/// Designated initializer.
- (instancetype)initWithAppName:(NSString *)appName
                       bundleID:(NSString *)bundleIdentifier
                      namespace:(NSString *)firebaseNamespace {
  self = [super init];
  if (self) {
    _firebaseAppName = appName;
    _bundleIdentifier = bundleIdentifier;
    NSInteger location = [firebaseNamespace rangeOfString:@":"].location;
    if (location == NSNotFound) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000064",
                  @"Error: Namespace %@ is not fully qualified app:namespace.", firebaseNamespace);
      _firebaseNamespace = firebaseNamespace;
    } else {
      _firebaseNamespace = [firebaseNamespace substringToIndex:location];
    }

    // Initialize the user defaults with a prefix and the bundleID. For app extensions, this will be
    // the bundleID of the app extension.
    _userDefaults =
        [RCNUserDefaultsManager sharedUserDefaultsForBundleIdentifier:_bundleIdentifier];
  }

  return self;
}

+ (NSUserDefaults *)sharedUserDefaultsForBundleIdentifier:(NSString *)bundleIdentifier {
  static dispatch_once_t onceToken;
  static NSUserDefaults *sharedInstance;
  dispatch_once(&onceToken, ^{
    NSString *userDefaultsSuiteName =
        [RCNUserDefaultsManager userDefaultsSuiteNameForBundleIdentifier:bundleIdentifier];
    sharedInstance = [[NSUserDefaults alloc] initWithSuiteName:userDefaultsSuiteName];
  });
  return sharedInstance;
}

+ (NSString *)userDefaultsSuiteNameForBundleIdentifier:(NSString *)bundleIdentifier {
  NSString *suiteName =
      [NSString stringWithFormat:@"%@.%@.%@", kRCNGroupPrefix, bundleIdentifier, kRCNGroupSuffix];
  return suiteName;
}

#pragma mark Public properties.

- (NSString *)lastETag {
  return [[self instanceUserDefaults] objectForKey:kRCNUserDefaultsKeyNamelastETag];
}

- (void)setLastETag:(NSString *)lastETag {
  if (lastETag) {
    [self setInstanceUserDefaultsValue:lastETag forKey:kRCNUserDefaultsKeyNamelastETag];
  }
}

- (NSTimeInterval)lastETagUpdateTime {
  NSNumber *lastETagUpdateTime =
      [[self instanceUserDefaults] objectForKey:kRCNUserDefaultsKeyNamelastETagUpdateTime];
  return lastETagUpdateTime.doubleValue;
}

- (void)setLastETagUpdateTime:(NSTimeInterval)lastETagUpdateTime {
  if (lastETagUpdateTime) {
    [self setInstanceUserDefaultsValue:@(lastETagUpdateTime)
                                forKey:kRCNUserDefaultsKeyNamelastETagUpdateTime];
  }
}

- (NSTimeInterval)lastFetchTime {
  NSNumber *lastFetchTime =
      [[self instanceUserDefaults] objectForKey:kRCNUserDefaultsKeyNameLastSuccessfulFetchTime];
  return lastFetchTime.doubleValue;
}

- (void)setLastFetchTime:(NSTimeInterval)lastFetchTime {
  [self setInstanceUserDefaultsValue:@(lastFetchTime)
                              forKey:kRCNUserDefaultsKeyNameLastSuccessfulFetchTime];
}

- (NSString *)lastFetchStatus {
  return [[self instanceUserDefaults] objectForKey:kRCNUserDefaultsKeyNamelastFetchStatus];
}

- (void)setLastFetchStatus:(NSString *)lastFetchStatus {
  if (lastFetchStatus) {
    [self setInstanceUserDefaultsValue:lastFetchStatus
                                forKey:kRCNUserDefaultsKeyNamelastFetchStatus];
  }
}

- (BOOL)isClientThrottledWithExponentialBackoff {
  NSNumber *isClientThrottled =
      [[self instanceUserDefaults] objectForKey:kRCNUserDefaultsKeyNameIsClientThrottled];
  return isClientThrottled.boolValue;
}

- (void)setIsClientThrottledWithExponentialBackoff:(BOOL)isClientThrottled {
  [self setInstanceUserDefaultsValue:@(isClientThrottled)
                              forKey:kRCNUserDefaultsKeyNameIsClientThrottled];
}

- (NSTimeInterval)throttleEndTime {
  NSNumber *throttleEndTime =
      [[self instanceUserDefaults] objectForKey:kRCNUserDefaultsKeyNameThrottleEndTime];
  return throttleEndTime.doubleValue;
}

- (void)setThrottleEndTime:(NSTimeInterval)throttleEndTime {
  [self setInstanceUserDefaultsValue:@(throttleEndTime)
                              forKey:kRCNUserDefaultsKeyNameThrottleEndTime];
}

- (NSTimeInterval)currentThrottlingRetryIntervalSeconds {
  NSNumber *throttleEndTime = [[self instanceUserDefaults]
      objectForKey:kRCNUserDefaultsKeyNamecurrentThrottlingRetryInterval];
  return throttleEndTime.doubleValue;
}

- (void)setCurrentThrottlingRetryIntervalSeconds:(NSTimeInterval)throttlingRetryIntervalSeconds {
  [self setInstanceUserDefaultsValue:@(throttlingRetryIntervalSeconds)
                              forKey:kRCNUserDefaultsKeyNamecurrentThrottlingRetryInterval];
}

#pragma mark Public methods.
- (void)resetUserDefaults {
  [self resetInstanceUserDefaults];
}

#pragma mark Private methods.

// There is a nested hierarchy for the userdefaults as follows:
// [FIRAppName][FIRNamespaceName][Key]
- (nonnull NSDictionary *)appUserDefaults {
  NSString *appPath = _firebaseAppName;
  NSDictionary *appDict = [_userDefaults valueForKeyPath:appPath];
  if (!appDict) {
    appDict = [[NSDictionary alloc] init];
  }
  return appDict;
}

// Search for the user defaults for this (app, namespace) instance using the valueForKeyPath method.
- (nonnull NSDictionary *)instanceUserDefaults {
  NSString *appNamespacePath =
      [NSString stringWithFormat:@"%@.%@", _firebaseAppName, _firebaseNamespace];
  NSDictionary *appNamespaceDict = [_userDefaults valueForKeyPath:appNamespacePath];

  if (!appNamespaceDict) {
    appNamespaceDict = [[NSMutableDictionary alloc] init];
  }
  return appNamespaceDict;
}

// Update users defaults for just this (app, namespace) instance.
- (void)setInstanceUserDefaultsValue:(NSObject *)value forKey:(NSString *)key {
  @synchronized(_userDefaults) {
    NSMutableDictionary *appUserDefaults = [[self appUserDefaults] mutableCopy];
    NSMutableDictionary *appNamespaceUserDefaults = [[self instanceUserDefaults] mutableCopy];
    [appNamespaceUserDefaults setObject:value forKey:key];
    [appUserDefaults setObject:appNamespaceUserDefaults forKey:_firebaseNamespace];
    [_userDefaults setObject:appUserDefaults forKey:_firebaseAppName];
    // We need to synchronize to have this value updated for the extension.
    [_userDefaults synchronize];
  }
}

// Delete any existing userdefaults for this instance.
- (void)resetInstanceUserDefaults {
  @synchronized(_userDefaults) {
    NSMutableDictionary *appUserDefaults = [[self appUserDefaults] mutableCopy];
    NSMutableDictionary *appNamespaceUserDefaults = [[self instanceUserDefaults] mutableCopy];
    [appNamespaceUserDefaults removeAllObjects];
    [appUserDefaults setObject:appNamespaceUserDefaults forKey:_firebaseNamespace];
    [_userDefaults setObject:appUserDefaults forKey:_firebaseAppName];
    // We need to synchronize to have this value updated for the extension.
    [_userDefaults synchronize];
  }
}

@end
