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

#import "FirebasePerformance/Sources/Common/FPRDate.h"

/** Internal fake date class which can be used to move the clock ahead or behind for unit tests. */
@interface FPRFakeDate : NSObject <FPRDate>

// Increments the clock time by |interval|, or decrements if |interval| is negative.
- (void)incrementTime:(NSTimeInterval)interval;

@end
