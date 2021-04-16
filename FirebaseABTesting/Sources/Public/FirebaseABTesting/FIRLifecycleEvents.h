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

NS_ASSUME_NONNULL_BEGIN

/// Default event name for when an experiment is set.
extern NSString *const FIRSetExperimentEventName NS_SWIFT_NAME(DefaultSetExperimentEventName);
/// Default event name for when an experiment is activated.
// clang-format off
// clang-format12 will merge lines and exceed 100 character limit.
extern NSString *const FIRActivateExperimentEventName
    NS_SWIFT_NAME(DefaultActivateExperimentEventName);
/// Default event name for when an experiment is cleared.
extern NSString *const FIRClearExperimentEventName NS_SWIFT_NAME(DefaultClearExperimentEventName);
/// Default event name for when an experiment times out for being activated.
extern NSString *const FIRTimeoutExperimentEventName
    NS_SWIFT_NAME(DefaultTimeoutExperimentEventName);
// clang-format on
/// Default event name for when an experiment is expired as it reaches the end of TTL.
extern NSString *const FIRExpireExperimentEventName NS_SWIFT_NAME(DefaultExpireExperimentEventName);

/// An Experiment Lifecycle Event Object that specifies the name of the experiment event to be
/// logged by Firebase Analytics.
NS_SWIFT_NAME(LifecycleEvents)
@interface FIRLifecycleEvents : NSObject

/// Event name for when an experiment is set. It is default to FIRSetExperimentEventName and can be
/// overridden. If experiment payload has a valid string of this field, always use experiment
/// payload.
@property(nonatomic, copy) NSString *setExperimentEventName;

/// Event name for when an experiment is activated. It is default to FIRActivateExperimentEventName
/// and can be overridden. If experiment payload has a valid string of this field, always use
/// experiment payload.
@property(nonatomic, copy) NSString *activateExperimentEventName;

/// Event name for when an experiment is cleared. It is default to FIRClearExperimentEventName and
/// can be overridden. If experiment payload has a valid string of this field, always use experiment
/// payload.
@property(nonatomic, copy) NSString *clearExperimentEventName;
/// Event name for when an experiment is timeout from being STANDBY. It is default to
/// FIRTimeoutExperimentEventName and can be overridden. If experiment payload has a valid string
/// of this field, always use experiment payload.
@property(nonatomic, copy) NSString *timeoutExperimentEventName;

/// Event name when an experiment is expired when it reaches the end of its TTL.
/// It is default to FIRExpireExperimentEventName and can be overridden. If experiment payload has a
/// valid string of this field, always use experiment payload.
@property(nonatomic, copy) NSString *expireExperimentEventName;

@end

NS_ASSUME_NONNULL_END
