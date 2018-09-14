/*
 * Copyright 2018 Google
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

#import <FirebaseInAppMessaging/FIRInAppMessagingRendering.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_NAME(InAppMessagingDefaultDisplayImpl)
/**
 * Public class for displaying fiam messages. Most apps should not use it since its instance
 * would be instantiated upon SDK start-up automatically. It's exposed in public interface
 * to help UI Testing app access the UI layer directly.
 */
@interface FIRIAMDefaultDisplayImpl : NSObject <FIRInAppMessagingDisplay>
- (void)displayMessage:(FIRInAppMessagingDisplayMessageBase *)messageForDisplay
       displayDelegate:(id<FIRInAppMessagingDisplayDelegate>)displayDelegate;
@end
NS_ASSUME_NONNULL_END
