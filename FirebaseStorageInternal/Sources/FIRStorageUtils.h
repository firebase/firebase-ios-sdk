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

@class FIRStoragePath;
@class FIRIMPLStorageReference;

NS_ASSUME_NONNULL_BEGIN

/**
 * FIRStorageUtils provides a number of helper methods for commonly used operations
 * in Firebase Storage, such as JSON parsing, escaping, and file extensions.
 */
@interface FIRStorageUtils : NSObject

/**
 * Performs a crude translation of the user provided timeouts to the retry intervals that
 * GTMSessionFetcher accepts. GTMSessionFetcher times out operations if the time between individual
 * retry attempts exceed a certain threshold, while our API contract looks at the total observed
 * time of the operation (i.e. the sum of all retries).
 * @param retryTime A timeout that caps the sum of all retry attempts
 * @return A timeout that caps the timeout of the last retry attempt
 */
+ (NSTimeInterval)computeRetryIntervalFromRetryTime:(NSTimeInterval)retryTime;

@end

NS_ASSUME_NONNULL_END
