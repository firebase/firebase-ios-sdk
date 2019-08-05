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

#import <FirebaseABTesting/FIRLifecycleEvents.h>

#import <FirebaseABTesting/FIRExperimentController.h>

/// Default name of the analytics event to be logged when an experiment is set.
NSString *const FIRSetExperimentEventName = @"_exp_set";
/// Default name of the analytics event to be logged when an experiment is activated.
NSString *const FIRActivateExperimentEventName = @"_exp_activate";
/// Default name of the analytics event to be logged when an experiment is cleared.
NSString *const FIRClearExperimentEventName = @"_exp_clear";
/// Default name of the analytics event to be logged when an experiment times out for being
/// activated.
NSString *const FIRTimeoutExperimentEventName = @"_exp_timeout";
/// Default name of the analytics event to be logged when an experiment is expired as it reaches the
/// end of TTL.
NSString *const FIRExpireExperimentEventName = @"_exp_expire";
/// Prefix for lifecycle event names.
static NSString *const kLifecycleEventPrefix = @"_";

@implementation FIRLifecycleEvents
- (instancetype)init {
  self = [super init];
  if (self) {
    _setExperimentEventName = FIRSetExperimentEventName;
    _activateExperimentEventName = FIRActivateExperimentEventName;
    _clearExperimentEventName = FIRClearExperimentEventName;
    _timeoutExperimentEventName = FIRTimeoutExperimentEventName;
    _expireExperimentEventName = FIRExpireExperimentEventName;
  }
  return self;
}

- (void)setSetExperimentEventName:(NSString *)setExperimentEventName {
  if (setExperimentEventName && [setExperimentEventName hasPrefix:kLifecycleEventPrefix]) {
    _setExperimentEventName = setExperimentEventName;
  } else {
    _setExperimentEventName = FIRSetExperimentEventName;
  }
}

- (void)setActivateExperimentEventName:(NSString *)activateExperimentEventName {
  if (activateExperimentEventName &&
      [activateExperimentEventName hasPrefix:kLifecycleEventPrefix]) {
    _activateExperimentEventName = activateExperimentEventName;
  } else {
    _activateExperimentEventName = FIRActivateExperimentEventName;
  }
}

- (void)setClearExperimentEventName:(NSString *)clearExperimentEventName {
  if (clearExperimentEventName && [clearExperimentEventName hasPrefix:kLifecycleEventPrefix]) {
    _clearExperimentEventName = clearExperimentEventName;
  } else {
    _clearExperimentEventName = FIRClearExperimentEventName;
  }
}

- (void)setTimeoutExperimentEventName:(NSString *)timeoutExperimentEventName {
  if (timeoutExperimentEventName && [timeoutExperimentEventName hasPrefix:kLifecycleEventPrefix]) {
    _timeoutExperimentEventName = timeoutExperimentEventName;
  } else {
    _timeoutExperimentEventName = FIRTimeoutExperimentEventName;
  }
}

- (void)setExpireExperimentEventName:(NSString *)expireExperimentEventName {
  if (expireExperimentEventName && [_timeoutExperimentEventName hasPrefix:kLifecycleEventPrefix]) {
    _expireExperimentEventName = expireExperimentEventName;
  } else {
    _expireExperimentEventName = FIRExpireExperimentEventName;
  }
}

@end
