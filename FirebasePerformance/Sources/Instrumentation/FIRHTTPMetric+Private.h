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

#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"

/**
 * Extension that is added on top of the class FIRHTTPMetric to make the private properties visible
 * between the implementation file and the unit tests.
 */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
@interface FIRHTTPMetric ()

/* Network trace to capture the HTTPMetric information. */
@property(nonatomic, strong) FPRNetworkTrace *networkTrace;

/**
 * Marks the end time of the request.
 */
- (void)markRequestComplete;

/**
 * Marks the start time of the response.
 */
- (void)markResponseStart;

@end
