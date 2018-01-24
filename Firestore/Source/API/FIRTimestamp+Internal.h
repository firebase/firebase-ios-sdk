/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FIRTimestamp.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRTimestamp ()

/**
 * Creates a new timestamp.
 *
 * @param seconds the number of seconds since epoch.
 * @param nanos the number of nanoseconds after the seconds.
 */
- (instancetype)initWithSeconds:(int64_t)seconds nanos:(int32_t)nanos NS_DESIGNATED_INITIALIZER;

/**
 * Non-negative fractions of a second at nanosecond resolution. Negative second values with
 * fractions must still have non-negative nanos values that count forward in time.
 * Must be from 0 to 999,999,999 inclusive.
 */
@property(nonatomic, assign, readonly) int32_t nanos;

@end

/** Internal FIRTimestamp API we don't want exposed in our public header files. */
@interface FIRTimestamp (Internal)

/** Creates a new timestamp with the current date / time. */
+ (instancetype)timestamp;

- (NSComparisonResult)compare:(FIRTimestamp *)other;

/**
 * Converts the given date to an ISO 8601 timestamp string, useful for rendering in JSON.
 *
 * ISO 8601 dates times in UTC look like this: "1912-04-14T23:40:00.000000000Z".
 *
 * @see http://www.ecma-international.org/ecma-262/6.0/#sec-date-time-string-format
 */
- (NSString *)ISO8601String;

@end

NS_ASSUME_NONNULL_END
