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

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRLogger.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMClearcutLogStorage.h"
#import "FIRIAMClearcutLogger.h"
#import "FIRIAMClearcutUploader.h"

@interface FIRIAMClearcutLogger ()

// these two writable for assisting unit testing need
@property(readwrite, nonatomic) FIRIAMClearcutHttpRequestSender *requestSender;
@property(readwrite, nonatomic) id<FIRIAMTimeFetcher> timeFetcher;

@property(readonly, nonatomic) FIRIAMClientInfoFetcher *clientInfoFetcher;
@property(readonly, nonatomic) FIRIAMClearcutUploader *ctUploader;

@property(readonly, copy, nonatomic) NSString *fbProjectNumber;
@property(readonly, copy, nonatomic) NSString *fbAppId;

@end

@implementation FIRIAMClearcutLogger {
  NSString *_iid;
}
- (instancetype)initWithFBProjectNumber:(NSString *)fbProjectNumber
                                fbAppId:(NSString *)fbAppId
                      clientInfoFetcher:(FIRIAMClientInfoFetcher *)clientInfoFetcher
                       usingTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                          usingUploader:(FIRIAMClearcutUploader *)uploader {
  if (self = [super init]) {
    _fbProjectNumber = fbProjectNumber;
    _fbAppId = fbAppId;
    _clientInfoFetcher = clientInfoFetcher;
    _timeFetcher = timeFetcher;
    _ctUploader = uploader;
  }
  return self;
}

+ (void)updateSourceExtensionDictWithAnalyticsEventEnumType:(FIRIAMAnalyticsLogEventType)eventType
                                                    forDict:(NSMutableDictionary *)dict {
  switch (eventType) {
    case FIRIAMAnalyticsEventMessageImpression:
      dict[@"event_type"] = @"IMPRESSION_EVENT_TYPE";
      break;
    case FIRIAMAnalyticsEventActionURLFollow:
      dict[@"event_type"] = @"CLICK_EVENT_TYPE";
      break;
    case FIRIAMAnalyticsEventMessageDismissAuto:
      dict[@"dismiss_type"] = @"AUTO";
      break;
    case FIRIAMAnalyticsEventMessageDismissClick:
      dict[@"dismiss_type"] = @"CLICK";
      break;
    case FIRIAMAnalyticsEventMessageDismissSwipe:
      dict[@"dismiss_type"] = @"SWIPE";
      break;
    case FIRIAMAnalyticsEventImageFetchError:
      dict[@"render_error_reason"] = @"IMAGE_FETCH_ERROR";
      break;
    case FIRIAMAnalyticsEventImageFormatUnsupported:
      dict[@"render_error_reason"] = @"IMAGE_UNSUPPORTED_FORMAT";
      break;
    case FIRIAMAnalyticsEventFetchAPIClientError:
      dict[@"fetch_error_reason"] = @"CLIENT_ERROR";
      break;
    case FIRIAMAnalyticsEventFetchAPIServerError:
      dict[@"fetch_error_reason"] = @"SERVER_ERROR";
      break;
    case FIRIAMAnalyticsEventFetchAPINetworkError:
      dict[@"fetch_error_reason"] = @"NETWORK_ERROR";
      break;
    case FIRIAMAnalyticsEventTestMessageImpression:
      dict[@"event_type"] = @"TEST_MESSAGE_IMPRESSION_EVENT_TYPE";
      break;
    case FIRIAMAnalyticsEventTestMessageClick:
      dict[@"event_type"] = @"TEST_MESSAGE_CLICK_EVENT_TYPE";
      break;
    case FIRIAMAnalyticsLogEventUnknown:
      break;
  }
}

// constructing CampaignAnalytics proto defined in campaign_analytics.proto and serialize it into
// a string.
// @return nil if error happened
- (NSString *)constructSourceExtensionJsonForClearcutWithEventType:
                  (FIRIAMAnalyticsLogEventType)eventType
                                                     forCampaignID:(NSString *)campaignID
                                                     eventTimeInMs:(NSNumber *)eventTimeInMs
                                                        instanceID:(NSString *)instanceID {
  NSMutableDictionary *campaignAnalyticsDict = [[NSMutableDictionary alloc] init];

  campaignAnalyticsDict[@"project_number"] = self.fbProjectNumber;
  campaignAnalyticsDict[@"campaign_id"] = campaignID;
  campaignAnalyticsDict[@"client_app"] =
      @{@"google_app_id" : self.fbAppId, @"firebase_instance_id" : instanceID};
  campaignAnalyticsDict[@"client_timestamp_millis"] = eventTimeInMs;
  [self.class updateSourceExtensionDictWithAnalyticsEventEnumType:eventType
                                                          forDict:campaignAnalyticsDict];

  campaignAnalyticsDict[@"fiam_sdk_version"] = [self.clientInfoFetcher getIAMSDKVersion];

  // turn campaignAnalyticsDict into a json string
  NSError *error;
  NSData *jsonData = [NSJSONSerialization
      dataWithJSONObject:campaignAnalyticsDict  // Here you can pass array or dictionary
                 options:0  // Pass 0 if you don't care about the readability of the generated
                            // string
                   error:&error];

  if (jsonData) {
    NSString *jsonString;
    jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM210006",
                @"Source extension json string produced as %@", jsonString);
    return jsonString;
  } else {
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM210007",
                  @"Error in generating source extension json string: %@", error);
    return nil;
  }
}

- (void)logAnalyticsEventForType:(FIRIAMAnalyticsLogEventType)eventType
                   forCampaignID:(NSString *)campaignID
               withEventTimeInMs:(nullable NSNumber *)eventTimeInMs
                             IID:(NSString *)iid
                      completion:(void (^)(BOOL success))completion {
  NSTimeInterval nowInMs = [self.timeFetcher currentTimestampInSeconds] * 1000;
  if (eventTimeInMs == nil) {
    eventTimeInMs = @((long)nowInMs);
  }

  if (!iid) {
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM210009",
                  @"Instance ID is nil, event %ld for campaign ID %@ will not be sent",
                  (long)eventType, campaignID);
    return;
  }

  NSString *sourceExtensionJsonString =
      [self constructSourceExtensionJsonForClearcutWithEventType:eventType
                                                   forCampaignID:campaignID
                                                   eventTimeInMs:eventTimeInMs
                                                      instanceID:iid];

  FIRIAMClearcutLogRecord *newRecord = [[FIRIAMClearcutLogRecord alloc]
      initWithExtensionJsonString:sourceExtensionJsonString
          eventTimestampInSeconds:eventTimeInMs.integerValue / 1000];
  [self.ctUploader addNewLogRecord:newRecord];
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM210003",
              @"One more clearcut log record created and sent to uploader with source extension %@",
              sourceExtensionJsonString);
  completion(YES);
}

- (void)logAnalyticsEventForType:(FIRIAMAnalyticsLogEventType)eventType
                   forCampaignID:(NSString *)campaignID
                withCampaignName:(NSString *)campaignName
                   eventTimeInMs:(nullable NSNumber *)eventTimeInMs
                      completion:(void (^)(BOOL success))completion {
  if (!_iid) {
    [self.clientInfoFetcher
        fetchFirebaseIIDDataWithProjectNumber:self.fbProjectNumber
                               withCompletion:^(NSString *_Nullable iid, NSString *_Nullable token,
                                                NSError *_Nullable error) {
                                 if (error) {
                                   FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM210001",
                                                 @"Failed to get iid value for clearcut logging %@",
                                                 error);
                                   completion(NO);
                                 } else {
                                   // persist iid through the whole life-cycle
                                   self->_iid = iid;
                                   [self logAnalyticsEventForType:eventType
                                                    forCampaignID:campaignID
                                                withEventTimeInMs:eventTimeInMs
                                                              IID:iid
                                                       completion:completion];
                                 }
                               }];
  } else {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM210004",
                @"Using remembered iid for event logging");
    [self logAnalyticsEventForType:eventType
                     forCampaignID:campaignID
                 withEventTimeInMs:eventTimeInMs
                               IID:_iid
                        completion:completion];
  }
}
@end
