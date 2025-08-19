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

#import <Foundation/Foundation.h>

#import <AppCheckCore/AppCheckCore.h>

@class FIRApp;
@class GULUserDefaults;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kFIRAppCheckTokenAutoRefreshEnabledUserDefaultsPrefix;
FOUNDATION_EXPORT NSString *const kFIRAppCheckTokenAutoRefreshEnabledInfoPlistKey;

/// Handles storing and updating the Firebase app check wide settings and parameters.
@interface FIRAppCheckSettings : GACAppCheckSettings

/// If Firebase app check token auto-refresh is allowed.
@property(nonatomic, assign) BOOL isTokenAutoRefreshEnabled;

- (instancetype)initWithApp:(FIRApp *)firebaseApp
                userDefault:(GULUserDefaults *)userDefaults
                 mainBundle:(NSBundle *)mainBundle NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
