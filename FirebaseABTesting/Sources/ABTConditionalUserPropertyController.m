// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebaseABTesting/Sources/ABTConditionalUserPropertyController.h"

#import <FirebaseABTesting/FIRLifecycleEvents.h>
#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseCore/FIRLogger.h>
#import "FirebaseABTesting/Sources/ABTConstants.h"

@implementation ABTConditionalUserPropertyController {
  dispatch_queue_t _analyticOperationQueue;
  id<FIRAnalyticsInterop> _Nullable _analytics;
}

/// Returns the ABTConditionalUserPropertyController singleton.
+ (instancetype)sharedInstanceWithAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics {
  static ABTConditionalUserPropertyController *sharedInstance = nil;
  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[ABTConditionalUserPropertyController alloc] initWithAnalytics:analytics];
  });
  return sharedInstance;
}

- (instancetype)initWithAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics {
  self = [super init];
  if (self) {
    _analyticOperationQueue =
        dispatch_queue_create("com.google.FirebaseABTesting.analytics", DISPATCH_QUEUE_SERIAL);
    _analytics = analytics;
  }
  return self;
}

#pragma mark - experiments proxy methods on Firebase Analytics

- (NSArray *)experimentsWithOrigin:(NSString *)origin {
  return [_analytics conditionalUserProperties:origin propertyNamePrefix:@""];
}

- (void)clearExperiment:(NSString *)experimentID
              variantID:(NSString *)variantID
             withOrigin:(NSString *)origin
                payload:(ABTExperimentPayload *)payload
                 events:(FIRLifecycleEvents *)events {
  // Payload always overwrite event names.
  NSString *clearExperimentEventName = events.clearExperimentEventName;
  if (payload && payload.clearEventToLog && payload.clearEventToLog.length) {
    clearExperimentEventName = payload.clearEventToLog;
  }

  [_analytics clearConditionalUserProperty:experimentID
                                 forOrigin:origin
                            clearEventName:clearExperimentEventName
                      clearEventParameters:@{experimentID : variantID}];

  FIRLogDebug(kFIRLoggerABTesting, @"I-ABT000015", @"Clear Experiment ID %@, variant ID %@.",
              experimentID, variantID);
}

- (void)setExperimentWithOrigin:(NSString *)origin
                        payload:(ABTExperimentPayload *)payload
                         events:(FIRLifecycleEvents *)events
                         policy:(ABTExperimentPayload_ExperimentOverflowPolicy)policy {
  NSInteger maxNumOfExperiments = [self maxNumberOfExperimentsOfOrigin:origin];
  if (maxNumOfExperiments < 0) {
    return;
  }

  // Clear experiments if overflow
  NSArray *experiments = [self experimentsWithOrigin:origin];
  if (!experiments) {
    FIRLogInfo(kFIRLoggerABTesting, @"I-ABT000003",
               @"Failed to get conditional user properties from Firebase Analytics.");
    return;
  }

  if (maxNumOfExperiments <= experiments.count) {
    ABTExperimentPayload_ExperimentOverflowPolicy overflowPolicy =
        [self overflowPolicyWithPayload:payload originalPolicy:policy];
    id experimentToClear = experiments.firstObject;
    if (overflowPolicy == ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest &&
        experimentToClear) {
      NSString *expID = [self experimentIDOfExperiment:experimentToClear];
      NSString *varID = [self variantIDOfExperiment:experimentToClear];

      [self clearExperiment:expID variantID:varID withOrigin:origin payload:payload events:events];
      FIRLogDebug(kFIRLoggerABTesting, @"I-ABT000016",
                  @"Clear experiment ID %@ variant ID %@ due to "
                  @"overflow policy.",
                  expID, varID);

    } else {
      FIRLogDebug(kFIRLoggerABTesting, @"I-ABT000017",
                  @"Experiment ID %@ variant ID %@ won't be set due to "
                  @"overflow policy.",
                  payload.experimentId, payload.variantId);

      return;
    }
  }

  // Clear experiment if other variant ID exists.
  NSString *experimentID = payload.experimentId;
  NSString *variantID = payload.variantId;
  for (id experiment in experiments) {
    NSString *expID = [self experimentIDOfExperiment:experiment];
    NSString *varID = [self variantIDOfExperiment:experiment];
    if ([expID isEqualToString:experimentID] && ![varID isEqualToString:variantID]) {
      FIRLogDebug(kFIRLoggerABTesting, @"I-ABT000018",
                  @"Clear experiment ID %@ with variant ID %@ because "
                  @"only one variant ID can be existed "
                  @"at any time.",
                  expID, varID);
      [self clearExperiment:expID variantID:varID withOrigin:origin payload:payload events:events];
    }
  }

  // Set experiment
  NSDictionary<NSString *, id> *experiment = [self createExperimentFromOrigin:origin
                                                                      payload:payload
                                                                       events:events];

  [_analytics setConditionalUserProperty:experiment];

  FIRLogDebug(kFIRLoggerABTesting, @"I-ABT000019",
              @"Set conditional user property, experiment ID %@ with "
              @"variant ID %@ triggered event %@.",
              experimentID, variantID, payload.triggerEvent);

  // Log setEvent (experiment lifecycle event to be set when an experiment is set)
  [self logEventWithOrigin:origin payload:payload events:events];
}

- (NSMutableDictionary<NSString *, id> *)createExperimentFromOrigin:(NSString *)origin
                                                            payload:(ABTExperimentPayload *)payload
                                                             events:(FIRLifecycleEvents *)events {
  NSMutableDictionary<NSString *, id> *experiment = [[NSMutableDictionary alloc] init];
  NSString *experimentID = payload.experimentId;
  NSString *variantID = payload.variantId;

  NSDictionary *eventParams = @{experimentID : variantID};

  [experiment setValue:origin forKey:kABTExperimentDictionaryOriginKey];

  NSTimeInterval creationTimestamp = (double)(payload.experimentStartTimeMillis / ABT_MSEC_PER_SEC);
  [experiment setValue:@(creationTimestamp) forKey:kABTExperimentDictionaryCreationTimestampKey];
  [experiment setValue:experimentID forKey:kABTExperimentDictionaryExperimentIDKey];
  [experiment setValue:variantID forKey:kABTExperimentDictionaryVariantIDKey];

  // For the experiment to be immediately activated/triggered, its trigger event must be null.
  // Double check if payload's trigger event is empty string, it must be set to null to trigger.
  if (payload && payload.triggerEvent && payload.triggerEvent.length) {
    [experiment setValue:payload.triggerEvent forKey:kABTExperimentDictionaryTriggeredEventNameKey];
  } else {
    [experiment setValue:nil forKey:kABTExperimentDictionaryTriggeredEventNameKey];
  }

  // Set timeout event name and params.
  NSString *timeoutEventName = events.timeoutExperimentEventName;
  if (payload && payload.timeoutEventToLog && payload.timeoutEventToLog.length) {
    timeoutEventName = payload.timeoutEventToLog;
  }
  NSDictionary<NSString *, id> *timeoutEvent = [self eventDictionaryWithOrigin:origin
                                                                     eventName:timeoutEventName
                                                                        params:eventParams];
  [experiment setValue:timeoutEvent forKey:kABTExperimentDictionaryTimedOutEventKey];

  // Set trigger timeout information on how long to wait for trigger event.
  NSTimeInterval triggerTimeout = (double)(payload.triggerTimeoutMillis / ABT_MSEC_PER_SEC);
  [experiment setValue:@(triggerTimeout) forKey:kABTExperimentDictionaryTriggerTimeoutKey];

  // Set activate event name and params.
  NSString *activateEventName = events.activateExperimentEventName;
  if (payload && payload.activateEventToLog && payload.activateEventToLog.length) {
    activateEventName = payload.activateEventToLog;
  }
  NSDictionary<NSString *, id> *triggeredEvent = [self eventDictionaryWithOrigin:origin
                                                                       eventName:activateEventName
                                                                          params:eventParams];
  [experiment setValue:triggeredEvent forKey:kABTExperimentDictionaryTriggeredEventKey];

  // Set time to live information for how long the experiment lasts.
  NSTimeInterval timeToLive = (double)(payload.timeToLiveMillis / ABT_MSEC_PER_SEC);
  [experiment setValue:@(timeToLive) forKey:kABTExperimentDictionaryTimeToLiveKey];

  // Set expired event name and params.
  NSString *expiredEventName = events.expireExperimentEventName;
  if (payload && payload.ttlExpiryEventToLog && payload.ttlExpiryEventToLog.length) {
    expiredEventName = payload.ttlExpiryEventToLog;
  }
  NSDictionary<NSString *, id> *expiredEvent = [self eventDictionaryWithOrigin:origin
                                                                     eventName:expiredEventName
                                                                        params:eventParams];
  [experiment setValue:expiredEvent forKey:kABTExperimentDictionaryExpiredEventKey];
  return experiment;
}

- (NSDictionary<NSString *, id> *)
    eventDictionaryWithOrigin:(nonnull NSString *)origin
                    eventName:(nonnull NSString *)eventName
                       params:(nonnull NSDictionary<NSString *, NSString *> *)params {
  return @{
    kABTEventDictionaryOriginKey : origin,
    kABTEventDictionaryNameKey : eventName,
    kABTEventDictionaryTimestampKey : @([NSDate date].timeIntervalSince1970),
    kABTEventDictionaryParametersKey : params
  };
}

#pragma mark - experiment properties
- (NSString *)experimentIDOfExperiment:(id)experiment {
  if (!experiment) {
    return @"";
  }
  return [experiment valueForKey:kABTExperimentDictionaryExperimentIDKey];
}

- (NSString *)variantIDOfExperiment:(id)experiment {
  if (!experiment) {
    return @"";
  }
  return [experiment valueForKey:kABTExperimentDictionaryVariantIDKey];
}

- (NSInteger)maxNumberOfExperimentsOfOrigin:(NSString *)origin {
  if (!_analytics) {
    return 0;
  }
  return [_analytics maxUserProperties:origin];
}

#pragma mark - analytics internal methods

- (void)logEventWithOrigin:(NSString *)origin
                   payload:(ABTExperimentPayload *)payload
                    events:(FIRLifecycleEvents *)events {
  NSString *setExperimentEventName = events.setExperimentEventName;
  if (payload && payload.setEventToLog && payload.setEventToLog.length) {
    setExperimentEventName = payload.setEventToLog;
  }
  NSDictionary<NSString *, NSString *> *params;
  params = payload.experimentId ? @{payload.experimentId : payload.variantId} : @{};
  [_analytics logEventWithOrigin:origin name:setExperimentEventName parameters:params];
}

#pragma mark - helper

- (BOOL)isExperiment:(id)experiment theSameAsPayload:(ABTExperimentPayload *)payload {
  NSString *experimentID = [self experimentIDOfExperiment:experiment];
  NSString *variantID = [self variantIDOfExperiment:experiment];
  return [experimentID isEqualToString:payload.experimentId] &&
         [variantID isEqualToString:payload.variantId];
}

- (ABTExperimentPayload_ExperimentOverflowPolicy)
    overflowPolicyWithPayload:(ABTExperimentPayload *)payload
               originalPolicy:(ABTExperimentPayload_ExperimentOverflowPolicy)originalPolicy {
  if (payload.overflowPolicy != ABTExperimentPayload_ExperimentOverflowPolicy_PolicyUnspecified) {
    return payload.overflowPolicy;
  }
  if (originalPolicy != ABTExperimentPayload_ExperimentOverflowPolicy_PolicyUnspecified &&
      ABTExperimentPayload_ExperimentOverflowPolicy_IsValidValue(originalPolicy)) {
    return originalPolicy;
  }
  return ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest;
}

@end
