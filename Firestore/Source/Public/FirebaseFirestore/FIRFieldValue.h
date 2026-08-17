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
@class FIRDecimal128Value;
@class FIRInt32Value;
@class FIRVectorValue;

/**
 * Sentinel values that can be used when writing document fields with `setData()` or `updateData()`.
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(FieldValue)
@interface FIRFieldValue : NSObject

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/** Used with `updateData()` to mark a field for deletion. */
// clang-format off
+ (instancetype)fieldValueForDelete NS_SWIFT_NAME(delete());
// clang-format on

/**
 * Used with `setData()` or `updateData()` to include a server-generated timestamp in the written
 * data.
 */
+ (instancetype)fieldValueForServerTimestamp NS_SWIFT_NAME(serverTimestamp());

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to union the given elements with any array value that already exists on the server. Each
 * specified element that doesn't already exist in the array will be added to the end. If the
 * field being modified is not already an array it will be overwritten with an array containing
 * exactly the specified elements.
 *
 * @param elements The elements to union into the array.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForArrayUnion:(NSArray<id> *)elements NS_SWIFT_NAME(arrayUnion(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to remove the given elements from any array value that already exists on the server. All
 * instances of each element specified will be removed from the array. If the field being
 * modified is not already an array it will be overwritten with an empty array.
 *
 * @param elements The elements to remove from the array.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForArrayRemove:(NSArray<id> *)elements NS_SWIFT_NAME(arrayRemove(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to increment the field's current value by the given value.
 *
 * If the current value is an integer or a double, both the current and the given value will be
 * interpreted as doubles and all arithmetic will follow IEEE 754 semantics. Otherwise, the
 * transformation will set the field to the given value.
 *
 * @param d The double value to increment by.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForDoubleIncrement:(double)d NS_SWIFT_NAME(increment(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to increment the field's current value by the given value.
 *
 * If the current field value is an integer, possible integer overflows are resolved to LONG_MAX or
 * LONG_MIN. If the current field value is a double, both values will be interpreted as doubles and
 * the arithmetic will follow IEEE 754 semantics.
 *
 * If field is not an integer or double, or if the field does not yet exist, the transformation
 * will set the field to the given value.
 *
 * @param l The integer value to increment by.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForIntegerIncrement:(int64_t)l NS_SWIFT_NAME(increment(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to increment the field's current value by the given 32-bit integer value.
 *
 * If the current field value is a 32-bit integer, possible integer overflows are resolved to
 * INT32_MAX or INT32_MIN. If the current field value is an integer, possible integer overflows are
 * resolved to LONG_MAX or LONG_MIN. If the current field value is a double, both values will be
 * interpreted as doubles and the arithmetic will follow IEEE 754 semantics.
 *
 * If field is not a number, or if the field does not yet exist, the transformation
 * will set the field to the given value.
 *
 * @param int32 The 32-bit integer value to increment by.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForInt32Increment:(FIRInt32Value *)int32 NS_SWIFT_NAME(increment(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to increment the field's current value by the given 128-bit decimal floating point value.
 *
 * Note: For local latency-compensated evaluation, 128-bit decimal arithmetic is approximated
 * using standard 64-bit floating point arithmetic until the mutation is acknowledged and
 * finalized with full precision by the server.
 *
 * If field is not a number, or if the field does not yet exist, the transformation
 * will set the field to the given value.
 *
 * @param decimal128 The 128-bit decimal floating point value to increment by.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForDecimal128Increment:(FIRDecimal128Value *)decimal128
    NS_SWIFT_NAME(increment(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to set the field to the minimum of its current value and the given double value.
 *
 * If the field is not a number, or if the field does not yet exist, the transformation will set the
 * field to the given value.
 *
 * @param d The double value to compare.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForDoubleMinimum:(double)d NS_SWIFT_NAME(minimum(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to set the field to the minimum of its current value and the given integer value.
 *
 * If the field is not a number, or if the field does not yet exist, the transformation will set the
 * field to the given value.
 *
 * @param l The integer value to compare.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForIntegerMinimum:(int64_t)l NS_SWIFT_NAME(minimum(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to set the field to the minimum of its current value and the given 32-bit integer value.
 *
 * If the field is not a number, or if the field does not yet exist, the transformation will set the
 * field to the given value.
 *
 * @param int32 The 32-bit integer value to compare.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForInt32Minimum:(FIRInt32Value *)int32 NS_SWIFT_NAME(minimum(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to set the field to the minimum of its current value and the given 128-bit decimal floating point
 * value.
 *
 * If the field is not a number, or if the field does not yet exist, the transformation will set the
 * field to the given value.
 *
 * @param decimal128 The 128-bit decimal floating point value to compare.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForDecimal128Minimum:(FIRDecimal128Value *)decimal128
    NS_SWIFT_NAME(minimum(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to set the field to the maximum of its current value and the given double value.
 *
 * If the field is not a number, or if the field does not yet exist, the transformation will set the
 * field to the given value.
 *
 * @param d The double value to compare.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForDoubleMaximum:(double)d NS_SWIFT_NAME(maximum(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to set the field to the maximum of its current value and the given integer value.
 *
 * If the field is not a number, or if the field does not yet exist, the transformation will set the
 * field to the given value.
 *
 * @param l The integer value to compare.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForIntegerMaximum:(int64_t)l NS_SWIFT_NAME(maximum(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to set the field to the maximum of its current value and the given 32-bit integer value.
 *
 * If the field is not a number, or if the field does not yet exist, the transformation will set the
 * field to the given value.
 *
 * @param int32 The 32-bit integer value to compare.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForInt32Maximum:(FIRInt32Value *)int32 NS_SWIFT_NAME(maximum(_:));

/**
 * Returns a special value that can be used with `setData()` or `updateData()` that tells the server
 * to set the field to the maximum of its current value and the given 128-bit decimal floating point
 * value.
 *
 * If the field is not a number, or if the field does not yet exist, the transformation will set the
 * field to the given value.
 *
 * @param decimal128 The 128-bit decimal floating point value to compare.
 * @return The `FieldValue` sentinel for use in a call to `setData()` or `updateData()`.
 */
+ (instancetype)fieldValueForDecimal128Maximum:(FIRDecimal128Value *)decimal128
    NS_SWIFT_NAME(maximum(_:));

/**
 * Creates a new `VectorValue` constructed with a copy of the given array of NSNumbers.
 *
 * @param array Create a `VectorValue` instance with a copy of this array of NSNumbers.
 * @return A new `VectorValue` constructed with a copy of the given array of NSNumbers.
 */
+ (FIRVectorValue *)vectorWithArray:(NSArray<NSNumber *> *)array NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
