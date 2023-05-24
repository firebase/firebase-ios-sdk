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

#import "AppCheck/Sources/Public/AppCheck/GACAppCheckSettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface GACAppCheckSettings ()

@property(nonatomic, readonly) NSUserDefaults *userDefaults;
@property(nonatomic, readonly) NSBundle *mainBundle;
@property(nonatomic, readonly) NSString *tokenAutoRefreshPolicyUserDefaultsKey;
@property(nonatomic, readonly) NSString *tokenAutoRefreshPolicyInfoPListKey;

@end

@implementation GACAppCheckSettings

@synthesize tokenAutoRefreshPolicy = _tokenAutoRefreshPolicy;
@dynamic isTokenAutoRefreshEnabled;

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
                               mainBundle:(NSBundle *)mainBundle
    tokenAutoRefreshPolicyUserDefaultsKey:(NSString *)tokenAutoRefreshPolicyUserDefaultsKey
       tokenAutoRefreshPolicyInfoPListKey:(NSString *)tokenAutoRefreshPolicyInfoPListKey {
  self = [super init];
  if (self) {
    _userDefaults = userDefaults;
    _mainBundle = mainBundle;
    _tokenAutoRefreshPolicyUserDefaultsKey = [tokenAutoRefreshPolicyUserDefaultsKey copy];
    _tokenAutoRefreshPolicyInfoPListKey = [tokenAutoRefreshPolicyInfoPListKey copy];
  }
  return self;
}

- (instancetype)
    initWitTokenAutoRefreshPolicyUserDefaultsKey:(NSString *)tokenAutoRefreshPolicyUserDefaultsKey
              tokenAutoRefreshPolicyInfoPListKey:(NSString *)tokenAutoRefreshPolicyInfoPListKey {
  return [self initWithUserDefaults:[NSUserDefaults standardUserDefaults]
                                 mainBundle:[NSBundle mainBundle]
      tokenAutoRefreshPolicyUserDefaultsKey:tokenAutoRefreshPolicyUserDefaultsKey
         tokenAutoRefreshPolicyInfoPListKey:tokenAutoRefreshPolicyInfoPListKey];
}

- (BOOL)isTokenAutoRefreshEnabled {
  NSAssert(NO, @"The method `isTokenAutoRefreshEnabled` must be implemented in a subclass of "
               @"GACAppCheckSettings.");
  return NO;
}

- (void)setIsTokenAutoRefreshEnabled:(BOOL)isTokenAutoRefreshEnabled {
  NSAssert(NO, @"The method `setIsTokenAutoRefreshEnabled:` must be implemented in a subclass of "
               @"GACAppCheckSettings.");
}

#pragma mark - GACAppCheckSettingsProtocol

- (GACAppCheckTokenAutoRefreshPolicy)tokenAutoRefreshPolicy {
  @synchronized(self) {
    // Return the in-memory cached value, when available, to avoid checking user defaults or bundle.
    if (_tokenAutoRefreshPolicy != GACAppCheckTokenAutoRefreshPolicyUnspecified) {
      return _tokenAutoRefreshPolicy;
    }

    // Check user defaults for a value set during the previous launch.
    _tokenAutoRefreshPolicy = GACAppCheckSettingsTokenRefreshPolicy(
        [self.userDefaults objectForKey:self.tokenAutoRefreshPolicyUserDefaultsKey]);

    // Check the main bundule (Info.plist) if no user defaults value was cached.
    if (_tokenAutoRefreshPolicy == GACAppCheckTokenAutoRefreshPolicyUnspecified) {
      _tokenAutoRefreshPolicy = GACAppCheckSettingsTokenRefreshPolicy(
          [self.mainBundle objectForInfoDictionaryKey:self.tokenAutoRefreshPolicyInfoPListKey]);
    }

    return _tokenAutoRefreshPolicy;
  }
}

- (void)setTokenAutoRefreshPolicy:(GACAppCheckTokenAutoRefreshPolicy)tokenAutoRefreshPolicy {
  @synchronized(self) {
    if (tokenAutoRefreshPolicy == GACAppCheckTokenAutoRefreshPolicyUnspecified) {
      [self.userDefaults removeObjectForKey:self.tokenAutoRefreshPolicyUserDefaultsKey];
      return;
    }

    _tokenAutoRefreshPolicy = tokenAutoRefreshPolicy;
    BOOL autoRefreshEnabled = tokenAutoRefreshPolicy == GACAppCheckTokenAutoRefreshPolicyEnabled;
    [self.userDefaults setBool:autoRefreshEnabled
                        forKey:self.tokenAutoRefreshPolicyUserDefaultsKey];
  }
}

#pragma mark - Private

GACAppCheckTokenAutoRefreshPolicy GACAppCheckSettingsTokenRefreshPolicy(
    NSNumber *_Nullable autoRefreshNumber) {
  if (autoRefreshNumber == nil) {
    return GACAppCheckTokenAutoRefreshPolicyUnspecified;
  }

  return autoRefreshNumber.boolValue ? GACAppCheckTokenAutoRefreshPolicyEnabled
                                     : GACAppCheckTokenAutoRefreshPolicyDisabled;
}

@end

NS_ASSUME_NONNULL_END
