/*
 * Copyright 2017 Google
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

/**
 * This class provides configuration fields for Firebase Analytics.
 */
@interface FIRAnalyticsConfiguration : NSObject

/**
 * Returns the shared instance of FIRAnalyticsConfiguration.
 */
+ (FIRAnalyticsConfiguration *)sharedInstance;

/**
 * Sets the minimum engagement time in seconds required to start a new session. The default value
 * is 10 seconds.
 */
- (void)setMinimumSessionInterval:(NSTimeInterval)minimumSessionInterval;

/**
 * Sets the interval of inactivity in seconds that terminates the current session. The default
 * value is 1800 seconds (30 minutes).
 */
- (void)setSessionTimeoutInterval:(NSTimeInterval)sessionTimeoutInterval;

/**
 * Sets whether analytics collection is enabled for this app on this device. This setting is
 * persisted across app sessions. By default it is enabled.
 */
- (void)setAnalyticsCollectionEnabled:(BOOL)analyticsCollectionEnabled;

/**
 * Deprecated. Sets whether measurement and reporting are enabled for this app on this device. By
 * default they are enabled.
 */
- (void)setIsEnabled:(BOOL)isEnabled
    DEPRECATED_MSG_ATTRIBUTE("Use setAnalyticsCollectionEnabled: instead.");

@end
