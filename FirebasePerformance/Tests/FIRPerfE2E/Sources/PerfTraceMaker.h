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

#import "FirebasePerformance/FIRPerformance.h"
#import "PerfTraceDelegate.h"

/**
 * This class enables creating a FIRTrace with the provided attributes.
 */
@interface PerfTraceMaker : NSObject

/**
 * Creates a trace with the provided name. The trace will be automatically stopped after the
 * duration specified.
 *
 * @param name The name of the trace.
 * @param duration The duration for which the trace will be running.
 * @return The trace object with the name specified.
 */
+ (FIRTrace *)createTraceWithName:(NSString *)name
                         duration:(NSTimeInterval)duration
                         delegate:(id<PerfTraceDelegate>)delegate;

@end
