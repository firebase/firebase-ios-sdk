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

#import "FirebasePerformance/Sources/AppActivity/FPRAppActivityTracker.h"

@protocol FPRGaugeCollector <NSObject>

/** Initiates a fetch for the gauge metric. */
- (void)collectMetric;

/**
 * Adapts to application state and starts capturing the gauge metric at a pre-configured rate as
 * defined in the configuration system.
 *
 * @note Call this method when the application state has changed.
 *
 * @param applicationState Application state.
 */
- (void)updateSamplingFrequencyForApplicationState:(FPRApplicationState)applicationState;

@end
