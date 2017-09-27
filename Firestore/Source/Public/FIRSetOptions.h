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
 * An options object that configures the behavior of setData() calls. By providing the
 * `FIRSetOptions` objects returned by `merge:`, the setData() methods in `FIRDocumentReference`,
 * `FIRWriteBatch` and `FIRTransaction` can be configured to perform granular merges instead
 * of overwriting the target documents in their entirety.
 */
NS_SWIFT_NAME(SetOptions)
@interface FIRSetOptions : NSObject

/**   */
- (id)init NS_UNAVAILABLE;
/**
 * Changes the behavior of setData() calls to only replace the values specified in its data
 * argument. Fields with no corresponding values in the data passed to setData() will remain
 * untouched.
 *
 * @return The created `FIRSetOptions` object
 */
+ (instancetype)merge;

/** Whether setData() should merge existing data instead of performing an overwrite. */
@property(nonatomic, readonly, getter=isMerge) BOOL merge;

@end

NS_ASSUME_NONNULL_END
