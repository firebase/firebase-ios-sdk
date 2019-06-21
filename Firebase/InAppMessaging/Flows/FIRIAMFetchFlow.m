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

#import <FirebaseCore/FIRLogger.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMClearcutLogger.h"
#import "FIRIAMFetchFlow.h"
#import "FIRIAMRuntimeManager.h"

@implementation FIRIAMFetchSetting
@end

// the notification message to say that the fetch flow is done
NSString *const kFIRIAMFetchIsDoneNotification = @"FIRIAMFetchIsDoneNotification";

@interface FIRIAMFetchFlow ()
@property(nonatomic) id<FIRIAMTimeFetcher> timeFetcher;
@property(nonatomic) NSTimeInterval lastFetchTime;
@property(nonatomic, nonnull, readonly) FIRIAMFetchSetting *setting;
@property(nonatomic, nonnull, readonly) FIRIAMMessageClientCache *messageCache;
@property(nonatomic) id<FIRIAMMessageFetcher> messageFetcher;
@property(nonatomic, nonnull, readonly) id<FIRIAMBookKeeper> fetchBookKeeper;
@property(nonatomic, nonnull, readonly) FIRIAMActivityLogger *activityLogger;
@property(nonatomic, nonnull, readonly) id<FIRIAMAnalyticsEventLogger> analyticsEventLogger;

@property(nonatomic, nonnull, readonly) FIRIAMSDKModeManager *sdkModeManager;
@end

@implementation FIRIAMFetchFlow
- (instancetype)initWithSetting:(FIRIAMFetchSetting *)setting
                   messageCache:(FIRIAMMessageClientCache *)cache
                 messageFetcher:(id<FIRIAMMessageFetcher>)messageFetcher
                    timeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                     bookKeeper:(id<FIRIAMBookKeeper>)fetchBookKeeper
                 activityLogger:(FIRIAMActivityLogger *)activityLogger
           analyticsEventLogger:(id<FIRIAMAnalyticsEventLogger>)analyticsEventLogger
           FIRIAMSDKModeManager:(FIRIAMSDKModeManager *)sdkModeManager {
  if (self = [super init]) {
    _timeFetcher = timeFetcher;
    _lastFetchTime = [fetchBookKeeper lastFetchTime];
    _setting = setting;
    _messageCache = cache;
    _messageFetcher = messageFetcher;
    _fetchBookKeeper = fetchBookKeeper;
    _activityLogger = activityLogger;
    _analyticsEventLogger = analyticsEventLogger;
    _sdkModeManager = sdkModeManager;
  }
  return self;
}

- (FIRIAMAnalyticsLogEventType)fetchErrorToLogEventType:(NSError *)error {
  if ([error.domain isEqual:NSURLErrorDomain]) {
    if (error.code == NSURLErrorNotConnectedToInternet) {
      return FIRIAMAnalyticsEventFetchAPINetworkError;
    } else {
      // error.code could be a non 2xx status code
      if (error.code > 0) {
        if (error.code >= 400 && error.code < 500) {
          return FIRIAMAnalyticsEventFetchAPIClientError;
        } else {
          if (error.code >= 500 && error.code < 600) {
            return FIRIAMAnalyticsEventFetchAPIServerError;
          }
        }
      }
    }
  }

  return FIRIAMAnalyticsLogEventUnknown;
}

- (void)sendFetchIsDoneNotification {
  [[NSNotificationCenter defaultCenter] postNotificationName:kFIRIAMFetchIsDoneNotification
                                                      object:self];
}

- (void)handleSuccessullyFetchedMessages:(NSArray<FIRIAMMessageDefinition *> *)messagesInResponse
                       withFetchWaitTime:(NSNumber *_Nullable)fetchWaitTime
                      requestImpressions:(NSArray<FIRIAMImpressionRecord *> *)requestImpressions {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM700004", @"%lu messages were fetched successfully.",
              (unsigned long)messagesInResponse.count);

  for (FIRIAMMessageDefinition *next in messagesInResponse) {
    if (next.isTestMessage && self.sdkModeManager.currentMode != FIRIAMSDKModeTesting) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM700006",
                  @"Seeing test message in fetch response. Turn "
                   "the current instance into a testing instance.");
      [self.sdkModeManager becomeTestingInstance];
    }
  }

  NSArray<NSString *> *responseMessageIDs =
      [messagesInResponse valueForKeyPath:@"renderData.messageID"];
  NSArray<NSString *> *impressionMessageIDs = [requestImpressions valueForKey:@"messageID"];

  // We are going to clear impression records for those IDs that are in both impressionMessageIDs
  // and responseMessageIDs. This is to avoid incorrectly clearing impressions records that come
  // in between the sending the request and receiving the response for the fetch operation.
  // So we are computing intersection between responseMessageIDs and impressionMessageIDs and use
  // that for impression log clearing.
  NSMutableSet *idIntersection = [NSMutableSet setWithArray:responseMessageIDs];
  [idIntersection intersectSet:[NSSet setWithArray:impressionMessageIDs]];

  [self.fetchBookKeeper clearImpressionsWithMessageList:[idIntersection allObjects]];
  [self.messageCache setMessageData:messagesInResponse];

  [self.sdkModeManager registerOneMoreFetch];
  [self.fetchBookKeeper recordNewFetchWithFetchCount:messagesInResponse.count
                              withTimestampInSeconds:[self.timeFetcher currentTimestampInSeconds]
                                   nextFetchWaitTime:fetchWaitTime];
}

- (void)checkAndFetchForInitialAppLaunch:(BOOL)forInitialAppLaunch {
  NSTimeInterval intervalFromLastFetchInSeconds =
      [self.timeFetcher currentTimestampInSeconds] - self.fetchBookKeeper.lastFetchTime;

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM700005",
              @"Interval from last time fetch is %lf seconds", intervalFromLastFetchInSeconds);

  BOOL fetchIsAllowedNow = NO;

  if (intervalFromLastFetchInSeconds >= self.fetchBookKeeper.nextFetchWaitTime) {
    // it's enough wait time interval from last fetch.
    fetchIsAllowedNow = YES;
  } else {
    FIRIAMSDKMode sdkMode = [self.sdkModeManager currentMode];
    if (sdkMode == FIRIAMSDKModeNewlyInstalled || sdkMode == FIRIAMSDKModeTesting) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM700007",
                  @"OK to fetch due to current SDK mode being %@",
                  FIRIAMDescriptonStringForSDKMode(sdkMode));
      fetchIsAllowedNow = YES;
    } else {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM700008",
                  @"Interval from last time fetch is %lf seconds, smaller than fetch wait time %lf",
                  intervalFromLastFetchInSeconds, self.fetchBookKeeper.nextFetchWaitTime);
    }
  }

  if (fetchIsAllowedNow) {
    // we are allowed to fetch in-app message from time interval wise

    FIRIAMActivityRecord *record =
        [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeCheckForFetch
                                              isSuccessful:YES
                                                withDetail:@"OK to do a fetch"
                                                 timestamp:nil];
    [self.activityLogger addLogRecord:record];

    NSArray<FIRIAMImpressionRecord *> *impressions = [self.fetchBookKeeper getImpressions];
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM700001", @"Go ahead to fetch messages");

    NSTimeInterval fetchStartTime = [[NSDate date] timeIntervalSince1970];

    [self.messageFetcher
        fetchMessagesWithImpressionList:impressions
                         withCompletion:^(NSArray<FIRIAMMessageDefinition *> *_Nullable messages,
                                          NSNumber *_Nullable nextFetchWaitTime,
                                          NSInteger discardedMessageCount,
                                          NSError *_Nullable error) {
                           if (error) {
                             FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM700002",
                                           @"Error happened during message fetching %@", error);

                             FIRIAMAnalyticsLogEventType eventType =
                                 [self fetchErrorToLogEventType:error];

                             [self.analyticsEventLogger logAnalyticsEventForType:eventType
                                                                   forCampaignID:@"all"
                                                                withCampaignName:@"all"
                                                                   eventTimeInMs:nil
                                                                      completion:^(BOOL success){
                                                                          // nothing to do
                                                                      }];

                             FIRIAMActivityRecord *record = [[FIRIAMActivityRecord alloc]
                                 initWithActivityType:FIRIAMActivityTypeFetchMessage
                                         isSuccessful:NO
                                           withDetail:error.description
                                            timestamp:nil];
                             [self.activityLogger addLogRecord:record];
                           } else {
                             double fetchOperationLatencyInMills =
                                 ([[NSDate date] timeIntervalSince1970] - fetchStartTime) * 1000;
                             NSString *impressionListString =
                                 [impressions componentsJoinedByString:@","];
                             NSString *activityLogDetail = @"";

                             if (discardedMessageCount > 0) {
                               activityLogDetail = [NSString
                                   stringWithFormat:
                                       @"%lu messages fetched with impression list as [%@]"
                                        " and %lu messages are discarded due to data being "
                                        "invalid. It took"
                                        " %lf milliseconds",
                                       (unsigned long)messages.count, impressionListString,
                                       (unsigned long)discardedMessageCount,
                                       fetchOperationLatencyInMills];
                             } else {
                               activityLogDetail = [NSString
                                   stringWithFormat:
                                       @"%lu messages fetched with impression list as [%@]. It took"
                                        " %lf milliseconds",
                                       (unsigned long)messages.count, impressionListString,
                                       fetchOperationLatencyInMills];
                             }

                             FIRIAMActivityRecord *record = [[FIRIAMActivityRecord alloc]
                                 initWithActivityType:FIRIAMActivityTypeFetchMessage
                                         isSuccessful:YES
                                           withDetail:activityLogDetail
                                            timestamp:nil];
                             [self.activityLogger addLogRecord:record];

                             // Now handle the fetched messages.
                             [self handleSuccessullyFetchedMessages:messages
                                                  withFetchWaitTime:nextFetchWaitTime
                                                 requestImpressions:impressions];

                             if (forInitialAppLaunch) {
                               [self checkForAppLaunchMessage];
                             }
                           }
                           // Send this regardless whether fetch is successful or not.
                           [self sendFetchIsDoneNotification];
                         }];

  } else {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM700003",
                @"Only %lf seconds from last fetch time. No action.",
                intervalFromLastFetchInSeconds);
    // for no fetch case, we still send out the notification so that and display flow can continue
    // from here.
    [self sendFetchIsDoneNotification];
    FIRIAMActivityRecord *record =
        [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeCheckForFetch
                                              isSuccessful:NO
                                                withDetail:@"Abort due to check time interval "
                                                            "not reached yet"
                                                 timestamp:nil];
    [self.activityLogger addLogRecord:record];
  }
}

- (void)checkForAppLaunchMessage {
  [[FIRIAMRuntimeManager getSDKRuntimeInstance]
          .displayExecutor checkAndDisplayNextAppLaunchMessage];
}
@end
