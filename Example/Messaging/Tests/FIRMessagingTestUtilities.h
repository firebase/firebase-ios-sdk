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

#import <Foundation/Foundation.h>

#import <FirebaseMessaging/FIRMessaging.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRMessaging (TestUtilities)
// Surface the user defaults instance to clean up after tests.
@property(nonatomic, strong) NSUserDefaults *messagingUserDefaults;
@end

@interface FIRMessagingTestUtilities : NSObject

/**
 Creates an instance of FIRMessaging to use with tests, and will instantiate a new instance of
 InstanceID.

 Note: This does not create a FIRApp instance and call `configureWithApp:`. If required, it's up to
       each test to do so.

 @param userDefaults The user defaults to be used for Messaging.
 @return An instance of FIRMessaging with everything initialized.
 */
+ (FIRMessaging *)messagingForTestsWithUserDefaults:(NSUserDefaults *)userDefaults;

@end

NS_ASSUME_NONNULL_END
