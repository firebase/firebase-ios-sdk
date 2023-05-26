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

static NSString *const kExperimentIdKey = @"experimentId";
static NSString *const kAffectedParameterKeys = @"affectedParameterKeys";

@interface RCNConfigExperiment ()
@property(nonatomic, strong)
    NSMutableArray<NSData *> *experimentPayloads;  ///< Experiment payloads.
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, id> *experimentMetadata;  ///< Experiment metadata
@property(nonatomic, strong)
    NSMutableArray<NSData *> *activeExperimentPayloads;   ///< Activated experiment payloads.
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

- (NSMutableDictionary<NSString *, NSDictionary *> *)getExperimentsMap:
    (NSMutableArray<NSData *> *)experiments {
  NSMutableDictionary<NSString *, NSDictionary *> *experimentsMap =
      [[NSMutableDictionary alloc] init];

  for (NSData *experiment in experiments) {
    NSError *error;
    NSDictionary *experimentJSON =
        [NSJSONSerialization JSONObjectWithData:experiment
                                        options:NSJSONReadingMutableContainers
                                          error:&error];
    if (!error && experimentJSON) {
      /// Map experiments to experiment ID.
      [experimentsMap setObject:experimentJSON
                         forKey:[experimentJSON valueForKey:kExperimentIdKey]];
    }
  }

  return experimentsMap;
}

- (NSMutableArray *)extractConfigKeysFromExperiment:(NSDictionary *)experiment {
  if (![experiment objectForKey:kAffectedParameterKeys]) {
    return [[NSMutableArray alloc] init];
  }

  return (NSMutableArray *)[experiment objectForKey:kAffectedParameterKeys];
}

- (bool)isExperimentMetadataUnchanged:(NSDictionary *)activeExperiment
                    fetchedExperiment:(NSDictionary *)fetchedExperiment {
  /// Create copies of active and fetched experiments.
  NSMutableDictionary *activeExperimentCopy = [activeExperiment mutableCopy];
  NSMutableDictionary *fetchedExperimentCopy = [fetchedExperiment mutableCopy];

  /// Remove config parameter keys from object since they don't show up in consistent order.
  if ([activeExperimentCopy objectForKey:kAffectedParameterKeys]) {
    [activeExperimentCopy removeObjectForKey:kAffectedParameterKeys];
  }
  if ([fetchedExperimentCopy objectForKey:kAffectedParameterKeys]) {
    [fetchedExperimentCopy removeObjectForKey:kAffectedParameterKeys];
  }

  return [activeExperimentCopy isEqualToDictionary:fetchedExperimentCopy];
}

- (NSMutableSet<NSString *> *)getChangedExperimentConfigKeys:(NSMutableArray *)activeExperimentKeys
                                       fetchedExperimentKeys:
                                           (NSMutableArray *)fetchedExperimentKeys {
  NSMutableSet<NSString *> *allKeys = [[NSMutableSet alloc] init];
  NSMutableSet<NSString *> *activeKeys = [[NSMutableSet alloc] init];
  NSMutableSet<NSString *> *fetchedKeys = [[NSMutableSet alloc] init];

  /// Init keys set with experiment keys.
  [activeKeys addObjectsFromArray:activeExperimentKeys];
  [fetchedKeys addObjectsFromArray:fetchedExperimentKeys];
  /// Add all keys into a single set.
  allKeys = [[allKeys setByAddingObjectsFromSet:activeKeys] mutableCopy];
  allKeys = [[allKeys setByAddingObjectsFromSet:fetchedKeys] mutableCopy];

  NSMutableSet<NSString *> *changedKeys = [allKeys mutableCopy];

  /// Iterate through all possible keys.
  for (NSString *key in allKeys) {
    /// If keys are present in both active and fetched sets, remove from `changedKeys`.
    if ([activeKeys containsObject:key] && [fetchedKeys containsObject:key]) {
      [changedKeys removeObject:key];
    }
  }

  return changedKeys;
}

- (NSMutableSet<NSString *> *)getKeysAffectedByChangedExperiments {
  NSMutableSet<NSString *> *changedKeys = [[NSMutableSet alloc] init];

  NSMutableDictionary<NSString *, NSDictionary *> *activeExperiments =
      [self getExperimentsMap:_activeExperimentPayloads];
  NSMutableDictionary<NSString *, NSDictionary *> *fetchedExperiments =
      [self getExperimentsMap:_experimentPayloads];

  NSMutableSet<NSString *> *allExperimentIds = [[NSMutableSet alloc] init];
  [allExperimentIds addObjectsFromArray:[fetchedExperiments allKeys]];
  [allExperimentIds addObjectsFromArray:[activeExperiments allKeys]];

  /// Iterate through all possible experiment IDs.
  for (NSString *experimentId in allExperimentIds) {
    /// If an experiment ID doesn't exist one of the maps then an experiment must have been
    /// added/removed. Add it's keys into `changedKeys`.
    if (![activeExperiments objectForKey:experimentId] ||
        ![fetchedExperiments objectForKey:experimentId]) {
      /// Get the experiment that was altered.
      NSDictionary *experiment;
      if ([activeExperiments objectForKey:experimentId]) {
        experiment = [activeExperiments objectForKey:experimentId];
      } else {
        experiment = [fetchedExperiments objectForKey:experimentId];
      }

      /// Add all of it's keys into `changedKeys`.
      [changedKeys addObjectsFromArray:[self extractConfigKeysFromExperiment:experiment]];
    } else {
      /// Fetched and Active contain the experiment ID. The metadata needs to be compared to see if
      /// they're still the same.
      NSDictionary *activeExperiment = [activeExperiments objectForKey:experimentId];
      NSDictionary *fetchedExperiment = [fetchedExperiments objectForKey:experimentId];

      /// Extract keys from active and fetched experiments.
      NSMutableArray *activeExperimentKeys =
          [self extractConfigKeysFromExperiment:activeExperiment];
      NSMutableArray *fetchedExperimentKeys =
          [self extractConfigKeysFromExperiment:fetchedExperiment];

      if (![self isExperimentMetadataUnchanged:activeExperiment
                             fetchedExperiment:fetchedExperiment]) {
        /// Add in all keys from both sides if the experiments metadata has changed.
        [changedKeys addObjectsFromArray:activeExperimentKeys];
        [changedKeys addObjectsFromArray:fetchedExperimentKeys];
      } else {
        /// Compare config keys from either experiment.
        changedKeys = [[changedKeys
            setByAddingObjectsFromSet:[self getChangedExperimentConfigKeys:activeExperimentKeys
                                                     fetchedExperimentKeys:fetchedExperimentKeys]]
            mutableCopy];
      }
    }
  }

  return changedKeys;
}
@end
