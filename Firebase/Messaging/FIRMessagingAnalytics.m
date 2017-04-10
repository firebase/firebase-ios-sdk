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

#import "FIRMessagingAnalytics.h"

//#import "analytics-private/FIRAnalytics+Internal.h"
//#import "analytics-private/FIREventNames+Internal.h"
//#import "analytics-private/FIREventOrigins.h"
//#import "analytics-private/FIRParameterNames+Internal.h"
//#import "analytics-private/FIRUserPropertyNames+Internal.h"
//#import <FirebaseAnalytics/FIRAnalytics.h>

#import "FIRMessagingConstants.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingUtilities.h"

static NSString *const kAnalyticsLogEventClassString = @"FIRAnalytics";
static NSString *const kAnalyticsLogEventSelectorString =
    @"logInternalEventWithOrigin:name:parameters:";

static NSString *const kAnalyticsSetInternalUserPropertySelectorString =
    @"setInternalUserProperty:forName:";

static NSString *const kLogTag = @"FIRMessagingAnalytics";

// aps Key
static NSString *const kApsKey = @"aps";
static NSString *const kApsAlertKey = @"alert";
static NSString *const kApsSoundKey = @"sound";
static NSString *const kApsBadgeKey = @"badge";
static NSString *const kApsContentAvailableKey = @"badge";

// Data Key
static NSString *const kDataKey = @"data";

static NSString *const kReengagementSource = @"Firebase";
static NSString *const kReengagementMedium = @"notification";

// Analytics
static NSString *const kAnalyticsEnabled =              @"google.c.a." @"e";
static NSString *const kAnalyticsComposerIdentifier =   @"google.c.a." @"c_id";
static NSString *const kAnalyticsComposerLabel =        @"google.c.a." @"c_l";
static NSString *const kAnalyticsMessageTimestamp =     @"google.c.a." @"ts";
static NSString *const kAnalyticsMessageUseDeviceTime = @"google.c.a." @"udt";
static NSString *const kAnalyticsTrackConversions =     @"google.c.a." @"tc";

@implementation FIRMessagingAnalytics

+ (BOOL)canLogNotification:(NSDictionary *)notification {
  if (!notification.count) {
    // Payload is empty
    return NO;
  }
  NSDictionary *apsDictionary = notification[kApsKey];
  if (!apsDictionary[kApsAlertKey] &&
      !apsDictionary[kApsSoundKey] &&
      !apsDictionary[kApsBadgeKey]) {
    // This is not a display notification
    return NO;
  }
  NSString *composerIdentifier = notification[kAnalyticsComposerIdentifier];
  if (![composerIdentifier isKindOfClass:[NSString class]] || !composerIdentifier.length) {
    // Invalid, missing or empty composer id
    return NO;
  }
  // Is a display message with a composer id
  return YES;
}

+ (void)logOpenNotification:(NSDictionary *)notification {
  [self logEvent:@"Replace ME" withNotification:notification];
}

+ (void)logForegroundNotification:(NSDictionary *)notification {
  [self logEvent:@"Replace ME" withNotification:notification];
}

+ (void)logEvent:(NSString *)event withNotification:(NSDictionary *)notification {
  NSMutableDictionary *params = [NSMutableDictionary dictionary];

  NSDictionary *analyticsDataMap = notification;
  if (!analyticsDataMap.count) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics000,
                            @"No data found in notification. Will not log any analytics events.");
    return;
  }

  NSString *composerIdentifier = analyticsDataMap[kAnalyticsComposerIdentifier];
  NSString *composerLabel = analyticsDataMap[kAnalyticsComposerLabel];

  if ([composerIdentifier isKindOfClass:[NSString class]] && composerIdentifier.length) {
    params[@"Replace ME"] = [composerIdentifier copy];
  } else {
    // The message could be a topic message.
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics001,
                            @"Nil composer id for event: %@. Do not log message.", event);
    return;
  }

  if ([composerLabel isKindOfClass:[NSString class]] && composerLabel.length) {
    params[@"Replace ME"] = [composerLabel copy];
  }

  NSString *from = analyticsDataMap[kFIRMessagingFromKey];
  if ([from isKindOfClass:[NSString class]] && [from containsString:@"/topics/"]) {
    params[@"Replace ME"] = [from copy];
  }

  int64_t timestamp = [analyticsDataMap[kAnalyticsMessageTimestamp] longLongValue];
  if (timestamp) {
    params[@"Replace ME"] = @(timestamp);
  }

  if (analyticsDataMap[kAnalyticsMessageUseDeviceTime]) {
    params[@"Replace ME"] = analyticsDataMap[kAnalyticsMessageUseDeviceTime];
  }

  if (!params.count) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics002,
                            @"%@: FIRMessaging analytics event %@ has no params, will not log "
                            @" analytics event.",
                            kLogTag, event);
    return;
  }


  NSInteger shouldTrackConversions = [analyticsDataMap[kAnalyticsTrackConversions] integerValue];

  if (shouldTrackConversions == 1) {
    // Set user property for event.
    if ([event isEqualToString:@"Replace ME"]) {
      SEL userPropertySelector =
          NSSelectorFromString(kAnalyticsSetInternalUserPropertySelectorString);
      Class firebaseAnalyticsClass = NSClassFromString(kAnalyticsLogEventClassString);

      if (composerIdentifier.length &&
          [firebaseAnalyticsClass respondsToSelector:userPropertySelector]) {
//        [firebaseAnalyticsClass setInternalUserProperty:composerIdentifier
//                                                forName:@"Replace ME"];

        // Set the re-engagement attribution properties.
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:3];
        params[@"Replace ME"] = kReengagementSource;
        params[@"Replace ME"] = kReengagementMedium;
        params[@"Replace ME"] = composerIdentifier;

        [self logAnalyticsEventWithOrigin:@"Replace ME"
                                     name:@"Replace ME"
                               parameters:params];
        FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics003,
                                @"%@: Sending event: %@ params: %@", kLogTag,
                                @"TODO kFIREventFirebaseCampaign", params);

      } else {
        FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics004,
                                @"%@: Failed to set user property: %@ value: %@", kLogTag,
                                @"TODO kFIRUserPropertyLastNotification", composerIdentifier);
      }
    }
  }

  [self logAnalyticsEventWithOrigin:@"TODO kFIREventOriginFCM" name:event parameters:params];
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics005, @"%@: Sending event: %@ params: %@",
                          kLogTag, event, params);
}

+ (void)logAnalyticsEventWithOrigin:(NSString *)origin
                               name:(NSString *)name
                         parameters:(NSDictionary *)params {
  SEL logEventSelector = NSSelectorFromString(kAnalyticsLogEventSelectorString);
  Class firebaseAnalyticsClass = NSClassFromString(kAnalyticsLogEventClassString);

  if ([firebaseAnalyticsClass respondsToSelector:logEventSelector]) {
 //   [firebaseAnalyticsClass logInternalEventWithOrigin:origin name:name parameters:params];
  } else {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeAnalytics008,
                            @"%@: Missing selector %@, failed to send event to Analytics.", kLogTag,
                            kAnalyticsLogEventSelectorString);
  }
}

@end

