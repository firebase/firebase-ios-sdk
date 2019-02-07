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

#import "FIRIAMAnalyticsEventLoggerImpl.h"

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseCore/FIRLogger.h>
#import "FIRCore+InAppMessaging.h"
#import "FIRIAMClearcutLogger.h"

typedef void (^FIRAUserPropertiesCallback)(NSDictionary *userProperties);

@interface FIRIAMAnalyticsEventLoggerImpl ()
@property(readonly, nonatomic) FIRIAMClearcutLogger *clearCutLogger;
@property(readonly, nonatomic) id<FIRIAMTimeFetcher> timeFetcher;
@property(nonatomic, readonly) NSUserDefaults *userDefaults;
@end

// in these kFAXX constants, FA represents FirebaseAnalytics
static NSString *const kFIREventOriginFIAM = @"fiam";
;
static NSString *const kFAEventNameForImpression = @"firebase_in_app_message_impression";
static NSString *const kFAEventNameForAction = @"firebase_in_app_message_action";
static NSString *const kFAEventNameForDismiss = @"firebase_in_app_message_dismiss";

// In order to support tracking conversions from clicking a fiam event, we need to set
// an analytics user property with the fiam message's campaign id.
// This is the user property as kFIRUserPropertyLastNotification defined for FCM.
// Unlike FCM, FIAM would only allow the user property to exist up to certain expiration time
// after which, we stop attributing any further conversions to that fiam message click.
// So we include kFAUserPropertyPrefixForFIAM as the prefix for the entry written by fiam SDK
// to avoid removing entries written by FCM SDK
static NSString *const kFAUserPropertyForLastNotification = @"_ln";
static NSString *const kFAUserPropertyPrefixForFIAM = @"fiam:";

// This user defaults key is for the entry to tell when we should remove the private user
// property from a prior action url click to stop conversion attribution for a campaign
static NSString *const kFIAMUserDefaualtsKeyForRemoveUserPropertyTimeInSeconds =
    @"firebase-iam-conversion-tracking-expires-in-seconds";

@implementation FIRIAMAnalyticsEventLoggerImpl {
  id<FIRAnalyticsInterop> _analytics;
}

- (instancetype)initWithClearcutLogger:(FIRIAMClearcutLogger *)ctLogger
                      usingTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                     usingUserDefaults:(nullable NSUserDefaults *)userDefaults
                             analytics:(nullable id<FIRAnalyticsInterop>)analytics {
  if (self = [super init]) {
    _clearCutLogger = ctLogger;
    _timeFetcher = timeFetcher;
    _analytics = analytics;
    _userDefaults = userDefaults ? userDefaults : [NSUserDefaults standardUserDefaults];

    if (!_analytics) {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM280002",
                    @"Firebase In App Messaging was not configured with FirebaseAnalytics.");
    }
  }
  return self;
}

- (NSDictionary *)constructFAEventParamsWithCampaignID:(NSString *)campaignID
                                          campaignName:(NSString *)campaignName {
  // event parameter names are aligned with definitions in event_names_util.cc
  return @{
    @"_nmn" : campaignName ?: @"unknown",
    @"_nmid" : campaignID ?: @"unknown",
    @"_ndt" : @([self.timeFetcher currentTimestampInSeconds])
  };
}

- (void)logFAEventsForMessageImpressionWithcampaignID:(NSString *)campaignID
                                         campaignName:(NSString *)campaignName {
  if (_analytics) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM280001",
                @"Log campaign impression Firebase Analytics event for campaign ID %@", campaignID);

    NSDictionary *params = [self constructFAEventParamsWithCampaignID:campaignID
                                                         campaignName:campaignName];
    [_analytics logEventWithOrigin:kFIREventOriginFIAM
                              name:kFAEventNameForImpression
                        parameters:params];
  }
}

- (BOOL)setAnalyticsUserPropertyForKey:(NSString *)key withValue:(NSString *)value {
  if (!_analytics || !key || !value) {
    return NO;
  }
  [_analytics setUserPropertyWithOrigin:kFIREventOriginFIAM name:key value:value];
  return YES;
}

- (void)logFAEventsForMessageActionWithCampaignID:(NSString *)campaignID
                                     campaignName:(NSString *)campaignName {
  if (_analytics) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM280004",
                @"Log action click Firebase Analytics event for campaign ID %@", campaignID);

    NSDictionary *params = [self constructFAEventParamsWithCampaignID:campaignID
                                                         campaignName:campaignName];

    [_analytics logEventWithOrigin:kFIREventOriginFIAM
                              name:kFAEventNameForAction
                        parameters:params];
  }

  // set a special user property so that conversion events can be queried based on that
  // for reporting purpose
  NSString *conversionTrackingUserPropertyValue =
      [NSString stringWithFormat:@"%@%@", kFAUserPropertyPrefixForFIAM, campaignID];

  if ([self setAnalyticsUserPropertyForKey:kFAUserPropertyForLastNotification
                                 withValue:conversionTrackingUserPropertyValue]) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM280009",
                @"User property for conversion tracking was set for campaign %@", campaignID);
  }
}

- (void)logFAEventsForMessageDismissWithcampaignID:(NSString *)campaignID
                                      campaignName:(NSString *)campaignName {
  if (_analytics) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM280007",
                @"Log message dismiss Firebase Analytics event for campaign ID %@", campaignID);

    NSDictionary *params = [self constructFAEventParamsWithCampaignID:campaignID
                                                         campaignName:campaignName];
    [_analytics logEventWithOrigin:kFIREventOriginFIAM
                              name:kFAEventNameForDismiss
                        parameters:params];
  }
}

- (void)logAnalyticsEventForType:(FIRIAMAnalyticsLogEventType)eventType
                   forCampaignID:(NSString *)campaignID
                withCampaignName:(NSString *)campaignName
                   eventTimeInMs:(nullable NSNumber *)eventTimeInMs
                      completion:(void (^)(BOOL success))completion {
  // log Firebase Analytics event first
  if (eventType == FIRIAMAnalyticsEventMessageImpression) {
    [self logFAEventsForMessageImpressionWithcampaignID:campaignID campaignName:campaignName];
  } else if (eventType == FIRIAMAnalyticsEventActionURLFollow) {
    [self logFAEventsForMessageActionWithCampaignID:campaignID campaignName:campaignName];
  } else if (eventType == FIRIAMAnalyticsEventMessageDismissAuto ||
             eventType == FIRIAMAnalyticsEventMessageDismissClick) {
    [self logFAEventsForMessageDismissWithcampaignID:campaignID campaignName:campaignName];
  }

  // and do clearcut logging as well
  [self.clearCutLogger logAnalyticsEventForType:eventType
                                  forCampaignID:campaignID
                               withCampaignName:campaignName
                                  eventTimeInMs:eventTimeInMs
                                     completion:completion];
}
@end
