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

#import "FIRFieldValue.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRFieldValue (Internal)
/**
 * The method name (e.g. "FieldValue.delete()") that was used to create this FIRFieldValue
 * instance, for use in error messages, etc.
 */
@property(nonatomic, strong, readonly) NSString *methodName;
@end

/**
 * FIRFieldValue class for field deletes. Exposed internally so code can do isKindOfClass checks on
 * it.
 */
@interface FSTDeleteFieldValue : FIRFieldValue
- (instancetype)init NS_UNAVAILABLE;
@end

/**
 * FIRFieldValue class for server timestamps. Exposed internally so code can do isKindOfClass checks
 * on it.
 */
@interface FSTServerTimestampFieldValue : FIRFieldValue
- (instancetype)init NS_UNAVAILABLE;
@end

/** FIRFieldValue class for array unions. */
@interface FSTArrayUnionFieldValue : FIRFieldValue
- (instancetype)init NS_UNAVAILABLE;
@property(strong, nonatomic, readonly) NSArray<id> *elements;
@end

/** FIRFieldValue class for array removes. */
@interface FSTArrayRemoveFieldValue : FIRFieldValue
- (instancetype)init NS_UNAVAILABLE;
@property(strong, nonatomic, readonly) NSArray<id> *elements;
@end

// TODO(array-features): Move to FIRFieldValue.h once backend support lands.
@interface FIRFieldValue ()

/**
 * Returns a special value that can be used with setData() or updateData() that tells the server to
 * union the given elements with any array value that already exists on the server. Each
 * specified element that doesn't already exist in the array will be added to the end. If the
 * field being modified is not already an array it will be overwritten with an array containing
 * exactly the specified elements.
 *
 * @param elements The elements to union into the array.
 * @return The FieldValue sentinel for use in a call to setData() or updateData().
 */
+ (instancetype)fieldValueForArrayUnion:(NSArray<id> *)elements NS_SWIFT_NAME(arrayUnion(_:));

/**
 * Returns a special value that can be used with setData() or updateData() that tells the server to
 * remove the given elements from any array value that already exists on the server. All
 * instances of each element specified will be removed from the array. If the field being
 * modified is not already an array it will be overwritten with an empty array.
 *
 * @param elements The elements to remove from the array.
 * @return The FieldValue sentinel for use in a call to setData() or updateData().
 */
+ (instancetype)fieldValueForArrayRemove:(NSArray<id> *)elements NS_SWIFT_NAME(arrayRemove(_:));

@end

NS_ASSUME_NONNULL_END
