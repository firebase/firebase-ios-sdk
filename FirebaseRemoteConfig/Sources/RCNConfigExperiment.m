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

#import "FirebaseABTesting/Sources/Private/FirebaseABTestingInternal.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDefines.h"

static NSString *const kExperimentMetadataKeyLastStartTime = @"last_experiment_start_time";

static NSString *const kServiceOrigin = @"frc";
static NSString *const kMethodNameLatestStartTime =
    @"latestExperimentStartTimestampBetweenTimestamp:andPayloads:";

@interface RCNConfigExperiment ()
@property(nonatomic, strong)
    NSMutableArray<NSData *> *experimentPayloads;  ///< Experiment payloads.
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, id> *experimentMetadata;  ///< Experiment metadata
@property(nonatomic, strong)
    NSMutableArray<NSData *> *activeExperimentPayloads;      ///< Activated experiment payloads.
@property(nonatomic, strong) RCNConfigDBManager *DBManager;  ///< Database Manager.
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
    _activeExperimentPayloads = [[NSMutableArray alloc] init];
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
        NSError *error;
        id experimentPayloadJSON = [NSJSONSerialization JSONObjectWithData:experiment
                                                                   options:kNilOptions
                                                                     error:&error];
        if (!experimentPayloadJSON || error) {
          FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000031",
                        @"Experiment payload could not be parsed as JSON.");
        } else {
          [strongSelf->_experimentPayloads addObject:experiment];
        }
      }
    }
    if (result[@RCNExperimentTableKeyMetadata]) {
      strongSelf->_experimentMetadata = [result[@RCNExperimentTableKeyMetadata] mutableCopy];
    }

    /// Load activated experiments payload and metadata.
    if (result[@RCNExperimentTableKeyActivePayload]) {
      [strongSelf->_activeExperimentPayloads removeAllObjects];
      for (NSData *experiment in result[@RCNExperimentTableKeyActivePayload]) {
        NSError *error;
        id experimentPayloadJSON = [NSJSONSerialization JSONObjectWithData:experiment
                                                                   options:kNilOptions
                                                                     error:&error];
        if (!experimentPayloadJSON || error) {
          FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000031",
                        @"Activated experiment payload could not be parsed as JSON.");
        } else {
          [strongSelf->_activeExperimentPayloads addObject:experiment];
        }
      }
    }
  };
  [_DBManager loadExperimentWithCompletionHandler:completionHandler];
}

- (void)updateExperimentsWithResponse:(NSArray<NSDictionary<NSString *, id> *> *)response {
  // cache fetched experiment payloads.
  [_experimentPayloads removeAllObjects];
  [_DBManager deleteExperimentTableForKey:@RCNExperimentTableKeyPayload];

  for (NSDictionary<NSString *, id> *experiment in response) {
    NSError *error;
    NSData *JSONPayload = [NSJSONSerialization dataWithJSONObject:experiment
                                                          options:kNilOptions
                                                            error:&error];
    if (!JSONPayload || error) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000030",
                  @"Invalid experiment payload to be serialized.");
    } else {
      [_experimentPayloads addObject:JSONPayload];
      [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyPayload
                                         value:JSONPayload
                             completionHandler:nil];
    }
  }
}

- (void)updateExperimentsWithHandler:(void (^)(NSError *_Nullable))handler {
  FIRLifecycleEvents *lifecycleEvent = [[FIRLifecycleEvents alloc] init];

  // Get the last experiment start time prior to the latest payload.
  NSTimeInterval lastStartTime =
      [_experimentMetadata[kExperimentMetadataKeyLastStartTime] doubleValue];

  // Update the last experiment start time with the latest payload.
  [self updateExperimentStartTime];
  [self.experimentController
      updateExperimentsWithServiceOrigin:kServiceOrigin
                                  events:lifecycleEvent
                                  policy:ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest
                           lastStartTime:lastStartTime
                                payloads:_experimentPayloads
                       completionHandler:handler];

  /// Update activated experiments payload and metadata in DB.
  [self updateActiveExperimentsInDB];
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

- (void)updateActiveExperimentsInDB {
  /// Put current fetched experiment payloads into activated experiment DB.
  [_activeExperimentPayloads removeAllObjects];
  [_DBManager deleteExperimentTableForKey:@RCNExperimentTableKeyActivePayload];
  for (NSData *experiment in _experimentPayloads) {
    [_activeExperimentPayloads addObject:experiment];
    [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyActivePayload
                                       value:experiment
                           completionHandler:nil];
  }
}

- (NSTimeInterval)latestStartTimeWithExistingLastStartTime:(NSTimeInterval)existingLastStartTime {
  return [self.experimentController
      latestExperimentStartTimestampBetweenTimestamp:existingLastStartTime
                                         andPayloads:_experimentPayloads];
}
@end
