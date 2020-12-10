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

#import "FirebasePerformance/Sources/Loggers/FPRGDTLogSampler.h"

@class FPRConfigurations;

/**
 * Extension that is added on top of the class FPRGDTLogSampler to aid unit tests.
 */
@interface FPRGDTLogSampler ()

/**
 * A custom initializer used only in the case of testing.
 *
 * @param flags Configuration flags to be initialized with.
 * @param bucket Bucket identifier to decide on dropping or sending the events based on the sampling
 * rate for traces.
 * @return Instance of FPRLogSampler.
 */
- (nullable instancetype)initWithFlags:(nonnull FPRConfigurations *)flags
                     samplingThreshold:(double)bucket NS_DESIGNATED_INITIALIZER;

@end
