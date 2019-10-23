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

#import "Example/Messaging/Tests/FIRMessagingTestUtilities.h"

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseInstanceID/FirebaseInstanceID.h>
#import <GoogleUtilities/GULUserDefaults.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRInstanceID (ExposedForTest)

/// Private initializer to avoid singleton usage.
- (FIRInstanceID *)initPrivately;

/// Starts fetching and configuration of InstanceID. This is necessary after the `initPrivately`
/// call.
- (void)start;

@end

@interface FIRMessaging (ExposedForTest)

/// Surface internal initializer to avoid singleton usage during tests.
- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics
                   withInstanceID:(FIRInstanceID *)instanceID
                 withUserDefaults:(GULUserDefaults *)defaults;

/// Kicks off required calls for some messaging tests.
- (void)start;

@end

@implementation FIRMessagingTestUtilities

+ (FIRMessaging *)messagingForTestsWithUserDefaults:(GULUserDefaults *)userDefaults {
  // Create the messaging instance with all the necessary dependencies.
  FIRInstanceID *instanceID = [[FIRInstanceID alloc] initPrivately];
  [instanceID start];

  // Create the messaging instance and call `start`.
  FIRMessaging *messaging = [[FIRMessaging alloc] initWithAnalytics:nil
                                                     withInstanceID:instanceID
                                                   withUserDefaults:userDefaults];
  [messaging start];
  return messaging;
}

@end

NS_ASSUME_NONNULL_END
