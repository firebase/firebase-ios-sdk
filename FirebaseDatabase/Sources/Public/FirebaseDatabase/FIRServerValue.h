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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Placeholder values you may write into Firebase Database as a value or
 * priority that will automatically be populated by the Firebase Database
 * server.
 */
NS_SWIFT_NAME(ServerValue)
@interface FIRServerValue : NSObject

/**
 * Placeholder value for the number of milliseconds since the Unix epoch
 */
+ (NSDictionary *)timestamp;

/**
 * Returns a placeholder value that can be used to atomically increment the
 * current database value by the provided delta.
 *
 * The delta must be a long or double value. If the current value is not an
 * integer or double, or if the data does not yet exist, the transformation will
 * set the data to the delta value. If either of the delta value or the existing
 * data are doubles, both values will be interpreted as doubles. Double
 * arithmetic and representation of double values follow IEEE 754 semantics. If
 * there is positive/negative integer overflow, the sum is calculated as a
 * double.
 *
 * @param delta the amount to modify the current value atomically.
 * @return a placeholder value for modifying data atomically server-side.
 */
+ (NSDictionary *)increment:(NSNumber *)delta NS_SWIFT_NAME(increment(_:));

@end

NS_ASSUME_NONNULL_END
