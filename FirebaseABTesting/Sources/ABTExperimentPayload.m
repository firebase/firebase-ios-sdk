// Copyright 2020 Google LLC
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

#import "FirebaseABTesting/Sources/Private/ABTExperimentPayload.h"

static NSString *const kExperimentPayloadKeyExperimentID = @"experimentId";
static NSString *const kExperimentPayloadKeyVariantID = @"variantId";

// Start time can either be a date string or integer (milliseconds since 1970).
static NSString *const kExperimentPayloadKeyExperimentStartTime = @"experimentStartTime";
static NSString *const kExperimentPayloadKeyExperimentStartTimeMillis =
    @"experimentStartTimeMillis";
static NSString *const kExperimentPayloadKeyTriggerEvent = @"triggerEvent";
static NSString *const kExperimentPayloadKeyTriggerTimeoutMillis = @"triggerTimeoutMillis";
static NSString *const kExperimentPayloadKeyTimeToLiveMillis = @"timeToLiveMillis";
static NSString *const kExperimentPayloadKeySetEventToLog = @"setEventToLog";
static NSString *const kExperimentPayloadKeyActivateEventToLog = @"activateEventToLog";
static NSString *const kExperimentPayloadKeyClearEventToLog = @"clearEventToLog";
static NSString *const kExperimentPayloadKeyTimeoutEventToLog = @"timeoutEventToLog";
static NSString *const kExperimentPayloadKeyTTLExpiryEventToLog = @"ttlExpiryEventToLog";

static NSString *const kExperimentPayloadKeyOverflowPolicy = @"overflowPolicy";
static NSString *const kExperimentPayloadValueDiscardOldestOverflowPolicy = @"DISCARD_OLDEST";
static NSString *const kExperimentPayloadValueIgnoreNewestOverflowPolicy = @"IGNORE_NEWEST";

static NSString *const kExperimentPayloadKeyOngoingExperiments = @"ongoingExperiments";

/// Returns `value` if it is a string, otherwise nil.
static NSString *_Nullable ABTStringValue(id _Nullable value) {
  return [value isKindOfClass:[NSString class]] ? value : nil;
}

/// Returns the int64 value of `value` if it is a number or numeric string, otherwise 0.
static int64_t ABTInt64Value(id _Nullable value) {
  if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) {
    return [value longLongValue];
  }
  return 0;
}

@implementation ABTExperimentLite

- (instancetype)initWithExperimentId:(NSString *)experimentId {
  if (self = [super init]) {
    _experimentId = experimentId;
  }
  return self;
}

@end

@implementation ABTExperimentPayload

+ (NSDateFormatter *)experimentStartTimeFormatter {
  // NSDateFormatter is expensive to create and is thread-safe on all supported OS versions, so
  // create it once and share it.
  static NSDateFormatter *dateFormatter;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    // Locale needs to be hardcoded. See
    // https://developer.apple.com/library/ios/#qa/qa1480/_index.html for more details.
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
  });
  return dateFormatter;
}

+ (nullable instancetype)parseFromData:(NSData *)data {
  if (![data isKindOfClass:[NSData class]]) {
    return nil;
  }
  NSError *error;
  id experimentDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                            options:NSJSONReadingAllowFragments
                                                              error:&error];
  if (error != nil || ![experimentDictionary isKindOfClass:[NSDictionary class]]) {
    return nil;
  } else {
    return [[ABTExperimentPayload alloc] initWithDictionary:experimentDictionary];
  }
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary {
  if (self = [super init]) {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
      dictionary = @{};
    }
    _experimentId = ABTStringValue(dictionary[kExperimentPayloadKeyExperimentID]);
    _variantId = ABTStringValue(dictionary[kExperimentPayloadKeyVariantID]);
    _triggerEvent = ABTStringValue(dictionary[kExperimentPayloadKeyTriggerEvent]);
    _setEventToLog = ABTStringValue(dictionary[kExperimentPayloadKeySetEventToLog]);
    _activateEventToLog = ABTStringValue(dictionary[kExperimentPayloadKeyActivateEventToLog]);
    _clearEventToLog = ABTStringValue(dictionary[kExperimentPayloadKeyClearEventToLog]);
    _timeoutEventToLog = ABTStringValue(dictionary[kExperimentPayloadKeyTimeoutEventToLog]);
    _ttlExpiryEventToLog = ABTStringValue(dictionary[kExperimentPayloadKeyTTLExpiryEventToLog]);

    // Experiment start time can either be in the form of a date string or milliseconds since 1970.
    NSString *experimentStartTimeString =
        ABTStringValue(dictionary[kExperimentPayloadKeyExperimentStartTime]);
    if (experimentStartTimeString) {
      // Convert from date string.
      NSDate *experimentStartTime =
          [[[self class] experimentStartTimeFormatter] dateFromString:experimentStartTimeString];
      _experimentStartTimeMillis = (int64_t)(experimentStartTime.timeIntervalSince1970 * 1000);
    } else if (dictionary[kExperimentPayloadKeyExperimentStartTimeMillis]) {
      // Simply store milliseconds.
      _experimentStartTimeMillis =
          ABTInt64Value(dictionary[kExperimentPayloadKeyExperimentStartTimeMillis]);
    }

    _triggerTimeoutMillis = ABTInt64Value(dictionary[kExperimentPayloadKeyTriggerTimeoutMillis]);
    _timeToLiveMillis = ABTInt64Value(dictionary[kExperimentPayloadKeyTimeToLiveMillis]);

    // Overflow policy can be an integer, or string e.g. "DISCARD_OLDEST" or "IGNORE_NEWEST".
    if ([dictionary[kExperimentPayloadKeyOverflowPolicy] isKindOfClass:[NSString class]]) {
      // If it's a string, pick against the preset string values.
      NSString *policy = dictionary[kExperimentPayloadKeyOverflowPolicy];
      if ([policy isEqualToString:kExperimentPayloadValueDiscardOldestOverflowPolicy]) {
        _overflowPolicy = ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest;
      } else if ([policy isEqualToString:kExperimentPayloadValueIgnoreNewestOverflowPolicy]) {
        _overflowPolicy = ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest;
      } else {
        _overflowPolicy = ABTExperimentPayloadExperimentOverflowPolicyUnrecognizedValue;
      }
    } else if ([dictionary[kExperimentPayloadKeyOverflowPolicy] isKindOfClass:[NSNumber class]]) {
      _overflowPolicy = [dictionary[kExperimentPayloadKeyOverflowPolicy] intValue];
    } else {
      _overflowPolicy = ABTExperimentPayloadExperimentOverflowPolicyUnspecified;
    }

    NSMutableArray<ABTExperimentLite *> *ongoingExperiments = [[NSMutableArray alloc] init];

    id ongoingExperimentsArray = dictionary[kExperimentPayloadKeyOngoingExperiments];
    if ([ongoingExperimentsArray isKindOfClass:[NSArray class]]) {
      for (id experimentDictionary in ongoingExperimentsArray) {
        if (![experimentDictionary isKindOfClass:[NSDictionary class]]) {
          continue;
        }
        NSString *experimentId =
            ABTStringValue(experimentDictionary[kExperimentPayloadKeyExperimentID]);
        if (experimentId) {
          ABTExperimentLite *liteExperiment =
              [[ABTExperimentLite alloc] initWithExperimentId:experimentId];
          [ongoingExperiments addObject:liteExperiment];
        }
      }
    }

    _ongoingExperiments = [ongoingExperiments copy];
  }
  return self;
}

- (void)clearTriggerEvent {
  _triggerEvent = nil;
}

- (BOOL)overflowPolicyIsValid {
  return self.overflowPolicy == ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest ||
         self.overflowPolicy == ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest;
}

- (void)setOverflowPolicy:(ABTExperimentPayloadExperimentOverflowPolicy)overflowPolicy {
  _overflowPolicy = overflowPolicy;
}

@end
