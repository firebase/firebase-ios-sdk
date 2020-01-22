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

#import <Foundation/Foundation.h>
#import "FIRIAMClientInfoFetcher.h"
#import "FIRIAMTimeFetcher.h"

NS_ASSUME_NONNULL_BEGIN

/// Values for different fiam activity types.
typedef NS_ENUM(NSInteger, FIRIAMAnalyticsLogEventType) {

  FIRIAMAnalyticsLogEventUnknown = -1,

  FIRIAMAnalyticsEventMessageImpression = 0,
  FIRIAMAnalyticsEventActionURLFollow = 1,
  FIRIAMAnalyticsEventMessageDismissAuto = 2,
  FIRIAMAnalyticsEventMessageDismissClick = 3,
  FIRIAMAnalyticsEventMessageDismissSwipe = 4,

  // category: errors happened
  FIRIAMAnalyticsEventImageFetchError = 11,
  FIRIAMAnalyticsEventImageFormatUnsupported = 12,

  FIRIAMAnalyticsEventFetchAPINetworkError = 13,
  FIRIAMAnalyticsEventFetchAPIClientError = 14,  // server returns 4xx status code
  FIRIAMAnalyticsEventFetchAPIServerError = 15,  // server returns 5xx status code

  // Events for test messages
  FIRIAMAnalyticsEventTestMessageImpression = 16,
  FIRIAMAnalyticsEventTestMessageClick = 17,
};

// a protocol for collecting Analytics log records. It's implementation will decide
// what to do with that analytics log record
@protocol FIRIAMAnalyticsEventLogger
/**
 * Adds an analytics log record.
 * @param eventTimeInMs the timestamp in ms for when the event happened.
 *      if it's nil, the implementation will use the current system for this info.
 */
- (void)logAnalyticsEventForType:(FIRIAMAnalyticsLogEventType)eventType
                   forCampaignID:(NSString *)campaignID
                withCampaignName:(NSString *)campaignName
                   eventTimeInMs:(nullable NSNumber *)eventTimeInMs
                      completion:(void (^)(BOOL success))completion;
@end
NS_ASSUME_NONNULL_END
