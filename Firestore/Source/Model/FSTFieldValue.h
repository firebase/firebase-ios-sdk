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

#import "FSTImmutableSortedDictionary.h"

@class FSTDatabaseID;
@class FSTDocumentKey;
@class FSTFieldPath;
@class FSTTimestamp;
@class FIRGeoPoint;

NS_ASSUME_NONNULL_BEGIN

/** The order of types in Firestore; this order is defined by the backend. */
typedef NS_ENUM(NSInteger, FSTTypeOrder) {
  FSTTypeOrderNull,
  FSTTypeOrderBoolean,
  FSTTypeOrderNumber,
  FSTTypeOrderTimestamp,
  FSTTypeOrderString,
  FSTTypeOrderBlob,
  FSTTypeOrderReference,
  FSTTypeOrderGeoPoint,
  FSTTypeOrderArray,
  FSTTypeOrderObject,
};

/**
 * Abstract base class representing an immutable data value as stored in Firestore. FSTFieldValue
 * represents all the different kinds of values that can be stored in fields in a document.
 *
 * Supported types are:
 *  - Null
 *  - Boolean
 *  - Long
 *  - Double
 *  - Timestamp
 *  - ServerTimestamp (a sentinel used in uncommitted writes)
 *  - String
 *  - Binary
 *  - (Document) References
 *  - GeoPoint
 *  - Array
 *  - Object
 */
@interface FSTFieldValue : NSObject

/** Returns the FSTTypeOrder for this value. */
- (FSTTypeOrder)typeOrder;

/**
 * Converts an FSTFieldValue into the value that users will see in document snapshots.
 *
 * TODO(mikelehen): This conversion should probably happen at the API level and right now `value` is
 * used inappropriately in the serializer implementation, etc.  We need to do some reworking.
 */
- (id)value;

/** Compares against another FSTFieldValue. */
- (NSComparisonResult)compare:(FSTFieldValue *)other;

@end

/**
 * A null value stored in Firestore. The |value| of a FSTNullValue is [NSNull null].
 */
@interface FSTNullValue : FSTFieldValue
+ (instancetype)nullValue;
- (id)value;
@end

/**
 * A boolean value stored in Firestore.
 */
@interface FSTBooleanValue : FSTFieldValue
+ (instancetype)trueValue;
+ (instancetype)falseValue;
+ (instancetype)booleanValue:(BOOL)value;
- (NSNumber *)value;
@end

/**
 * Base class inherited from by FSTIntegerValue and FSTDoubleValue. It implements proper number
 * comparisons between the two types.
 */
@interface FSTNumberValue : FSTFieldValue
@end

/**
 * An integer value stored in Firestore.
 */
@interface FSTIntegerValue : FSTNumberValue
+ (instancetype)integerValue:(int64_t)value;
- (NSNumber *)value;
- (int64_t)internalValue;
@end

/**
 * A double-precision floating point number stored in Firestore.
 */
@interface FSTDoubleValue : FSTNumberValue
+ (instancetype)doubleValue:(double)value;
+ (instancetype)nanValue;
- (NSNumber *)value;
- (double)internalValue;
@end

/**
 * A string stored in Firestore.
 */
@interface FSTStringValue : FSTFieldValue
+ (instancetype)stringValue:(NSString *)value;
- (NSString *)value;
@end

/**
 * A timestamp value stored in Firestore.
 */
@interface FSTTimestampValue : FSTFieldValue
+ (instancetype)timestampValue:(FSTTimestamp *)value;
- (NSDate *)value;
- (FSTTimestamp *)internalValue;
@end

/**
 * Represents a locally-applied Server Timestamp.
 *
 * Notes:
 * - FSTServerTimestampValue instances are created as the result of applying an FSTTransformMutation
 *   (see [FSTTransformMutation applyTo]). They can only exist in the local view of a document.
 *   Therefore they do not need to be parsed or serialized.
 * - When evaluated locally (e.g. via FSTDocumentSnapshot data), they evaluate to NSNull (at least
 *   for now, see b/62064202).
 * - They sort after all FSTTimestampValues. With respect to other FSTServerTimestampValues, they
 *   sort by their localWriteTime.
 */
@interface FSTServerTimestampValue : FSTFieldValue
+ (instancetype)serverTimestampValueWithLocalWriteTime:(FSTTimestamp *)localWriteTime;
- (NSNull *)value;
@property(nonatomic, strong, readonly) FSTTimestamp *localWriteTime;
@end

/**
 * A geo point value stored in Firestore.
 */
@interface FSTGeoPointValue : FSTFieldValue
+ (instancetype)geoPointValue:(FIRGeoPoint *)value;
- (FIRGeoPoint *)value;
@end

/**
 * A blob value stored in Firestore.
 */
@interface FSTBlobValue : FSTFieldValue
+ (instancetype)blobValue:(NSData *)value;
- (NSData *)value;
@end

/**
 * A reference value stored in Firestore.
 */
@interface FSTReferenceValue : FSTFieldValue
+ (instancetype)referenceValue:(FSTDocumentKey *)value databaseID:(FSTDatabaseID *)databaseID;
- (FSTDocumentKey *)value;
@property(nonatomic, strong, readonly) FSTDatabaseID *databaseID;
@end

/**
 * A structured object value stored in Firestore.
 */
@interface FSTObjectValue : FSTFieldValue
/** Returns an empty FSTObjectValue. */
+ (instancetype)objectValue;

/**
 * Initializes this FSTObjectValue with the given dictionary.
 */
- (instancetype)initWithDictionary:(NSDictionary<NSString *, FSTFieldValue *> *)value;

/**
 * Initializes this FSTObjectValue with the given immutable dictionary.
 */
- (instancetype)initWithImmutableDictionary:
    (FSTImmutableSortedDictionary<NSString *, FSTFieldValue *> *)value NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (NSDictionary<NSString *, id> *)value;
- (FSTImmutableSortedDictionary<NSString *, FSTFieldValue *> *)internalValue;

/** Returns the value at the given path if it exists. Returns nil otherwise. */
- (nullable FSTFieldValue *)valueForPath:(FSTFieldPath *)fieldPath;

/**
 * Returns a new object where the field at the named path has its value set to the given value.
 * This object remains unmodified.
 */
- (FSTObjectValue *)objectBySettingValue:(FSTFieldValue *)value forPath:(FSTFieldPath *)fieldPath;

/**
 * Returns a new object where the field at the named path has been removed. If any segment of the
 * path does not exist within this object's structure, no change is performed.
 */
- (FSTObjectValue *)objectByDeletingPath:(FSTFieldPath *)fieldPath;
@end

/**
 * An array value stored in Firestore.
 */
@interface FSTArrayValue : FSTFieldValue

/**
 * Initializes this instance with the given array of wrapped values.
 *
 * @param value An immutable array of FSTFieldValue objects. Caller is responsible for copying the
 *     value or releasing all references.
 */
- (instancetype)initWithValueNoCopy:(NSArray<FSTFieldValue *> *)value NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (NSArray<id> *)value;
- (NSArray<FSTFieldValue *> *)internalValue;

@end

NS_ASSUME_NONNULL_END
