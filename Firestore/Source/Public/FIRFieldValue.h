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
 * Sentinel values that can be used when writing document fields with setData() or updateData().
 */
NS_SWIFT_NAME(FieldValue)
@interface FIRFieldValue : NSObject

/**   */
- (instancetype)init NS_UNAVAILABLE;

/** Used with updateData() to mark a field for deletion. */
// clang-format off
+ (instancetype)fieldValueForDelete NS_SWIFT_NAME(delete());
// clang-format on

/**
 * Used with setData() or updateData() to include a server-generated timestamp in the written
 * data.
 */
+ (instancetype)fieldValueForServerTimestamp NS_SWIFT_NAME(serverTimestamp());

@end

NS_ASSUME_NONNULL_END
