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

NS_ASSUME_NONNULL_BEGIN

/**
 * Provides integration between FIRMessaging and Scion.
 *
 * All Scion dependencies should be kept in this class, and missing dependencies should be handled
 * gracefully.
 *
 * key/values expected by GcmAnalytics: (constants are defined in FIRMessagingAnalytics.m)
 *
 * - google.c.a.e = 1            # Enable Analytics
 * - google.c.a.c_id = 123       # Composer Id
 * - google.c.a.c_l = Campaign1  # Composer Label
 * - google.c.a.ts = 1234        # Timestamp of message
 * - google.c.a.udt = 1          # Whether the ts should be used only for DateTime, without timezone
 *
 */
@interface FIRMessagingAnalytics : NSObject

/**
 * Determine whether a notification has the properties to be loggable to Scion.
 * @param notification The notification payload from APNs
 */
+ (BOOL)canLogNotification:(NSDictionary *)notification;

/**
 *  Log user opening a display notification.
 *
 *  @param notification The notification opened by the user.
 */
+ (void)logOpenNotification:(NSDictionary *)notification;

/**
 *  Log receiving a foreground display notification.
 *
 *  @param notification The notification received while the app was in foreground.
 */
+ (void)logForegroundNotification:(NSDictionary *)notification;

@end

NS_ASSUME_NONNULL_END
