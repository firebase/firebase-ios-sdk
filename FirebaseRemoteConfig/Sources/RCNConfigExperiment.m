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

#import <os/lock.h>

#import "FirebaseABTesting/Sources/Private/FirebaseABTestingInternal.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDefines.h"

static NSString *const kExperimentMetadataKeyLastStartTime = @"last_experiment_start_time";

static NSString *const kServiceOrigin = @"frc";
static NSString *const kMethodNameLatestStartTime =
    @"latestExperimentStartTimestampBetweenTimestamp:andPayloads:";

@interface RCNConfigExperiment () {
  // Guards the immutable state snapshots and all generation counters below. No external work is
  // performed while this lock is held.
  os_unfair_lock _stateLock;
  NSArray<NSData *> *_experimentPayloads;
  NSDictionary<NSString *, id> *_experimentMetadata;
  NSArray<NSData *> *_activeExperimentPayloads;
  // The aggregate generation keeps payload and metadata calculations coherent. Per-field
  // generations prevent an older database load from replacing a field updated after it began.
  NSUInteger _stateGeneration;
  NSUInteger _experimentPayloadGeneration;
  NSUInteger _experimentMetadataGeneration;
  NSUInteger _activeExperimentPayloadGeneration;
}
@property(nonatomic, copy) NSArray<NSData *> *experimentPayloads;  ///< Experiment payloads.
@property(nonatomic, copy)
    NSDictionary<NSString *, id> *experimentMetadata;  ///< Experiment metadata
@property(nonatomic, copy)
    NSArray<NSData *> *activeExperimentPayloads;             ///< Activated experiment payloads.
@property(nonatomic, strong) RCNConfigDBManager *DBManager;  ///< Database Manager.
@property(nonatomic, strong) FIRExperimentController *experimentController;
@property(nonatomic, strong) NSDateFormatter *experimentStartTimeDateFormatter;
/// Updates metadata from a coherent state snapshot and optionally activates its fetched payloads.
/// Retries if state changes while the experiment controller calculates the latest start time.
- (nullable NSData *)updateExperimentMetadataAndActivate:(BOOL)activate
                                           lastStartTime:(nullable NSTimeInterval *)lastStartTime
                                                payloads:(NSArray<NSData *> *_Nullable *_Nullable)
                                                             payloads;
/// Returns the payloads that contain valid JSON, logging and omitting invalid entries.
- (NSArray<NSData *> *)validExperimentPayloads:(NSArray<NSData *> *)payloads
                                     logPrefix:(NSString *)logPrefix;
/// Serializes experiment metadata for persistence.
- (nullable NSData *)serializedExperimentMetadata:
    (NSDictionary<NSString *, id> *)experimentMetadata;
@end

@implementation RCNConfigExperiment

- (NSArray<NSData *> *)experimentPayloads {
  os_unfair_lock_lock(&_stateLock);
  NSArray<NSData *> *experimentPayloads = _experimentPayloads;
  os_unfair_lock_unlock(&_stateLock);
  return experimentPayloads;
}

- (void)setExperimentPayloads:(NSArray<NSData *> *)experimentPayloads {
  NSArray<NSData *> *payloadSnapshot = [experimentPayloads copy] ?: @[];
  os_unfair_lock_lock(&_stateLock);
  _experimentPayloads = payloadSnapshot;
  _experimentPayloadGeneration += 1;
  _stateGeneration += 1;
  os_unfair_lock_unlock(&_stateLock);
}

- (NSDictionary<NSString *, id> *)experimentMetadata {
  os_unfair_lock_lock(&_stateLock);
  NSDictionary<NSString *, id> *experimentMetadata = _experimentMetadata;
  os_unfair_lock_unlock(&_stateLock);
  return experimentMetadata;
}

- (void)setExperimentMetadata:(NSDictionary<NSString *, id> *)experimentMetadata {
  NSDictionary<NSString *, id> *metadataSnapshot = [experimentMetadata copy] ?: @{};
  os_unfair_lock_lock(&_stateLock);
  _experimentMetadata = metadataSnapshot;
  _experimentMetadataGeneration += 1;
  _stateGeneration += 1;
  os_unfair_lock_unlock(&_stateLock);
}

- (NSArray<NSData *> *)activeExperimentPayloads {
  os_unfair_lock_lock(&_stateLock);
  NSArray<NSData *> *activeExperimentPayloads = _activeExperimentPayloads;
  os_unfair_lock_unlock(&_stateLock);
  return activeExperimentPayloads;
}

- (void)setActiveExperimentPayloads:(NSArray<NSData *> *)activeExperimentPayloads {
  NSArray<NSData *> *payloadSnapshot = [activeExperimentPayloads copy] ?: @[];
  os_unfair_lock_lock(&_stateLock);
  _activeExperimentPayloads = payloadSnapshot;
  _activeExperimentPayloadGeneration += 1;
  _stateGeneration += 1;
  os_unfair_lock_unlock(&_stateLock);
}

/// Designated initializer
- (instancetype)initWithDBManager:(RCNConfigDBManager *)DBManager
             experimentController:(FIRExperimentController *)controller {
  self = [super init];
  if (self) {
    _stateLock = OS_UNFAIR_LOCK_INIT;
    _experimentPayloads = @[];
    _experimentMetadata = @{};
    _activeExperimentPayloads = @[];
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

  os_unfair_lock_lock(&_stateLock);
  NSUInteger experimentPayloadGeneration = _experimentPayloadGeneration;
  NSUInteger experimentMetadataGeneration = _experimentMetadataGeneration;
  NSUInteger activeExperimentPayloadGeneration = _activeExperimentPayloadGeneration;
  os_unfair_lock_unlock(&_stateLock);

  __weak RCNConfigExperiment *weakSelf = self;
  [_DBManager loadExperimentWithCompletionHandler:^(BOOL success, NSDictionary *result) {
    RCNConfigExperiment *strongSelf = weakSelf;
    if (!strongSelf || !success) {
      return;
    }

    NSArray<NSData *> *experimentPayloads = nil;
    if (result[@RCNExperimentTableKeyPayload]) {
      experimentPayloads = [strongSelf validExperimentPayloads:result[@RCNExperimentTableKeyPayload]
                                                     logPrefix:@"Experiment"];
    }
    NSDictionary<NSString *, id> *experimentMetadata =
        [result[@RCNExperimentTableKeyMetadata] copy];
    NSArray<NSData *> *activeExperimentPayloads = nil;
    if (result[@RCNExperimentTableKeyActivePayload]) {
      activeExperimentPayloads =
          [strongSelf validExperimentPayloads:result[@RCNExperimentTableKeyActivePayload]
                                    logPrefix:@"Activated experiment"];
    }

    os_unfair_lock_lock(&strongSelf->_stateLock);
    BOOL didUpdateState = NO;
    if (experimentPayloads &&
        strongSelf->_experimentPayloadGeneration == experimentPayloadGeneration) {
      strongSelf->_experimentPayloads = experimentPayloads;
      strongSelf->_experimentPayloadGeneration += 1;
      didUpdateState = YES;
    }
    if (experimentMetadata &&
        strongSelf->_experimentMetadataGeneration == experimentMetadataGeneration) {
      strongSelf->_experimentMetadata = experimentMetadata;
      strongSelf->_experimentMetadataGeneration += 1;
      didUpdateState = YES;
    }
    if (activeExperimentPayloads &&
        strongSelf->_activeExperimentPayloadGeneration == activeExperimentPayloadGeneration) {
      strongSelf->_activeExperimentPayloads = activeExperimentPayloads;
      strongSelf->_activeExperimentPayloadGeneration += 1;
      didUpdateState = YES;
    }
    if (didUpdateState) {
      strongSelf->_stateGeneration += 1;
    }
    os_unfair_lock_unlock(&strongSelf->_stateLock);
  }];
}

- (void)updateExperimentsWithResponse:(NSArray<NSDictionary<NSString *, id> *> *)response {
  NSMutableArray<NSData *> *experimentPayloads = [[NSMutableArray alloc] init];
  for (NSDictionary<NSString *, id> *experiment in response) {
    NSError *error = nil;
    NSData *jsonPayload = [NSJSONSerialization dataWithJSONObject:experiment
                                                          options:kNilOptions
                                                            error:&error];
    if (!jsonPayload || error) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000030",
                  @"Invalid experiment payload to be serialized.");
    } else {
      [experimentPayloads addObject:jsonPayload];
    }
  }

  NSArray<NSData *> *payloadSnapshot = [experimentPayloads copy];
  os_unfair_lock_lock(&_stateLock);
  _experimentPayloads = payloadSnapshot;
  _experimentPayloadGeneration += 1;
  _stateGeneration += 1;
  os_unfair_lock_unlock(&_stateLock);

  [_DBManager replaceExperimentTableWithKey:@RCNExperimentTableKeyPayload
                                     values:payloadSnapshot
                          completionHandler:nil];
}

- (void)updateExperimentsWithHandler:(void (^)(NSError *_Nullable))handler {
  FIRLifecycleEvents *lifecycleEvent = [[FIRLifecycleEvents alloc] init];
  NSTimeInterval lastStartTime = 0;
  NSArray<NSData *> *experimentPayloads = nil;
  NSData *serializedExperimentMetadata =
      [self updateExperimentMetadataAndActivate:YES
                                  lastStartTime:&lastStartTime
                                       payloads:&experimentPayloads];

  FIRExperimentController *experimentController = self.experimentController;
  void (^updateAnalyticsExperiments)(void) = ^{
    if (experimentController) {
      [experimentController
          updateExperimentsWithServiceOrigin:kServiceOrigin
                                      events:lifecycleEvent
                                      policy:
                                          ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest
                               lastStartTime:lastStartTime
                                    payloads:experimentPayloads
                           completionHandler:handler];
    } else if (handler) {
      handler(nil);
    }
  };

  if (!_DBManager) {
    updateAnalyticsExperiments();
    return;
  }

  if (serializedExperimentMetadata) {
    [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyMetadata
                                       value:serializedExperimentMetadata
                           completionHandler:nil];
  }
  [_DBManager replaceExperimentTableWithKey:@RCNExperimentTableKeyActivePayload
                                     values:experimentPayloads
                          completionHandler:^(BOOL success, NSDictionary *result) {
                            updateAnalyticsExperiments();
                          }];
}

- (void)updateExperimentStartTime {
  NSData *serializedExperimentMetadata = [self updateExperimentMetadataAndActivate:NO
                                                                     lastStartTime:NULL
                                                                          payloads:NULL];
  if (serializedExperimentMetadata) {
    [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyMetadata
                                       value:serializedExperimentMetadata
                           completionHandler:nil];
  }
}

- (nullable NSData *)updateExperimentMetadataAndActivate:(BOOL)activate
                                           lastStartTime:(nullable NSTimeInterval *)lastStartTime
                                                payloads:(NSArray<NSData *> *_Nullable *_Nullable)
                                                             payloads {
  FIRExperimentController *experimentController = self.experimentController;
  while (YES) {
    os_unfair_lock_lock(&_stateLock);
    NSUInteger stateGeneration = _stateGeneration;
    NSArray<NSData *> *payloadSnapshot = _experimentPayloads;
    NSDictionary<NSString *, id> *metadataSnapshot = _experimentMetadata;
    os_unfair_lock_unlock(&_stateLock);

    NSTimeInterval existingLastStartTime =
        [metadataSnapshot[kExperimentMetadataKeyLastStartTime] doubleValue];
    NSTimeInterval latestStartTime =
        experimentController
            ? [experimentController
                  latestExperimentStartTimestampBetweenTimestamp:existingLastStartTime
                                                     andPayloads:payloadSnapshot]
            : existingLastStartTime;
    NSMutableDictionary<NSString *, id> *updatedMetadata = [metadataSnapshot mutableCopy];
    updatedMetadata[kExperimentMetadataKeyLastStartTime] = @(latestStartTime);
    NSData *serializedMetadata = [self serializedExperimentMetadata:updatedMetadata];

    os_unfair_lock_lock(&_stateLock);
    if (_stateGeneration != stateGeneration) {
      os_unfair_lock_unlock(&_stateLock);
      continue;
    }
    _experimentMetadata = [updatedMetadata copy];
    _experimentMetadataGeneration += 1;
    if (activate) {
      _activeExperimentPayloads = payloadSnapshot;
      _activeExperimentPayloadGeneration += 1;
    }
    _stateGeneration += 1;
    os_unfair_lock_unlock(&_stateLock);

    if (lastStartTime) {
      *lastStartTime = existingLastStartTime;
    }
    if (payloads) {
      *payloads = payloadSnapshot;
    }
    return serializedMetadata;
  }
}

- (NSArray<NSData *> *)validExperimentPayloads:(NSArray<NSData *> *)payloads
                                     logPrefix:(NSString *)logPrefix {
  NSMutableArray<NSData *> *validPayloads = [[NSMutableArray alloc] init];
  for (NSData *experiment in payloads) {
    NSError *error = nil;
    id experimentPayloadJSON = [NSJSONSerialization JSONObjectWithData:experiment
                                                               options:kNilOptions
                                                                 error:&error];
    if (!experimentPayloadJSON || error) {
      FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000031",
                    @"%@ payload could not be parsed as JSON.", logPrefix);
    } else {
      [validPayloads addObject:experiment];
    }
  }
  return [validPayloads copy];
}

- (nullable NSData *)serializedExperimentMetadata:
    (NSDictionary<NSString *, id> *)experimentMetadata {
  if (![NSJSONSerialization isValidJSONObject:experimentMetadata]) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000028",
                @"Invalid fetched experiment metadata to be serialized.");
    return nil;
  }

  NSError *error = nil;
  NSData *serializedExperimentMetadata =
      [NSJSONSerialization dataWithJSONObject:experimentMetadata
                                      options:NSJSONWritingPrettyPrinted
                                        error:&error];
  if (!serializedExperimentMetadata || error) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000028",
                @"Fetched experiment metadata could not be serialized.");
  }
  return serializedExperimentMetadata;
}
@end
