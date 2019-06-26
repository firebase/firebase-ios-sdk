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

#import "FIRIAMActionURLFollower.h"
#import "FIRIAMActivityLogger.h"
#import "FIRIAMBookKeeper.h"
#import "FIRIAMClearcutLogger.h"
#import "FIRIAMMessageClientCache.h"
#import "FIRIAMTimeFetcher.h"
#import "FIRInAppMessaging.h"
#import "FIRInAppMessagingRendering.h"

NS_ASSUME_NONNULL_BEGIN
@interface FIRIAMDisplaySetting : NSObject
@property(nonatomic) NSTimeInterval displayMinIntervalInMinutes;
@end

// The class for checking if there are appropriate messages to be displayed and if so, render it.
// There are other flows that would determine the timing for the checking and then use this class
// instance for the actual check/display.
//
// In addition to fetch eligible message from message cache, this class also ensures certain
// conditions are satisfied for the rendering
//   1 No current in-app message is being displayed
//   2 For non-contextual messages, the display interval in display setting is met.
@interface FIRIAMDisplayExecutor : NSObject

- (instancetype)initWithInAppMessaging:(FIRInAppMessaging *)inAppMessaging
                               setting:(FIRIAMDisplaySetting *)setting
                          messageCache:(FIRIAMMessageClientCache *)cache
                           timeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                            bookKeeper:(id<FIRIAMBookKeeper>)displayBookKeeper
                     actionURLFollower:(FIRIAMActionURLFollower *)actionURLFollower
                        activityLogger:(FIRIAMActivityLogger *)activityLogger
                  analyticsEventLogger:(id<FIRIAMAnalyticsEventLogger>)analyticsEventLogger;

// Check and display next in-app message eligible for app launch trigger
- (void)checkAndDisplayNextAppLaunchMessage;
// Check and display next in-app message eligible for app open trigger
- (void)checkAndDisplayNextAppForegroundMessage;
// Check and display next in-app message eligible for analytics event trigger with given event name.
- (void)checkAndDisplayNextContextualMessageForAnalyticsEvent:(NSString *)eventName;

// a boolean flag that can be used to suppress/resume displaying messages.
@property(nonatomic) BOOL suppressMessageDisplay;

// This is the display component used by display executor for actual message rendering.
@property(nonatomic) id<FIRInAppMessagingDisplay> messageDisplayComponent;
@end
NS_ASSUME_NONNULL_END
