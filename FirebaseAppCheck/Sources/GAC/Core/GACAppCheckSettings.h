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

typedef NS_CLOSED_ENUM(NSInteger, GACAppCheckTokenAutoRefreshPolicy) {
  GACAppCheckTokenAutoRefreshPolicyDefault,
  GACAppCheckTokenAutoRefreshPolicyEnabled,
  GACAppCheckTokenAutoRefreshPolicyDisabled
};

@protocol GACAppCheckSettingsProtocol <NSObject>

@property(nonatomic, assign) GACAppCheckTokenAutoRefreshPolicy tokenAutoRefreshPolicy;

@end

/// Handles storing and updating App Check-wide settings and parameters.
@interface GACAppCheckSettings : NSObject <GACAppCheckSettingsProtocol>

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
                               mainBundle:(NSBundle *)mainBundle
    tokenAutoRefreshPolicyUserDefaultsKey:(NSString *)tokenAutoRefreshPolicyUserDefaultsKey
       tokenAutoRefreshPolicyInfoPListKey:(NSString *)tokenAutoRefreshPolicyInfoPListKey
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
