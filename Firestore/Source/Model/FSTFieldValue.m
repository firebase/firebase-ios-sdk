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

#import "Firestore/Source/Model/FSTFieldValue.h"

#import "Firestore/Source/API/FIRGeoPoint+Internal.h"
#import "Firestore/Source/API/FIRSnapshotOptions+Internal.h"
#import "Firestore/Source/Core/FSTTimestamp.h"
#import "Firestore/Source/Model/FSTDatabaseID.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTClasses.h"
#import "Firestore/Source/Util/FSTComparison.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTFieldValueOptions

@implementation FSTFieldValueOptions

+ (instancetype)optionsForSnapshotOptions:(FIRSnapshotOptions *)options {
  if (options.serverTimestampBehavior == FSTServerTimestampBehaviorNone) {
    static FSTFieldValueOptions *defaultInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
      defaultInstance = [[FSTFieldValueOptions alloc]
          initWithServerTimestampBehavior:FSTServerTimestampBehaviorNone];
    });
    return defaultInstance;
  } else {
    return [[FSTFieldValueOptions alloc]
        initWithServerTimestampBehavior:options.serverTimestampBehavior];
  }
}

- (instancetype)initWithServerTimestampBehavior:
    (FSTServerTimestampBehavior)serverTimestampBehavior {
  self = [super init];

  if (self) {
    _serverTimestampBehavior = serverTimestampBehavior;
  }
  return self;
}

@end

#pragma mark - FSTFieldValue

@interface FSTFieldValue ()
- (NSComparisonResult)defaultCompare:(FSTFieldValue *)other;
@end

@implementation FSTFieldValue

- (FSTTypeOrder)typeOrder {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (id)value {
  return [self valueWithOptions:[FSTFieldValueOptions
                                    optionsForSnapshotOptions:[FIRSnapshotOptions defaultOptions]]];
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (BOOL)isEqual:(id)other {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (NSUInteger)hash {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (NSString *)description {
  return [[self value] description];
}

- (NSComparisonResult)defaultCompare:(FSTFieldValue *)other {
  if (self.typeOrder > other.typeOrder) {
    return NSOrderedDescending;
  } else {
    FSTAssert(self.typeOrder < other.typeOrder,
              @"defaultCompare should not be used for values of same type.");
    return NSOrderedAscending;
  }
}

@end

#pragma mark - FSTNullValue

@implementation FSTNullValue

+ (instancetype)nullValue {
  static FSTNullValue *sharedInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[FSTNullValue alloc] init];
  });
  return sharedInstance;
}

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderNull;
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  return [NSNull null];
}

- (BOOL)isEqual:(id)other {
  return [other isKindOfClass:[self class]];
}

- (NSUInteger)hash {
  return 47;
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if ([other isKindOfClass:[self class]]) {
    return NSOrderedSame;
  } else {
    return [self defaultCompare:other];
  }
}

@end

#pragma mark - FSTBooleanValue

@interface FSTBooleanValue ()
@property(nonatomic, assign, readonly) BOOL internalValue;
@end

@implementation FSTBooleanValue

+ (instancetype)trueValue {
  static FSTBooleanValue *sharedInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[FSTBooleanValue alloc] initWithValue:YES];
  });
  return sharedInstance;
}

+ (instancetype)falseValue {
  static FSTBooleanValue *sharedInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[FSTBooleanValue alloc] initWithValue:NO];
  });
  return sharedInstance;
}

+ (instancetype)booleanValue:(BOOL)value {
  return value ? [FSTBooleanValue trueValue] : [FSTBooleanValue falseValue];
}

- (id)initWithValue:(BOOL)value {
  self = [super init];
  if (self) {
    _internalValue = value;
  }
  return self;
}

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderBoolean;
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  return self.internalValue ? @YES : @NO;
}

- (BOOL)isEqual:(id)other {
  // Since we create shared instances for true / false, we can use reference equality.
  return self == other;
}

- (NSUInteger)hash {
  return self.internalValue ? 1231 : 1237;
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if ([other isKindOfClass:[FSTBooleanValue class]]) {
    return FSTCompareBools(self.internalValue, ((FSTBooleanValue *)other).internalValue);
  } else {
    return [self defaultCompare:other];
  }
}

@end

#pragma mark - FSTNumberValue

@implementation FSTNumberValue

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderNumber;
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if (![other isKindOfClass:[FSTNumberValue class]]) {
    return [self defaultCompare:other];
  } else {
    if ([self isKindOfClass:[FSTDoubleValue class]]) {
      double thisDouble = ((FSTDoubleValue *)self).internalValue;
      if ([other isKindOfClass:[FSTDoubleValue class]]) {
        return FSTCompareDoubles(thisDouble, ((FSTDoubleValue *)other).internalValue);
      } else {
        FSTAssert([other isKindOfClass:[FSTIntegerValue class]], @"Unknown number value: %@",
                  other);
        return FSTCompareMixed(thisDouble, ((FSTIntegerValue *)other).internalValue);
      }
    } else {
      int64_t thisInt = ((FSTIntegerValue *)self).internalValue;
      if ([other isKindOfClass:[FSTIntegerValue class]]) {
        return FSTCompareInt64s(thisInt, ((FSTIntegerValue *)other).internalValue);
      } else {
        FSTAssert([other isKindOfClass:[FSTDoubleValue class]], @"Unknown number value: %@", other);
        return -1 * FSTCompareMixed(((FSTDoubleValue *)other).internalValue, thisInt);
      }
    }
  }
}

@end

#pragma mark - FSTIntegerValue

@interface FSTIntegerValue ()
@property(nonatomic, assign, readonly) int64_t internalValue;
@end

@implementation FSTIntegerValue

+ (instancetype)integerValue:(int64_t)value {
  return [[FSTIntegerValue alloc] initWithValue:value];
}

- (id)initWithValue:(int64_t)value {
  self = [super init];
  if (self) {
    _internalValue = value;
  }
  return self;
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  return @(self.internalValue);
}

- (BOOL)isEqual:(id)other {
  // NOTE: DoubleValue and LongValue instances may compare: the same, but that doesn't make them
  // equal via isEqual:
  return [other isKindOfClass:[FSTIntegerValue class]] &&
         self.internalValue == ((FSTIntegerValue *)other).internalValue;
}

- (NSUInteger)hash {
  return (((NSUInteger)self.internalValue) ^ (NSUInteger)(self.internalValue >> 32));
}

// NOTE: compare: is implemented in NumberValue.

@end

#pragma mark - FSTDoubleValue

@interface FSTDoubleValue ()
@property(nonatomic, assign, readonly) double internalValue;
@end

@implementation FSTDoubleValue

+ (instancetype)doubleValue:(double)value {
  // Normalize NaNs to match the behavior on the backend (which uses Double.doubletoLongBits()).
  if (isnan(value)) {
    return [FSTDoubleValue nanValue];
  }
  return [[FSTDoubleValue alloc] initWithValue:value];
}

+ (instancetype)nanValue {
  static FSTDoubleValue *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FSTDoubleValue alloc] initWithValue:NAN];
  });
  return sharedInstance;
}

- (id)initWithValue:(double)value {
  self = [super init];
  if (self) {
    _internalValue = value;
  }
  return self;
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  return @(self.internalValue);
}

- (BOOL)isEqual:(id)other {
  // NOTE: DoubleValue and LongValue instances may compare: the same, but that doesn't make them
  // equal via isEqual:

  // NOTE: isEqual: should compare NaN equal to itself and -0.0 not equal to 0.0.

  return [other isKindOfClass:[FSTDoubleValue class]] &&
         FSTDoubleBitwiseEquals(self.internalValue, ((FSTDoubleValue *)other).internalValue);
}

- (NSUInteger)hash {
  return FSTDoubleBitwiseHash(self.internalValue);
}

// NOTE: compare: is implemented in NumberValue.

@end

#pragma mark - FSTStringValue

@interface FSTStringValue ()
@property(nonatomic, copy, readonly) NSString *internalValue;
@end

// TODO(b/37267885): Add truncation support
@implementation FSTStringValue

+ (instancetype)stringValue:(NSString *)value {
  return [[FSTStringValue alloc] initWithValue:value];
}

- (id)initWithValue:(NSString *)value {
  self = [super init];
  if (self) {
    _internalValue = [value copy];
  }
  return self;
}

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderString;
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  return self.internalValue;
}

- (BOOL)isEqual:(id)other {
  return [other isKindOfClass:[FSTStringValue class]] &&
         [self.internalValue isEqualToString:((FSTStringValue *)other).internalValue];
}

- (NSUInteger)hash {
  return self.internalValue ? 1 : 0;
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if ([other isKindOfClass:[FSTStringValue class]]) {
    return FSTCompareStrings(self.internalValue, ((FSTStringValue *)other).internalValue);
  } else {
    return [self defaultCompare:other];
  }
}

@end

#pragma mark - FSTTimestampValue

@interface FSTTimestampValue ()
@property(nonatomic, strong, readonly) FSTTimestamp *internalValue;
@end

@implementation FSTTimestampValue

+ (instancetype)timestampValue:(FSTTimestamp *)value {
  return [[FSTTimestampValue alloc] initWithValue:value];
}

- (id)initWithValue:(FSTTimestamp *)value {
  self = [super init];
  if (self) {
    _internalValue = value;  // FSTTimestamp is immutable.
  }
  return self;
}

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderTimestamp;
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  // For developers, we expose Timestamps as Dates.
  return self.internalValue.approximateDateValue;
}

- (BOOL)isEqual:(id)other {
  return [other isKindOfClass:[FSTTimestampValue class]] &&
         [self.internalValue isEqual:((FSTTimestampValue *)other).internalValue];
}

- (NSUInteger)hash {
  return [self.internalValue hash];
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if ([other isKindOfClass:[FSTTimestampValue class]]) {
    return [self.internalValue compare:((FSTTimestampValue *)other).internalValue];
  } else if ([other isKindOfClass:[FSTServerTimestampValue class]]) {
    // Concrete timestamps come before server timestamps.
    return NSOrderedAscending;
  } else {
    return [self defaultCompare:other];
  }
}

@end

#pragma mark - FSTServerTimestampValue

@implementation FSTServerTimestampValue

+ (instancetype)serverTimestampValueWithLocalWriteTime:(FSTTimestamp *)localWriteTime
                                         previousValue:(nullable FSTFieldValue *)previousValue {
  return [[FSTServerTimestampValue alloc] initWithLocalWriteTime:localWriteTime
                                                   previousValue:previousValue];
}

- (id)initWithLocalWriteTime:(FSTTimestamp *)localWriteTime
               previousValue:(nullable FSTFieldValue *)previousValue {
  self = [super init];
  if (self) {
    _localWriteTime = localWriteTime;
    _previousValue = previousValue;
  }
  return self;
}

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderTimestamp;
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  switch (options.serverTimestampBehavior) {
    case FSTServerTimestampBehaviorNone:
      return [NSNull null];
    case FSTServerTimestampBehaviorEstimate:
      return [self.localWriteTime approximateDateValue];
    case FSTServerTimestampBehaviorPrevious:
      return self.previousValue ? [self.previousValue valueWithOptions:options] : [NSNull null];
    default:
      FSTFail(@"Unexpected server timestamp option: %d", (int)options.serverTimestampBehavior);
  }
}

- (BOOL)isEqual:(id)other {
  return [other isKindOfClass:[FSTServerTimestampValue class]] &&
         [self.localWriteTime isEqual:((FSTServerTimestampValue *)other).localWriteTime];
}

- (NSUInteger)hash {
  return [self.localWriteTime hash];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<ServerTimestamp localTime=%@>", self.localWriteTime];
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if ([other isKindOfClass:[FSTServerTimestampValue class]]) {
    return [self.localWriteTime compare:((FSTServerTimestampValue *)other).localWriteTime];
  } else if ([other isKindOfClass:[FSTTimestampValue class]]) {
    // Server timestamps come after all concrete timestamps.
    return NSOrderedDescending;
  } else {
    return [self defaultCompare:other];
  }
}

@end

#pragma mark - FSTGeoPointValue

@interface FSTGeoPointValue ()
@property(nonatomic, strong, readonly) FIRGeoPoint *internalValue;
@end

@implementation FSTGeoPointValue

+ (instancetype)geoPointValue:(FIRGeoPoint *)value {
  return [[FSTGeoPointValue alloc] initWithValue:value];
}

- (id)initWithValue:(FIRGeoPoint *)value {
  self = [super init];
  if (self) {
    _internalValue = value;  // FIRGeoPoint is immutable.
  }
  return self;
}

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderGeoPoint;
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  return self.internalValue;
}

- (BOOL)isEqual:(id)other {
  return [other isKindOfClass:[FSTGeoPointValue class]] &&
         [self.internalValue isEqual:((FSTGeoPointValue *)other).internalValue];
}

- (NSUInteger)hash {
  return [self.internalValue hash];
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if ([other isKindOfClass:[FSTGeoPointValue class]]) {
    return [self.internalValue compare:((FSTGeoPointValue *)other).internalValue];
  } else {
    return [self defaultCompare:other];
  }
}

@end

#pragma mark - FSTBlobValue

@interface FSTBlobValue ()
@property(nonatomic, copy, readonly) NSData *internalValue;
@end

// TODO(b/37267885): Add truncation support
@implementation FSTBlobValue

+ (instancetype)blobValue:(NSData *)value {
  return [[FSTBlobValue alloc] initWithValue:value];
}

- (id)initWithValue:(NSData *)value {
  self = [super init];
  if (self) {
    _internalValue = [value copy];
  }
  return self;
}

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderBlob;
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  return self.internalValue;
}

- (BOOL)isEqual:(id)other {
  return [other isKindOfClass:[FSTBlobValue class]] &&
         [self.internalValue isEqual:((FSTBlobValue *)other).internalValue];
}

- (NSUInteger)hash {
  return [self.internalValue hash];
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if ([other isKindOfClass:[FSTBlobValue class]]) {
    return FSTCompareBytes(self.internalValue, ((FSTBlobValue *)other).internalValue);
  } else {
    return [self defaultCompare:other];
  }
}

@end

#pragma mark - FSTReferenceValue

@interface FSTReferenceValue ()
@property(nonatomic, strong, readonly) FSTDocumentKey *key;
@end

@implementation FSTReferenceValue

+ (instancetype)referenceValue:(FSTDocumentKey *)value databaseID:(FSTDatabaseID *)databaseID {
  return [[FSTReferenceValue alloc] initWithValue:value databaseID:databaseID];
}

- (id)initWithValue:(FSTDocumentKey *)value databaseID:(FSTDatabaseID *)databaseID {
  self = [super init];
  if (self) {
    _key = value;
    _databaseID = databaseID;
  }
  return self;
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  return self.key;
}

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderReference;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTReferenceValue class]]) {
    return NO;
  }

  FSTReferenceValue *otherRef = (FSTReferenceValue *)other;
  return [self.key isEqualToKey:otherRef.key] &&
         [self.databaseID isEqualToDatabaseId:otherRef.databaseID];
}

- (NSUInteger)hash {
  NSUInteger result = [self.databaseID hash];
  result = 31 * result + [self.key hash];
  return result;
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if ([other isKindOfClass:[FSTReferenceValue class]]) {
    FSTReferenceValue *ref = (FSTReferenceValue *)other;
    NSComparisonResult cmp = [self.databaseID compare:ref.databaseID];
    return cmp != NSOrderedSame ? cmp : [self.key compare:ref.key];
  } else {
    return [self defaultCompare:other];
  }
}

@end

#pragma mark - FSTObjectValue

@interface FSTObjectValue ()
@property(nonatomic, strong, readonly)
    FSTImmutableSortedDictionary<NSString *, FSTFieldValue *> *internalValue;
@end

@implementation FSTObjectValue

+ (instancetype)objectValue {
  static FSTObjectValue *sharedEmptyInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    FSTImmutableSortedDictionary<NSString *, FSTFieldValue *> *empty =
        [FSTImmutableSortedDictionary dictionaryWithComparator:FSTStringComparator];
    sharedEmptyInstance = [[FSTObjectValue alloc] initWithImmutableDictionary:empty];
  });
  return sharedEmptyInstance;
}

- (instancetype)initWithImmutableDictionary:
    (FSTImmutableSortedDictionary<NSString *, FSTFieldValue *> *)value {
  self = [super init];
  if (self) {
    _internalValue = value;  // FSTImmutableSortedDictionary is immutable.
  }
  return self;
}

- (id)initWithDictionary:(NSDictionary<NSString *, FSTFieldValue *> *)value {
  FSTImmutableSortedDictionary<NSString *, FSTFieldValue *> *dictionary =
      [FSTImmutableSortedDictionary dictionaryWithDictionary:value comparator:FSTStringComparator];
  return [self initWithImmutableDictionary:dictionary];
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  [self.internalValue
      enumerateKeysAndObjectsUsingBlock:^(NSString *key, FSTFieldValue *obj, BOOL *stop) {
        result[key] = [obj valueWithOptions:options];
      }];
  return result;
}

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderObject;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTObjectValue class]]) {
    return NO;
  }

  FSTObjectValue *otherObj = other;
  return [self.internalValue isEqual:otherObj.internalValue];
}

- (NSUInteger)hash {
  return [self.internalValue hash];
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if ([other isKindOfClass:[FSTObjectValue class]]) {
    FSTImmutableSortedDictionary *selfDict = self.internalValue;
    FSTImmutableSortedDictionary *otherDict = ((FSTObjectValue *)other).internalValue;
    NSEnumerator *enumerator1 = [selfDict keyEnumerator];
    NSEnumerator *enumerator2 = [otherDict keyEnumerator];
    NSString *key1 = [enumerator1 nextObject];
    NSString *key2 = [enumerator2 nextObject];
    while (key1 && key2) {
      NSComparisonResult keyCompare = [key1 compare:key2];
      if (keyCompare != NSOrderedSame) {
        return keyCompare;
      }
      NSComparisonResult valueCompare = [selfDict[key1] compare:otherDict[key2]];
      if (valueCompare != NSOrderedSame) {
        return valueCompare;
      }
      key1 = [enumerator1 nextObject];
      key2 = [enumerator2 nextObject];
    }
    // Only equal if both enumerators are exhausted.
    return FSTCompareBools(key1 != nil, key2 != nil);
  } else {
    return [self defaultCompare:other];
  }
}

- (nullable FSTFieldValue *)valueForPath:(FSTFieldPath *)fieldPath {
  FSTFieldValue *value = self;
  for (int i = 0, max = fieldPath.length; value && i < max; i++) {
    if (![value isMemberOfClass:[FSTObjectValue class]]) {
      return nil;
    }

    NSString *fieldName = fieldPath[i];
    value = ((FSTObjectValue *)value).internalValue[fieldName];
  }

  return value;
}

- (FSTObjectValue *)objectBySettingValue:(FSTFieldValue *)value forPath:(FSTFieldPath *)fieldPath {
  FSTAssert([fieldPath length] > 0, @"Cannot set value with an empty path");

  NSString *childName = [fieldPath firstSegment];
  if ([fieldPath length] == 1) {
    // Recursive base case:
    return [self objectBySettingValue:value forField:childName];
  } else {
    // Nested path. Recursively generate a new sub-object and then wrap a new FSTObjectValue around
    // the result.
    FSTFieldValue *child = [_internalValue objectForKey:childName];
    FSTObjectValue *childObject;
    if ([child isKindOfClass:[FSTObjectValue class]]) {
      childObject = (FSTObjectValue *)child;
    } else {
      // If the child is not found or is a primitive type, pretend as if an empty object lived
      // there.
      childObject = [FSTObjectValue objectValue];
    }
    FSTFieldValue *newChild =
        [childObject objectBySettingValue:value forPath:[fieldPath pathByRemovingFirstSegment]];
    return [self objectBySettingValue:newChild forField:childName];
  }
}

- (FSTObjectValue *)objectByDeletingPath:(FSTFieldPath *)fieldPath {
  FSTAssert([fieldPath length] > 0, @"Cannot delete an empty path");
  NSString *childName = [fieldPath firstSegment];
  if ([fieldPath length] == 1) {
    return [[FSTObjectValue alloc]
        initWithImmutableDictionary:[_internalValue dictionaryByRemovingObjectForKey:childName]];
  } else {
    FSTFieldValue *child = _internalValue[childName];
    if ([child isKindOfClass:[FSTObjectValue class]]) {
      FSTObjectValue *newChild =
          [((FSTObjectValue *)child) objectByDeletingPath:[fieldPath pathByRemovingFirstSegment]];
      return [self objectBySettingValue:newChild forField:childName];
    } else {
      // If the child is not found or is a primitive type, make no modifications
      return self;
    }
  }
}

- (FSTObjectValue *)objectBySettingValue:(FSTFieldValue *)value forField:(NSString *)field {
  return [[FSTObjectValue alloc]
      initWithImmutableDictionary:[_internalValue dictionaryBySettingObject:value forKey:field]];
}

@end

@interface FSTArrayValue ()
@property(nonatomic, strong, readonly) NSArray<FSTFieldValue *> *internalValue;
@end

#pragma mark - FSTArrayValue

@implementation FSTArrayValue

- (id)initWithValueNoCopy:(NSArray<FSTFieldValue *> *)value {
  self = [super init];
  if (self) {
    // Does not copy, assumes the caller has already copied.
    _internalValue = value;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[self class]]) {
    return NO;
  }

  // NSArray's isEqual does the right thing for our purposes.
  FSTArrayValue *otherArray = other;
  return [self.internalValue isEqual:otherArray.internalValue];
}

- (NSUInteger)hash {
  return [self.internalValue hash];
}

- (id)valueWithOptions:(FSTFieldValueOptions *)options {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:_internalValue.count];
  [self.internalValue enumerateObjectsUsingBlock:^(FSTFieldValue *obj, NSUInteger idx, BOOL *stop) {
    [result addObject:[obj value]];
  }];
  return result;
}

- (FSTTypeOrder)typeOrder {
  return FSTTypeOrderArray;
}

- (NSComparisonResult)compare:(FSTFieldValue *)other {
  if ([other isKindOfClass:[FSTArrayValue class]]) {
    NSArray<FSTFieldValue *> *selfArray = self.internalValue;
    NSArray<FSTFieldValue *> *otherArray = ((FSTArrayValue *)other).internalValue;
    NSUInteger minLength = MIN(selfArray.count, otherArray.count);
    for (NSUInteger i = 0; i < minLength; i++) {
      NSComparisonResult cmp = [selfArray[i] compare:otherArray[i]];
      if (cmp != NSOrderedSame) {
        return cmp;
      }
    }
    return FSTCompareUIntegers(selfArray.count, otherArray.count);
  } else {
    return [self defaultCompare:other];
  }
}

@end

NS_ASSUME_NONNULL_END
