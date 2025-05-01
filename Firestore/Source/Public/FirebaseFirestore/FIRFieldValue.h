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
@class FIRVectorValue;
@class FIRMinKey;
@class FIRMaxKey;
@class FIRRegexValue;
@class FIRInt32Value;
@class FIRBsonObjectId;
@class FIRBsonTimestamp;
@class FIRBsonBinaryData;

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
 * Creates a new `VectorValue` constructed with a copy of the given array of NSNumbers.
 *
 * @param array Create a `VectorValue` instance with a copy of this array of NSNumbers.
 * @return A new `VectorValue` constructed with a copy of the given array of NSNumbers.
 */
+ (FIRVectorValue *)vectorWithArray:(NSArray<NSNumber *> *)array NS_REFINED_FOR_SWIFT;

/**
 * Returns a `MinKey` value instance.
 *
 * @return A `MinKey` value instance.
 */
+ (nonnull FIRMinKey *)minKey NS_REFINED_FOR_SWIFT;

/**
 * Returns a `MaxKey` value instance.
 *
 * @return A `MaxKey` value instance.
 */
+ (nonnull FIRMaxKey *)maxKey NS_REFINED_FOR_SWIFT;

/**
 * Creates a new `RegexValue` constructed with the given pattern and options.
 *
 * @param pattern The pattern to use for the regular expression.
 * @param options The options to use for the regular expression.
 * @return A new `RegexValue` constructed with the given pattern and options.
 */
+ (nonnull FIRRegexValue *)regexWithPattern:(nonnull NSString *)pattern
                                    options:(nonnull NSString *)options NS_REFINED_FOR_SWIFT;

/**
 * Creates a new `Int32Value` with the given signed 32-bit integer value.
 *
 * @param value The 32-bit number to be used for constructing the Int32Value.
 * @return A new `Int32Value` instance.
 */
+ (nonnull FIRInt32Value *)int32WithValue:(int)value NS_REFINED_FOR_SWIFT;

/**
 * Creates a new `BsonObjectId` with the given value.
 *
 * @param value The 24-character hex string representation of the ObjectId.
 * @return A new `BsonObjectId` instance constructed with the given value.
 */
+ (nonnull FIRBsonObjectId *)bsonObjectIdWithValue:(nonnull NSString *)value NS_REFINED_FOR_SWIFT;

/**
 * Creates a new `BsonTimestamp` with the given values.
 *
 * @param seconds The underlying unsigned 32-bit integer for seconds.
 * @param increment The underlying unsigned 32-bit integer for increment.
 * @return A new `BsonTimestamp` instance constructed with the given values.
 */
+ (nonnull FIRBsonTimestamp *)bsonTimestampWithSeconds:(uint32_t)seconds
                                             increment:(uint32_t)increment NS_REFINED_FOR_SWIFT;

/**
 * Creates a new `BsonBinaryData` object with the given subtype and data.
 *
 * @param subtype An 8-bit unsigned integer denoting the subtype of the data.
 * @param data The binary data.
 * @return A new `BsonBinaryData` instance constructed with the given values.
 */
+ (nonnull FIRBsonBinaryData *)bsonBinaryDataWithSubtype:(uint8_t)subtype
                                                    data:(nonnull NSData *)data
    NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
