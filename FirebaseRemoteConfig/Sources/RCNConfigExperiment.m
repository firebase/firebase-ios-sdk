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
@property(nonatomic, copy) NSArray<NSData *> *experimentPayloads;  ///< Experiment payloads.
@property(nonatomic, copy)
    NSDictionary<NSString *, id> *experimentMetadata;  ///< Experiment metadata
@property(nonatomic, copy)
    NSArray<NSData *> *activeExperimentPayloads;             ///< Activated experiment payloads.
@property(nonatomic, strong) RCNConfigDBManager *DBManager;  ///< Database Manager.
@property(nonatomic, strong) FIRExperimentController *experimentController;
@property(nonatomic, strong) NSDateFormatter *experimentStartTimeDateFormatter;
@property(nonatomic, strong)
    dispatch_queue_t experimentDBQueue;  ///< Serial queue for DB atomicity.
@end

@implementation RCNConfigExperiment {
  NSMutableArray<NSData *> *_experimentPayloads;
  NSMutableDictionary<NSString *, id> *_experimentMetadata;
  NSMutableArray<NSData *> *_activeExperimentPayloads;
  BOOL _databaseLoadCompleted;
}

@synthesize experimentPayloads = _experimentPayloads;
@synthesize experimentMetadata = _experimentMetadata;
@synthesize activeExperimentPayloads = _activeExperimentPayloads;

- (NSArray<NSData *> *)experimentPayloads {
  @synchronized(self) {
    return [_experimentPayloads copy];
  }
}

- (void)setExperimentPayloads:(NSArray<NSData *> *)experimentPayloads {
  @synchronized(self) {
    _experimentPayloads = [experimentPayloads mutableCopy] ?: [[NSMutableArray alloc] init];
  }
}

- (NSDictionary<NSString *, id> *)experimentMetadata {
  @synchronized(self) {
    return [_experimentMetadata copy];
  }
}

- (void)setExperimentMetadata:(NSDictionary<NSString *, id> *)experimentMetadata {
  @synchronized(self) {
    _experimentMetadata = [experimentMetadata mutableCopy] ?: [[NSMutableDictionary alloc] init];
  }
}

- (NSArray<NSData *> *)activeExperimentPayloads {
  @synchronized(self) {
    return [_activeExperimentPayloads copy];
  }
}

- (void)setActiveExperimentPayloads:(NSArray<NSData *> *)activeExperimentPayloads {
  @synchronized(self) {
    _activeExperimentPayloads =
        [activeExperimentPayloads mutableCopy] ?: [[NSMutableArray alloc] init];
  }
}

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

    _experimentDBQueue = dispatch_queue_create("com.google.FirebaseRemoteConfig.ExperimentDBQueue",
                                               DISPATCH_QUEUE_SERIAL);

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
    NSMutableArray<NSData *> *parsedPayloads = nil;
    if (result[@RCNExperimentTableKeyPayload]) {
      parsedPayloads = [[NSMutableArray alloc] init];
      for (NSData *experiment in result[@RCNExperimentTableKeyPayload]) {
        NSError *error;
        id experimentPayloadJSON = [NSJSONSerialization JSONObjectWithData:experiment
                                                                   options:kNilOptions
                                                                     error:&error];
        if (!experimentPayloadJSON || error) {
          FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000031",
                        @"Experiment payload could not be parsed as JSON: %@.", error);
        } else {
          [parsedPayloads addObject:experiment];
        }
      }
    }

    NSMutableDictionary<NSString *, id> *parsedMetadata = nil;
    if (result[@RCNExperimentTableKeyMetadata]) {
      parsedMetadata = [result[@RCNExperimentTableKeyMetadata] mutableCopy];
    }

    NSMutableArray<NSData *> *parsedActivePayloads = nil;
    if (result[@RCNExperimentTableKeyActivePayload]) {
      parsedActivePayloads = [[NSMutableArray alloc] init];
      for (NSData *experiment in result[@RCNExperimentTableKeyActivePayload]) {
        NSError *error;
        id experimentPayloadJSON = [NSJSONSerialization JSONObjectWithData:experiment
                                                                   options:kNilOptions
                                                                     error:&error];
        if (!experimentPayloadJSON || error) {
          FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000031",
                        @"Activated experiment payload could not be parsed as JSON: %@.", error);
        } else {
          [parsedActivePayloads addObject:experiment];
        }
      }
    }

    @synchronized(strongSelf) {
      if (!strongSelf->_databaseLoadCompleted) {
        if (parsedPayloads) {
          [strongSelf->_experimentPayloads removeAllObjects];
          [strongSelf->_experimentPayloads addObjectsFromArray:parsedPayloads];
        }
        if (parsedMetadata) {
          strongSelf->_experimentMetadata = parsedMetadata;
        }
        if (parsedActivePayloads) {
          [strongSelf->_activeExperimentPayloads removeAllObjects];
          [strongSelf->_activeExperimentPayloads addObjectsFromArray:parsedActivePayloads];
        }
        strongSelf->_databaseLoadCompleted = YES;
      }
    }
  };
  [_DBManager loadExperimentWithCompletionHandler:completionHandler];
}

- (void)updateExperimentsWithResponse:(NSArray<NSDictionary<NSString *, id> *> *)response {
  NSMutableArray<NSData *> *serializedPayloads = [[NSMutableArray alloc] init];
  for (NSDictionary<NSString *, id> *experiment in response) {
    if (![NSJSONSerialization isValidJSONObject:experiment]) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000030",
                  @"Invalid experiment payload to be serialized (not a valid JSON object).");
      continue;
    }
    NSError *error;
    NSData *JSONPayload = [NSJSONSerialization dataWithJSONObject:experiment
                                                          options:kNilOptions
                                                            error:&error];
    if (!JSONPayload || error) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000030",
                  @"Invalid experiment payload to be serialized: %@.", error);
    } else {
      [serializedPayloads addObject:JSONPayload];
    }
  }

  @synchronized(self) {
    _databaseLoadCompleted = YES;
    // cache fetched experiment payloads.
    [_experimentPayloads removeAllObjects];
    [_experimentPayloads addObjectsFromArray:serializedPayloads];
  }

  __weak __typeof__(self) weakSelf = self;
  dispatch_async(self.experimentDBQueue, ^{
    __typeof__(self) strongSelf = weakSelf;
    if (!strongSelf) return;
    [strongSelf->_DBManager deleteExperimentTableForKey:@RCNExperimentTableKeyPayload];
    for (NSData *JSONPayload in serializedPayloads) {
      [strongSelf->_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyPayload
                                                     value:JSONPayload
                                         completionHandler:nil];
    }
  });
}

- (void)updateExperimentsWithHandler:(void (^)(NSError *_Nullable))handler {
  if (!self.experimentController) {
    if (handler) {
      NSError *error = [NSError
          errorWithDomain:@"com.google.FirebaseRemoteConfig"
                     code:-1
                 userInfo:@{NSLocalizedDescriptionKey : @"Experiment controller is unavailable."}];
      handler(error);
    }
    return;
  }

  FIRLifecycleEvents *lifecycleEvent = [[FIRLifecycleEvents alloc] init];

  // Capture a consistent snapshot of the current state before processing.
  NSTimeInterval lastStartTime;
  NSArray<NSData *> *payloadsCopy;
  @synchronized(self) {
    lastStartTime = [_experimentMetadata[kExperimentMetadataKeyLastStartTime] doubleValue];
    payloadsCopy = [_experimentPayloads copy];
  }

  // Update the last experiment start time with the latest payload.
  [self updateExperimentStartTime];

  [self.experimentController
      updateExperimentsWithServiceOrigin:kServiceOrigin
                                  events:lifecycleEvent
                                  policy:ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest
                           lastStartTime:lastStartTime
                                payloads:payloadsCopy
                       completionHandler:handler];

  /// Update activated experiments payload and metadata in DB.
  [self updateActiveExperimentsInDBWithPayloads:payloadsCopy];
}

- (void)updateExperimentStartTime {
  NSTimeInterval existingLastStartTime;
  @synchronized(self) {
    existingLastStartTime = [_experimentMetadata[kExperimentMetadataKeyLastStartTime] doubleValue];
  }

  NSTimeInterval latestStartTime =
      [self latestStartTimeWithExistingLastStartTime:existingLastStartTime];

  NSDictionary *metadataCopy = nil;
  BOOL shouldUpdate = NO;
  @synchronized(self) {
    // Check if the calculated start time is newer or equal to what is currently stored,
    // avoiding out-of-order overwrites from logical races during concurrent operations.
    NSTimeInterval currentStoredTime =
        [_experimentMetadata[kExperimentMetadataKeyLastStartTime] doubleValue];
    if (latestStartTime >= currentStoredTime) {
      _experimentMetadata[kExperimentMetadataKeyLastStartTime] = @(latestStartTime);
      metadataCopy = [_experimentMetadata copy];
      shouldUpdate = YES;
    }
  }

  if (!shouldUpdate) {
    return;
  }

  if (![NSJSONSerialization isValidJSONObject:metadataCopy]) {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000028",
                @"Invalid fetched experiment metadata to be serialized.");
    return;
  }
  NSError *error;
  NSData *serializedExperimentMetadata =
      [NSJSONSerialization dataWithJSONObject:metadataCopy
                                      options:NSJSONWritingPrettyPrinted
                                        error:&error];
  if (serializedExperimentMetadata) {
    __weak __typeof__(self) weakSelf = self;
    dispatch_async(self.experimentDBQueue, ^{
      __typeof__(self) strongSelf = weakSelf;
      if (!strongSelf) return;
      [strongSelf->_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyMetadata
                                                     value:serializedExperimentMetadata
                                         completionHandler:nil];
    });
  }
}

- (void)updateActiveExperimentsInDBWithPayloads:(NSArray<NSData *> *)payloads {
  NSArray<NSData *> *payloadsCopy = [payloads copy] ?: @[];
  @synchronized(self) {
    /// Put current fetched experiment payloads into activated experiment DB.
    [_activeExperimentPayloads removeAllObjects];
    [_activeExperimentPayloads addObjectsFromArray:payloadsCopy];
  }
  __weak __typeof__(self) weakSelf = self;
  dispatch_async(self.experimentDBQueue, ^{
    __typeof__(self) strongSelf = weakSelf;
    if (!strongSelf) return;
    [strongSelf->_DBManager deleteExperimentTableForKey:@RCNExperimentTableKeyActivePayload];
    for (NSData *experiment in payloadsCopy) {
      [strongSelf->_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyActivePayload
                                                     value:experiment
                                         completionHandler:nil];
    }
  });
}

- (NSTimeInterval)latestStartTimeWithExistingLastStartTime:(NSTimeInterval)existingLastStartTime {
  NSArray<NSData *> *payloadsCopy;
  @synchronized(self) {
    payloadsCopy = [_experimentPayloads copy];
  }
  return [self.experimentController
      latestExperimentStartTimestampBetweenTimestamp:existingLastStartTime
                                         andPayloads:payloadsCopy];
}
@end
