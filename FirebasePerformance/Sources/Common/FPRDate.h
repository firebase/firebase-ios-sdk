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

/**
 * Definition of a date that is used internally.
 */
@protocol FPRDate <NSObject>

/** Returns the current time. */
- (NSDate *)now;

/**
 * Calculates the time difference between the provided date and returns the difference in seconds.
 *
 * @param date A date object used for reference.
 * @return Difference in time between the current date and the provided date in seconds. If the
 * current date is older than the provided date, the difference is returned in positive, else
 * negative.
 */
- (NSTimeInterval)timeIntervalSinceDate:(NSDate *)date;

@end
