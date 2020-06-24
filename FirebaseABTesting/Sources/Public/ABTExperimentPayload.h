// Copyright 2020 Google
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

@property(nonatomic, readonly, copy) NSString *experimentId;
@property(nonatomic, readonly, copy) NSString *variantId;
@property(nonatomic, readonly) NSUInteger experimentStartTimeMillis;
@property(nonatomic, nullable, readonly, copy) NSString *triggerEvent;
@property(nonatomic, readonly) NSUInteger triggerTimeoutMillis;
@property(nonatomic, readonly) NSUInteger timeToLiveMillis;
@property(nonatomic, readonly, copy) NSString *setEventToLog;
@property(nonatomic, readonly, copy) NSString *activateEventToLog;
@property(nonatomic, readonly, copy) NSString *clearEventToLog;
@property(nonatomic, readonly, copy) NSString *timeoutEventToLog;
@property(nonatomic, readonly, copy) NSString *ttlExpiryEventToLog;
@property(nonatomic, readonly) ABTExperimentPayloadExperimentOverflowPolicy overflowPolicy;
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
