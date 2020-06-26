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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Policy for handling the case where there's an overflow of experiments for an installation
/// instance.
typedef NS_ENUM(int32_t, ABTExperimentPayloadExperimentOverflowPolicy) {
  ABTExperimentPayloadExperimentOverflowPolicyUnrecognizedValue = 999,
  ABTExperimentPayloadExperimentOverflowPolicyUnspecified = 0,
  ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest = 1,
  ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest = 2,
};

@interface ABTExperimentLite : NSObject
@property(nonatomic, readonly, copy) NSString *experimentId;

- (instancetype)initWithExperimentId:(NSString *)experimentId NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface ABTExperimentPayload : NSObject

/// Unique identifier for this experiment.
@property(nonatomic, readonly, copy) NSString *experimentId;

/// Unique identifier for the variant to which an installation instance has been assigned.
@property(nonatomic, readonly, copy) NSString *variantId;

/// Epoch time that represents when the experiment was started.
@property(nonatomic, readonly) int64_t experimentStartTimeMillis;

/// The event that triggers this experiment into ON state.
@property(nonatomic, nullable, readonly, copy) NSString *triggerEvent;

/// Duration in milliseconds for which the experiment can stay in STANDBY state (un-triggered).
@property(nonatomic, readonly) int64_t triggerTimeoutMillis;

/// Duration in milliseconds for which the experiment can stay in ON state (triggered).
@property(nonatomic, readonly) int64_t timeToLiveMillis;

/// The event logged when impact service sets the experiment.
@property(nonatomic, readonly, copy) NSString *setEventToLog;

/// The event logged when an experiment goes to the ON state.
@property(nonatomic, readonly, copy) NSString *activateEventToLog;

/// The event logged when an experiment is cleared.
@property(nonatomic, readonly, copy) NSString *clearEventToLog;

/// The event logged when an experiment times out after `triggerTimeoutMillis` milliseconds.
@property(nonatomic, readonly, copy) NSString *timeoutEventToLog;

/// The event logged when an experiment times out after `timeToLiveMillis` milliseconds.
@property(nonatomic, readonly, copy) NSString *ttlExpiryEventToLog;

@property(nonatomic, readonly) ABTExperimentPayloadExperimentOverflowPolicy overflowPolicy;

/// A list of all other ongoing (started, and not yet stopped) experiments at the time this
/// experiment was started. Does not include this experiment; only the others.
@property(nonatomic, readonly) NSArray<ABTExperimentLite *> *ongoingExperiments;

/// Parses an ABTExperimentPayload directly from JSON data.
/// @param data  JSON object as NSData. Must be reconstructible as an NSDictionary<NSString* , id>.
+ (instancetype)parseFromData:(NSData *)data;

/// Initializes an ABTExperimentPayload from a dictionary with experiment metadata.
- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Clears the trigger event associated with this payload.
- (void)clearTriggerEvent;

/// Checks if the overflow policy is a valid enum object.
- (BOOL)overflowPolicyIsValid;

@end

NS_ASSUME_NONNULL_END
