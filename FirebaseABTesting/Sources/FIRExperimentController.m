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

#import "FirebaseABTesting/Sources/Public/FirebaseABTesting/FIRExperimentController.h"

#import "FirebaseABTesting/Sources/ABTConditionalUserPropertyController.h"
#import "FirebaseABTesting/Sources/ABTConstants.h"
#import "FirebaseABTesting/Sources/Private/ABTExperimentPayload.h"
#import "FirebaseABTesting/Sources/Public/FirebaseABTesting/FIRLifecycleEvents.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

/// Logger Service String.
FIRLoggerService kFIRLoggerABTesting = @"[Firebase/ABTesting]";

/// Default experiment overflow policy.
const ABTExperimentPayloadExperimentOverflowPolicy FIRDefaultExperimentOverflowPolicy =
    ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest;

/// Deserialize the experiment payloads.
ABTExperimentPayload *ABTDeserializeExperimentPayload(NSData *payload) {
  // Verify that we have a JSON object.
  NSError *error;
  id JSONObject = [NSJSONSerialization JSONObjectWithData:payload options:kNilOptions error:&error];
  if (JSONObject == nil) {
    FIRLogError(kFIRLoggerABTesting, @"I-ABT000001", @"Failed to parse experiment payload: %@",
                error.debugDescription);
  }
  return [ABTExperimentPayload parseFromData:payload];
}

/// Returns a list of experiments to be set given the payloads and current list of experiments from
/// Firebase Analytics. If an experiment is in payloads but not in experiments, it should be set to
/// Firebase Analytics.
NSArray<ABTExperimentPayload *> *ABTExperimentsToSetFromPayloads(
    NSArray<NSData *> *payloads,
    NSArray<NSDictionary<NSString *, NSString *> *> *experiments,
    id<FIRAnalyticsInterop> _Nullable analytics) {
  NSArray<NSData *> *payloadsCopy = [payloads copy];
  NSArray *experimentsCopy = [experiments copy];
  NSMutableArray *experimentsToSet = [[NSMutableArray alloc] init];
  ABTConditionalUserPropertyController *controller =
      [ABTConditionalUserPropertyController sharedInstanceWithAnalytics:analytics];

  // Check if the experiment is in payloads but not in experiments.
  for (NSData *payload in payloadsCopy) {
    ABTExperimentPayload *experimentPayload = ABTDeserializeExperimentPayload(payload);
    if (!experimentPayload) {
      FIRLogInfo(kFIRLoggerABTesting, @"I-ABT000002",
                 @"Either payload is not set or it cannot be deserialized.");
      continue;
    }

    BOOL isExperimentSet = NO;
    for (id experiment in experimentsCopy) {
      if ([controller isExperiment:experiment theSameAsPayload:experimentPayload]) {
        isExperimentSet = YES;
        break;
      }
    }

    if (!isExperimentSet) {
      [experimentsToSet addObject:experimentPayload];
    }
  }
  return [experimentsToSet copy];
}

/// Returns a list of experiments to be cleared given the payloads and current list of
/// experiments from Firebase Analytics. If an experiment is in experiments but not in payloads, it
/// should be cleared in Firebase Analytics.
NSArray *ABTExperimentsToClearFromPayloads(
    NSArray<NSData *> *payloads,
    NSArray<NSDictionary<NSString *, NSString *> *> *experiments,
    id<FIRAnalyticsInterop> _Nullable analytics) {
  NSMutableArray *experimentsToClear = [[NSMutableArray alloc] init];
  ABTConditionalUserPropertyController *controller =
      [ABTConditionalUserPropertyController sharedInstanceWithAnalytics:analytics];

  // Check if the experiment is in experiments but not payloads.
  for (id experiment in experiments) {
    BOOL doesExperimentNoLongerExist = YES;
    for (NSData *payload in payloads) {
      ABTExperimentPayload *experimentPayload = ABTDeserializeExperimentPayload(payload);
      if (!experimentPayload) {
        FIRLogInfo(kFIRLoggerABTesting, @"I-ABT000002",
                   @"Either payload is not set or it cannot be deserialized.");
        continue;
      }

      if ([controller isExperiment:experiment theSameAsPayload:experimentPayload]) {
        doesExperimentNoLongerExist = NO;
      }
    }
    if (doesExperimentNoLongerExist) {
      [experimentsToClear addObject:experiment];
    }
  }
  return experimentsToClear;
}

// ABT doesn't provide any functionality to other components,
// so it provides a private, empty protocol that it conforms to and use it for registration.

@protocol FIRABTInstanceProvider
@end

@interface FIRExperimentController () <FIRABTInstanceProvider, FIRLibrary>
@property(nonatomic, readwrite, strong) id<FIRAnalyticsInterop> _Nullable analytics;
@end

@implementation FIRExperimentController

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self withName:@"fire-abt"];
}

+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRDependency *analyticsDep = [FIRDependency dependencyWithProtocol:@protocol(FIRAnalyticsInterop)
                                                           isRequired:NO];
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    // Ensure it's cached so it returns the same instance every time ABTesting is called.
    *isCacheable = YES;
    id<FIRAnalyticsInterop> analytics = FIR_COMPONENT(FIRAnalyticsInterop, container);
    return [[FIRExperimentController alloc] initWithAnalytics:analytics];
  };
  FIRComponent *abtProvider = [FIRComponent componentWithProtocol:@protocol(FIRABTInstanceProvider)
                                              instantiationTiming:FIRInstantiationTimingLazy
                                                     dependencies:@[ analyticsDep ]
                                                    creationBlock:creationBlock];

  return @[ abtProvider ];
}

- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics {
  self = [super init];
  if (self != nil) {
    _analytics = analytics;
  }
  return self;
}

+ (FIRExperimentController *)sharedInstance {
  FIRApp *defaultApp = [FIRApp defaultApp];  // Missing configure will be logged here.
  id<FIRABTInstanceProvider> instance = FIR_COMPONENT(FIRABTInstanceProvider, defaultApp.container);

  // We know the instance coming from the container is a FIRExperimentController instance, cast it.
  return (FIRExperimentController *)instance;
}

- (void)updateExperimentsWithServiceOrigin:(NSString *)origin
                                    events:(FIRLifecycleEvents *)events
                                    policy:(ABTExperimentPayloadExperimentOverflowPolicy)policy
                             lastStartTime:(NSTimeInterval)lastStartTime
                                  payloads:(NSArray<NSData *> *)payloads
                         completionHandler:
                             (nullable void (^)(NSError *_Nullable error))completionHandler {
  FIRExperimentController *__weak weakSelf = self;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
    FIRExperimentController *strongSelf = weakSelf;
    [strongSelf updateExperimentConditionalUserPropertiesWithServiceOrigin:origin
                                                                    events:events
                                                                    policy:policy
                                                             lastStartTime:lastStartTime
                                                                  payloads:payloads
                                                         completionHandler:completionHandler];
  });
}

- (void)
    updateExperimentConditionalUserPropertiesWithServiceOrigin:(NSString *)origin
                                                        events:(FIRLifecycleEvents *)events
                                                        policy:
                                                            (ABTExperimentPayloadExperimentOverflowPolicy)
                                                                policy
                                                 lastStartTime:(NSTimeInterval)lastStartTime
                                                      payloads:(NSArray<NSData *> *)payloads
                                             completionHandler:
                                                 (nullable void (^)(NSError *_Nullable error))
                                                     completionHandler {
  ABTConditionalUserPropertyController *controller =
      [ABTConditionalUserPropertyController sharedInstanceWithAnalytics:_analytics];

  // Get the list of expriments from Firebase Analytics.
  NSArray *experiments = [controller experimentsWithOrigin:origin];
  if (!experiments) {
    NSString *errorDescription =
        @"Failed to get conditional user properties from Firebase Analytics.";
    FIRLogInfo(kFIRLoggerABTesting, @"I-ABT000003", @"%@", errorDescription);

    if (completionHandler) {
      completionHandler([NSError
          errorWithDomain:kABTErrorDomain
                     code:kABTInternalErrorFailedToFetchConditionalUserProperties
                 userInfo:@{NSLocalizedDescriptionKey : errorDescription}]);
    }

    return;
  }
  NSArray<ABTExperimentPayload *> *experimentsToSet =
      ABTExperimentsToSetFromPayloads(payloads, experiments, _analytics);
  NSArray<NSDictionary<NSString *, NSString *> *> *experimentsToClear =
      ABTExperimentsToClearFromPayloads(payloads, experiments, _analytics);

  for (id experiment in experimentsToClear) {
    NSString *experimentID = [controller experimentIDOfExperiment:experiment];
    NSString *variantID = [controller variantIDOfExperiment:experiment];
    [controller clearExperiment:experimentID
                      variantID:variantID
                     withOrigin:origin
                        payload:nil
                         events:events];
  }

  for (ABTExperimentPayload *experimentPayload in experimentsToSet) {
    if (experimentPayload.experimentStartTimeMillis > lastStartTime * ABT_MSEC_PER_SEC) {
      [controller setExperimentWithOrigin:origin
                                  payload:experimentPayload
                                   events:events
                                   policy:policy];
      FIRLogInfo(kFIRLoggerABTesting, @"I-ABT000008",
                 @"Set Experiment ID %@, variant ID %@ to Firebase Analytics.",
                 experimentPayload.experimentId, experimentPayload.variantId);

    } else {
      FIRLogInfo(kFIRLoggerABTesting, @"I-ABT000009",
                 @"Not setting experiment ID %@, variant ID %@ due to the last update time %lld.",
                 experimentPayload.experimentId, experimentPayload.variantId,
                 (long)lastStartTime * ABT_MSEC_PER_SEC);
    }
  }

  if (completionHandler) {
    completionHandler(nil);
  }
}

- (NSTimeInterval)latestExperimentStartTimestampBetweenTimestamp:(NSTimeInterval)timestamp
                                                     andPayloads:(NSArray<NSData *> *)payloads {
  for (NSData *payload in [payloads copy]) {
    ABTExperimentPayload *experimentPayload = ABTDeserializeExperimentPayload(payload);
    if (!experimentPayload) {
      FIRLogInfo(kFIRLoggerABTesting, @"I-ABT000002",
                 @"Either payload is not set or it cannot be deserialized.");
      continue;
    }
    if (experimentPayload.experimentStartTimeMillis > timestamp * ABT_MSEC_PER_SEC) {
      timestamp = (double)(experimentPayload.experimentStartTimeMillis / ABT_MSEC_PER_SEC);
    }
  }
  return timestamp;
}

- (void)validateRunningExperimentsForServiceOrigin:(NSString *)origin
                         runningExperimentPayloads:(NSArray<ABTExperimentPayload *> *)payloads {
  ABTConditionalUserPropertyController *controller =
      [ABTConditionalUserPropertyController sharedInstanceWithAnalytics:_analytics];

  FIRLifecycleEvents *lifecycleEvents = [[FIRLifecycleEvents alloc] init];

  // Get the list of experiments from Firebase Analytics.
  NSArray<NSDictionary<NSString *, NSString *> *> *activeExperiments =
      [controller experimentsWithOrigin:origin];

  NSMutableSet *runningExperimentIDs = [NSMutableSet setWithCapacity:payloads.count];
  for (ABTExperimentPayload *payload in payloads) {
    [runningExperimentIDs addObject:payload.experimentId];
  }

  for (NSDictionary<NSString *, NSString *> *activeExperimentDictionary in activeExperiments) {
    NSString *experimentID = activeExperimentDictionary[@"name"];
    if (![runningExperimentIDs containsObject:experimentID]) {
      NSString *variantID = activeExperimentDictionary[@"value"];

      [controller clearExperiment:experimentID
                        variantID:variantID
                       withOrigin:origin
                          payload:nil
                           events:lifecycleEvents];
    }
  }
}

- (void)activateExperiment:(ABTExperimentPayload *)experimentPayload
          forServiceOrigin:(NSString *)origin {
  ABTConditionalUserPropertyController *controller =
      [ABTConditionalUserPropertyController sharedInstanceWithAnalytics:_analytics];

  FIRLifecycleEvents *lifecycleEvents = [[FIRLifecycleEvents alloc] init];

  // Ensure that trigger event is nil, which will immediately set the experiment to active.
  [experimentPayload clearTriggerEvent];

  [controller setExperimentWithOrigin:origin
                              payload:experimentPayload
                               events:lifecycleEvents
                               policy:experimentPayload.overflowPolicy];
}

@end
