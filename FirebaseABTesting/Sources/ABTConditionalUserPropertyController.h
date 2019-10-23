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

#import <Foundation/Foundation.h>

#import "FirebaseABTesting/Sources/Protos/developers/mobile/abt/proto/ExperimentPayload.pbobjc.h"

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>

NS_ASSUME_NONNULL_BEGIN

@class FIRLifecycleEvents;

/// This class dynamically calls Firebase Analytics API to collect or update experiments
/// information.
/// The experiment in Firebase Analytics is named as conditional user property (CUP) object defined
/// in FIRAConditionalUserProperty.h.
@interface ABTConditionalUserPropertyController : NSObject

/// Returns the ABTConditionalUserPropertyController singleton.
+ (instancetype)sharedInstanceWithAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics;

/// Returns the list of currently set experiments from Firebase Analytics for the provided origin.
- (NSArray *)experimentsWithOrigin:(NSString *)origin;

/// Returns the experiment ID from Firebase Analytics given an experiment object. Returns empty
/// string if can't find Firebase Analytics service.
- (NSString *)experimentIDOfExperiment:(nullable id)experiment;

/// Returns the variant ID from Firebase Analytics given an experiment object. Returns empty string
/// if can't find Firebase Analytics service.
- (NSString *)variantIDOfExperiment:(nullable id)experiment;

/// Returns whether the experiment is the same as the one in the provided payload.
- (BOOL)isExperiment:(id)experiment theSameAsPayload:(ABTExperimentPayload *)payload;

/// Clears the experiment in Firebase Analytics.
/// @param experimentID  Experiment ID to clear.
/// @param variantID     Variant ID to clear.
/// @param origin        Impacted originating service, it is defined at Firebase Analytics
///                      FIREventOrigins.h.
/// @param payload       Payload to overwrite event name in events. DO NOT use payload's experiment
///                      ID and variant ID as the experiment to clear.
/// @param events        Events name for clearing the experiment.
- (void)clearExperiment:(NSString *)experimentID
              variantID:(NSString *)variantID
             withOrigin:(NSString *)origin
                payload:(nullable ABTExperimentPayload *)payload
                 events:(FIRLifecycleEvents *)events;

/// Sets the experiment in Firebase Analytics.
/// @param origin        Impacted originating service, it is defined at Firebase Analytics
///                      FIREventOrigins.h.
/// @param payload       Payload to overwrite event name in events. DO NOT use payload's experiment
///                      ID and variant ID as the experiment to set.
/// @param events        Events name for setting the experiment.
/// @param policy        Overflow policy when the number of experiments is over the limit.
- (void)setExperimentWithOrigin:(NSString *)origin
                        payload:(ABTExperimentPayload *)payload
                         events:(FIRLifecycleEvents *)events
                         policy:(ABTExperimentPayload_ExperimentOverflowPolicy)policy;

/**
 *  Unavailable. Use sharedInstanceWithAnalytics: instead.
 */
- (instancetype)init __attribute__((unavailable("Use +sharedInstanceWithAnalytics: instead.")));
@end

NS_ASSUME_NONNULL_END
