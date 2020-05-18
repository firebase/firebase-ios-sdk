/*
 * Copyright 2019 Google
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

#import "FirebaseRemoteConfig/Sources/RCNConfigExperiment.h"

#import <FirebaseABTesting/ExperimentPayload.pbobjc.h>
#import <FirebaseABTesting/FIRExperimentController.h>
#import <FirebaseABTesting/FIRLifecycleEvents.h>
#import <FirebaseCore/FIRLogger.h>
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDefines.h"

static NSString *const kExperimentMetadataKeyLastStartTime = @"last_experiment_start_time";
/// Based on proto:
/// http://google3/googlemac/iPhone/Firebase/ABTesting/Source/Protos/developers/mobile/abt/proto/ExperimentPayload.pbobjc.m
static NSString *const kExperimentPayloadKeyExperimentID = @"experimentId";
static NSString *const kExperimentPayloadKeyVariantID = @"variantId";
static NSString *const kExperimentPayloadKeyExperimentStartTime = @"experimentStartTime";
static NSString *const kExperimentPayloadKeyTriggerEvent = @"triggerEvent";
static NSString *const kExperimentPayloadKeyTriggerTimeoutMillis = @"triggerTimeoutMillis";
static NSString *const kExperimentPayloadKeyTimeToLiveMillis = @"timeToLiveMillis";
static NSString *const kExperimentPayloadKeySetEventToLog = @"setEventToLog";
static NSString *const kExperimentPayloadKeyActivateEventToLog = @"activateEventToLog";
static NSString *const kExperimentPayloadKeyClearEventToLog = @"clearEventToLog";
static NSString *const kExperimentPayloadKeyTimeoutEventToLog = @"timeoutEventToLog";
static NSString *const kExperimentPayloadKeyTTLExpiryEventToLog = @"ttlExpiryEventToLog";
static NSString *const kExperimentPayloadKeyOverflowPolicy = @"overflowPolicy";

static NSString *const kServiceOrigin = @"frc";
static NSString *const kMethodNameLatestStartTime =
    @"latestExperimentStartTimestampBetweenTimestamp:andPayloads:";

@interface RCNConfigExperiment ()
@property(nonatomic, strong)
    NSMutableArray<NSData *> *experimentPayloads;  ///< Experiment payloads.
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, id> *experimentMetadata;  ///< Experiment metadata
@property(nonatomic, strong) RCNConfigDBManager *DBManager;   ///< Database Manager.
@property(nonatomic, strong) FIRExperimentController *experimentController;
@property(nonatomic, strong) NSDateFormatter *experimentStartTimeDateFormatter;
@end

@implementation RCNConfigExperiment
/// Designated initializer
- (instancetype)initWithDBManager:(RCNConfigDBManager *)DBManager
             experimentController:(FIRExperimentController *)controller {
  self = [super init];
  if (self) {
    _experimentPayloads = [[NSMutableArray alloc] init];
    _experimentMetadata = [[NSMutableDictionary alloc] init];
    _experimentStartTimeDateFormatter = [[NSDateFormatter alloc] init];
    [_experimentStartTimeDateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [_experimentStartTimeDateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    // Locale needs to be hardcoded. See
    // https://developer.apple.com/library/ios/#qa/qa1480/_index.html for more details.
    [_experimentStartTimeDateFormatter
        setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [_experimentStartTimeDateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];

    _DBManager = DBManager;
    _experimentController = controller;
    [self loadExperimentFromTable];
  }
  return self;
}

- (void)loadExperimentFromTable {
  if (!_DBManager) {
    return;
  }
  __weak RCNConfigExperiment *weakSelf = self;
  RCNDBCompletion completionHandler = ^(BOOL success, NSDictionary<NSString *, id> *result) {
    RCNConfigExperiment *strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }
    if (result[@RCNExperimentTableKeyPayload]) {
      [strongSelf->_experimentPayloads removeAllObjects];
      for (NSData *experiment in result[@RCNExperimentTableKeyPayload]) {
        // Try to parse the experimentpayload as JSON.
        NSError *error;
        id experimentPayloadJSON = [NSJSONSerialization JSONObjectWithData:experiment
                                                                   options:kNilOptions
                                                                     error:&error];
        if (!experimentPayloadJSON || error) {
          FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000031",
                        @"Experiment payload could not be parsed as JSON.");
          // Add this as serialized proto.
          [strongSelf->_experimentPayloads addObject:experiment];
        } else {
          // Convert to protobuf.
          NSData *protoPayload = [self convertABTExperimentPayloadToProto:experimentPayloadJSON];
          [strongSelf->_experimentPayloads addObject:protoPayload];
        }
      }
    }
    if (result[@RCNExperimentTableKeyMetadata]) {
      strongSelf->_experimentMetadata = [result[@RCNExperimentTableKeyMetadata] mutableCopy];
    }
  };
  [_DBManager loadExperimentWithCompletionHandler:completionHandler];
}

/// This method converts the ABT experiment payload to a serialized protobuf which is consumable by
/// the ABT SDK.
- (NSData *)convertABTExperimentPayloadToProto:(NSDictionary<NSString *, id> *)experimentPayload {
  ABTExperimentPayload *ABTExperiment = [[ABTExperimentPayload alloc] init];
  ABTExperiment.experimentId = experimentPayload[kExperimentPayloadKeyExperimentID];
  ABTExperiment.variantId = experimentPayload[kExperimentPayloadKeyVariantID];
  NSDate *experimentStartTime = [self.experimentStartTimeDateFormatter
      dateFromString:experimentPayload[kExperimentPayloadKeyExperimentStartTime]];
  ABTExperiment.experimentStartTimeMillis =
      [@([experimentStartTime timeIntervalSince1970] * 1000) longLongValue];
  ABTExperiment.triggerEvent = experimentPayload[kExperimentPayloadKeyTriggerEvent];
  ABTExperiment.triggerTimeoutMillis =
      experimentPayload[kExperimentPayloadKeyTriggerTimeoutMillis]
          ? atoll([experimentPayload[kExperimentPayloadKeyTriggerTimeoutMillis] UTF8String])
          : 0;
  ABTExperiment.timeToLiveMillis =
      experimentPayload[kExperimentPayloadKeyTimeToLiveMillis]
          ? atoll([experimentPayload[kExperimentPayloadKeyTimeToLiveMillis] UTF8String])
          : 0;
  ABTExperiment.setEventToLog = experimentPayload[kExperimentPayloadKeySetEventToLog];
  ABTExperiment.activateEventToLog = experimentPayload[kExperimentPayloadKeyActivateEventToLog];
  ABTExperiment.clearEventToLog = experimentPayload[kExperimentPayloadKeyClearEventToLog];
  ABTExperiment.timeoutEventToLog = experimentPayload[kExperimentPayloadKeyTimeoutEventToLog];
  ABTExperiment.ttlExpiryEventToLog = experimentPayload[kExperimentPayloadKeyTTLExpiryEventToLog];
  ABTExperiment.overflowPolicy = [experimentPayload[kExperimentPayloadKeyOverflowPolicy] intValue];

  // Serialize the experiment payload.
  NSData *serializedABTExperiment = ABTExperiment.data;
  return serializedABTExperiment;
}

- (void)updateExperimentsWithResponse:(NSArray<NSDictionary<NSString *, id> *> *)response {
  // cache fetched experiment payloads.
  [_experimentPayloads removeAllObjects];
  [_DBManager deleteExperimentTableForKey:@RCNExperimentTableKeyPayload];

  for (NSDictionary<NSString *, id> *experiment in response) {
    NSData *protoPayload = [self convertABTExperimentPayloadToProto:experiment];
    [_experimentPayloads addObject:protoPayload];
    // We will add the new serialized JSON data to the database.
    // TODO: (b/129272809). Eventually, RC and ABT need to be migrated to move off protos once
    // (most) customers have migrated to using the new SDK (and hence saving the new JSON based
    // payload in the database).
    NSError *error;
    NSData *JSONPayload = [NSJSONSerialization dataWithJSONObject:experiment
                                                          options:kNilOptions
                                                            error:&error];
    if (!JSONPayload || error) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000030",
                  @"Invalid experiment payload to be serialized.");
    }

    [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyPayload
                                       value:JSONPayload
                           completionHandler:nil];
  }
}

- (void)updateExperiments {
  FIRLifecycleEvents *lifecycleEvent = [[FIRLifecycleEvents alloc] init];

  // Get the last experiment start time prior to the latest payload.
  NSTimeInterval lastStartTime =
      [_experimentMetadata[kExperimentMetadataKeyLastStartTime] doubleValue];

  // Update the last experiment start time with the latest payload.
  [self updateExperimentStartTime];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [self.experimentController
      updateExperimentsWithServiceOrigin:kServiceOrigin
                                  events:lifecycleEvent
                                  policy:ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest
                           lastStartTime:lastStartTime
                                payloads:_experimentPayloads];
#pragma clang diagnostic pop
}

- (void)updateExperimentStartTime {
  NSTimeInterval existingLastStartTime =
      [_experimentMetadata[kExperimentMetadataKeyLastStartTime] doubleValue];

  NSTimeInterval latestStartTime =
      [self latestStartTimeWithExistingLastStartTime:existingLastStartTime];

  _experimentMetadata[kExperimentMetadataKeyLastStartTime] = @(latestStartTime);

  if (![NSJSONSerialization isValidJSONObject:_experimentMetadata]) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000028",
                @"Invalid fetched experiment metadata to be serialized.");
    return;
  }
  NSError *error;
  NSData *serializedExperimentMetadata =
      [NSJSONSerialization dataWithJSONObject:_experimentMetadata
                                      options:NSJSONWritingPrettyPrinted
                                        error:&error];
  [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyMetadata
                                     value:serializedExperimentMetadata
                         completionHandler:nil];
}

- (NSTimeInterval)latestStartTimeWithExistingLastStartTime:(NSTimeInterval)existingLastStartTime {
  return [self.experimentController
      latestExperimentStartTimestampBetweenTimestamp:existingLastStartTime
                                         andPayloads:_experimentPayloads];
}
@end
