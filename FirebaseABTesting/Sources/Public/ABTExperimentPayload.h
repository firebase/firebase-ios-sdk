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
    ABTExperimentPayloadExperimentOverflowPolicyUnrecognizedValue = 69696969,
    ABTExperimentPayloadExperimentOverflowPolicyUnspecified = 0,
    ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest = 1,
    ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest = 2,
};

@interface ABTExperimentLite : NSObject

@property(nonatomic, readwrite, copy, null_resettable) NSString *experimentId;

@end

@interface ABTExperimentPayload : NSObject

@property(nonatomic, readwrite, copy, null_resettable) NSString *experimentId;
@property(nonatomic, readwrite, copy, null_resettable) NSString *variantId;
@property(nonatomic, readwrite) int64_t experimentStartTimeMillis;
@property(nonatomic, readwrite, copy, null_resettable) NSString *triggerEvent;
@property(nonatomic, readwrite) int64_t triggerTimeoutMillis;
@property(nonatomic, readwrite) int64_t timeToLiveMillis;
@property(nonatomic, readwrite, copy, null_resettable) NSString *setEventToLog;
@property(nonatomic, readwrite, copy, null_resettable) NSString *activateEventToLog;
@property(nonatomic, readwrite, copy, null_resettable) NSString *clearEventToLog;
@property(nonatomic, readwrite, copy, null_resettable) NSString *timeoutEventToLog;
@property(nonatomic, readwrite, copy, null_resettable) NSString *ttlExpiryEventToLog;
@property(nonatomic, readwrite) ABTExperimentPayloadExperimentOverflowPolicy overflowPolicy;
@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<ABTExperimentLite*> *ongoingExperimentsArray;

@end

NS_ASSUME_NONNULL_END
