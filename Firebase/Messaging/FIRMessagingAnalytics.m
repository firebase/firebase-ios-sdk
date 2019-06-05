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

#import "FIRMessagingAnalytics.h"
#import "FIRMessagingLogger.h"

#import <FirebaseAnalyticsInterop/FIRInteropEventNames.h>
#import <FirebaseAnalyticsInterop/FIRInteropParameterNames.h>
#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import <GoogleUtilities/GULAppDelegateSwizzler.h>

static NSString *const kLogTag = @"FIRMessagingAnalytics";

// aps Key
static NSString *const kApsKey = @"aps";
static NSString *const kApsAlertKey = @"alert";
static NSString *const kApsSoundKey = @"sound";
static NSString *const kApsBadgeKey = @"badge";
static NSString *const kApsContentAvailableKey = @"badge";

// Data Key
static NSString *const kDataKey = @"data";

// Messaging From Key
static NSString *const kFIRMessagingFromKey = @"from";

static NSString *const kFIRParameterLabel = @"label";

static NSString *const kReengagementSource = @"Firebase";
static NSString *const kReengagementMedium = @"notification";

// Analytics
static NSString *const kAnalyticsEnabled =              @"google.c.a." @"e";
static NSString *const kAnalyticsComposerIdentifier =   @"google.c.a." @"c_id";
static NSString *const kAnalyticsComposerLabel =        @"google.c.a." @"c_l";
static NSString *const kAnalyticsMessageLabel =         @"google.c.a." @"m_l";
static NSString *const kAnalyticsMessageTimestamp =     @"google.c.a." @"ts";
static NSString *const kAnalyticsMessageUseDeviceTime = @"google.c.a." @"udt";
static NSString *const kAnalyticsTrackConversions =     @"google.c.a." @"tc";

@implementation FIRMessagingAnalytics

+ (BOOL)canLogNotification:(NSDictionary *)notification {
  if (!notification.count) {
    // Payload is empty
    return NO;
  }
  NSString *isAnalyticsLoggingEnabled = notification[kAnalyticsEnabled];
  if (![isAnalyticsLoggingEnabled isKindOfClass:[NSString class]] ||
      ![isAnalyticsLoggingEnabled isEqualToString:@"1"]) {
    // Analytics logging is not enabled
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics001,
                            @"Analytics logging is disabled. Do not log event.");
    return NO;
  }
  return YES;
}

+ (void)logOpenNotification:(NSDictionary *)notification
                toAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics {
  [self logUserPropertyForConversionTracking:notification toAnalytics:analytics];
  [self logEvent:kFIRIEventNotificationOpen
withNotification:notification
     toAnalytics:analytics];
}

+ (void)logForegroundNotification:(NSDictionary *)notification
                      toAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics {
  [self logEvent:kFIRIEventNotificationForeground
withNotification:notification
     toAnalytics:analytics];
}

+ (void)logEvent:(NSString *)event
withNotification:(NSDictionary *)notification
     toAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics {
  if (!event.length) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalyticsInvalidEvent,
                             @"Can't log analytics with empty event.");
    return;
  }
  NSMutableDictionary *params = [self paramsForEvent:event withNotification:notification];

  [analytics logEventWithOrigin:@"fcm" name:event parameters:params];
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics005,
                           @"%@: Sending event: %@ params: %@", kLogTag, event, params);
}

+ (NSMutableDictionary *)paramsForEvent:(NSString *)event
                       withNotification:(NSDictionary *)notification {
  NSDictionary *analyticsDataMap = notification;
  if (!analyticsDataMap.count) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics000,
                             @"No data found in notification. Will not log any analytics events.");
    return nil;
  }

  if (![self canLogNotification:analyticsDataMap]) {
    return nil;
  }

  NSMutableDictionary *params = [NSMutableDictionary dictionary];
  NSString *composerIdentifier = analyticsDataMap[kAnalyticsComposerIdentifier];
  if ([composerIdentifier isKindOfClass:[NSString class]] && composerIdentifier.length) {
    params[kFIRIParameterMessageIdentifier] = [composerIdentifier copy];
  }

  NSString *composerLabel = analyticsDataMap[kAnalyticsComposerLabel];
  if ([composerLabel isKindOfClass:[NSString class]] && composerLabel.length) {
    params[kFIRIParameterMessageName] = [composerLabel copy];
  }

  NSString *messageLabel = analyticsDataMap[kAnalyticsMessageLabel];
  if ([messageLabel isKindOfClass:[NSString class]] && messageLabel.length) {
    params[kFIRParameterLabel] = [messageLabel copy];
  }

  NSString *from = analyticsDataMap[kFIRMessagingFromKey];
  if ([from isKindOfClass:[NSString class]] && [from containsString:@"/topics/"]) {
    params[kFIRIParameterTopic] = [from copy];
  }

  id timestamp = analyticsDataMap[kAnalyticsMessageTimestamp];
  if ([timestamp respondsToSelector:@selector(longLongValue)]) {
    int64_t timestampValue = [timestamp longLongValue];
    if (timestampValue != 0) {
      params[kFIRIParameterMessageTime] = @(timestampValue);
    }
  }

  if (analyticsDataMap[kAnalyticsMessageUseDeviceTime]) {
    params[kFIRIParameterMessageDeviceTime] = analyticsDataMap[kAnalyticsMessageUseDeviceTime];
  }

  return params;
}

+ (void)logUserPropertyForConversionTracking:(NSDictionary *)notification
                                 toAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics {
  NSInteger shouldTrackConversions = [notification[kAnalyticsTrackConversions] integerValue];
  if (shouldTrackConversions != 1) {
    return;
  }

  NSString *composerIdentifier = notification[kAnalyticsComposerIdentifier];
  if ([composerIdentifier isKindOfClass:[NSString class]] && composerIdentifier.length) {
    // Set user property for event.
    [analytics setUserPropertyWithOrigin:@"fcm"
                                    name:kFIRIUserPropertyLastNotification
                                   value:composerIdentifier];

    // Set the re-engagement attribution properties.
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:3];
    params[kFIRIParameterSource] = kReengagementSource;
    params[kFIRIParameterMedium] = kReengagementMedium;
    params[kFIRIParameterCampaign] = composerIdentifier;
    [analytics logEventWithOrigin:@"fcm" name:kFIRIEventFirebaseCampaign parameters:params];

    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics003,
                             @"%@: Sending event: %@ params: %@", kLogTag,
                             kFIRIEventFirebaseCampaign, params);

  } else {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics004,
                             @"%@: Failed to set user property: %@ value: %@", kLogTag,
                             kFIRIUserPropertyLastNotification, composerIdentifier);
  }
}

+ (void)logMessage:(NSDictionary *)notification
       toAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics {
    // iOS onlly because Analytics doesn't support tvOS.
#if TARGET_OS_IOS
  if (![self canLogNotification:notification]) {
    return;
  }

  UIApplication *application = [GULAppDelegateSwizzler sharedApplication];
  if (!application) {
    return;
  }
  UIApplicationState applicationState = application.applicationState;
  switch (applicationState) {
    case UIApplicationStateInactive:
      // App was either in background(suspended) or inactive and user tapped on a display
      // notification.
      [self logOpenNotification:notification toAnalytics:analytics];
      break;

    case UIApplicationStateActive:
      // App was in foreground when it received the notification.
      [self logForegroundNotification:notification toAnalytics:analytics];
      break;

    default:
      // Only a silent notification (i.e. 'content-available' is true) can be received while the app
      // is in the background. These messages aren't loggable anyway.
      break;
  }
#endif
}

@end
