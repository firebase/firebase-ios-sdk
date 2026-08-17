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

#import "Firestore/Source/API/FIRFieldValue+Internal.h"
#import "Firestore/Source/Public/FirebaseFirestore/FIRDecimal128Value.h"
#import "Firestore/Source/Public/FirebaseFirestore/FIRInt32Value.h"
#import "Firestore/Source/Public/FirebaseFirestore/FIRVectorValue.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRFieldValue ()
- (instancetype)initPrivate NS_DESIGNATED_INITIALIZER;
@end

#pragma mark - FSTDeleteFieldValue

@interface FSTDeleteFieldValue ()
/** Returns a single shared instance of the class. */
+ (instancetype)deleteFieldValue;
@end

@implementation FSTDeleteFieldValue

- (instancetype)initPrivate {
  self = [super initPrivate];
  return self;
}

+ (instancetype)deleteFieldValue {
  static FSTDeleteFieldValue *sharedInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[FSTDeleteFieldValue alloc] initPrivate];
  });
  return sharedInstance;
}

- (NSString *)methodName {
  return @"FieldValue.delete()";
}

@end

#pragma mark - FSTServerTimestampFieldValue

@interface FSTServerTimestampFieldValue ()
/** Returns a single shared instance of the class. */
+ (instancetype)serverTimestampFieldValue;
@end

@implementation FSTServerTimestampFieldValue

- (instancetype)initPrivate {
  self = [super initPrivate];
  return self;
}

+ (instancetype)serverTimestampFieldValue {
  static FSTServerTimestampFieldValue *sharedInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[FSTServerTimestampFieldValue alloc] initPrivate];
  });
  return sharedInstance;
}

- (NSString *)methodName {
  return @"FieldValue.serverTimestamp()";
}

@end

#pragma mark - FSTArrayUnionFieldValue

@interface FSTArrayUnionFieldValue ()
- (instancetype)initWithElements:(NSArray<id> *)elements;
@end

@implementation FSTArrayUnionFieldValue
- (instancetype)initWithElements:(NSArray<id> *)elements {
  if (self = [super initPrivate]) {
    _elements = elements;
  }
  return self;
}

- (NSString *)methodName {
  return @"FieldValue.arrayUnion()";
}

- (BOOL)isEqual:(nullable id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTArrayUnionFieldValue class]]) {
    return NO;
  }
  FSTArrayUnionFieldValue *other = (FSTArrayUnionFieldValue *)object;
  return [self.elements isEqualToArray:other.elements];
}

- (NSUInteger)hash {
  return [self.elements hash];
}

@end

#pragma mark - FSTArrayRemoveFieldValue

@interface FSTArrayRemoveFieldValue ()
- (instancetype)initWithElements:(NSArray<id> *)elements;
@end

@implementation FSTArrayRemoveFieldValue
- (instancetype)initWithElements:(NSArray<id> *)elements {
  if (self = [super initPrivate]) {
    _elements = elements;
  }
  return self;
}

- (NSString *)methodName {
  return @"FieldValue.arrayRemove()";
}

- (BOOL)isEqual:(nullable id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTArrayRemoveFieldValue class]]) {
    return NO;
  }
  FSTArrayRemoveFieldValue *other = (FSTArrayRemoveFieldValue *)object;
  return [self.elements isEqualToArray:other.elements];
}

- (NSUInteger)hash {
  return [self.elements hash];
}

@end

#pragma mark - FSTNumericIncrementFieldValue

/* FieldValue class for increment() transforms. */
@interface FSTNumericIncrementFieldValue ()
- (instancetype)initWithOperand:(id)operand;
@end

@implementation FSTNumericIncrementFieldValue
- (instancetype)initWithOperand:(id)operand {
  if (self = [super initPrivate]) {
    _operand = operand;
  }
  return self;
}

- (NSString *)methodName {
  return @"FieldValue.increment()";
}

- (BOOL)isEqual:(nullable id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTNumericIncrementFieldValue class]]) {
    return NO;
  }
  FSTNumericIncrementFieldValue *other = (FSTNumericIncrementFieldValue *)object;
  return [self.operand isEqual:other.operand];
}

- (NSUInteger)hash {
  return [self.operand hash];
}

@end

#pragma mark - FSTNumericMinimumFieldValue

/* FieldValue class for minimum() transforms. */
@interface FSTNumericMinimumFieldValue ()
- (instancetype)initWithOperand:(id)operand;
@end

@implementation FSTNumericMinimumFieldValue
- (instancetype)initWithOperand:(id)operand {
  if (self = [super initPrivate]) {
    _operand = operand;
  }
  return self;
}

- (NSString *)methodName {
  return @"FieldValue.minimum()";
}

- (BOOL)isEqual:(nullable id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTNumericMinimumFieldValue class]]) {
    return NO;
  }
  FSTNumericMinimumFieldValue *other = (FSTNumericMinimumFieldValue *)object;
  return [self.operand isEqual:other.operand];
}

- (NSUInteger)hash {
  return [self.operand hash];
}

@end

#pragma mark - FSTNumericMaximumFieldValue

/* FieldValue class for maximum() transforms. */
@interface FSTNumericMaximumFieldValue ()
- (instancetype)initWithOperand:(id)operand;
@end

@implementation FSTNumericMaximumFieldValue
- (instancetype)initWithOperand:(id)operand {
  if (self = [super initPrivate]) {
    _operand = operand;
  }
  return self;
}

- (NSString *)methodName {
  return @"FieldValue.maximum()";
}

- (BOOL)isEqual:(nullable id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTNumericMaximumFieldValue class]]) {
    return NO;
  }
  FSTNumericMaximumFieldValue *other = (FSTNumericMaximumFieldValue *)object;
  return [self.operand isEqual:other.operand];
}

- (NSUInteger)hash {
  return [self.operand hash];
}

@end

#pragma mark - FIRFieldValue

@implementation FIRFieldValue

- (instancetype)initPrivate {
  self = [super init];
  return self;
}

+ (instancetype)fieldValueForDelete {
  return [FSTDeleteFieldValue deleteFieldValue];
}

+ (instancetype)fieldValueForServerTimestamp {
  return [FSTServerTimestampFieldValue serverTimestampFieldValue];
}

+ (instancetype)fieldValueForArrayUnion:(NSArray<id> *)elements {
  return [[FSTArrayUnionFieldValue alloc] initWithElements:elements];
}

+ (instancetype)fieldValueForArrayRemove:(NSArray<id> *)elements {
  return [[FSTArrayRemoveFieldValue alloc] initWithElements:elements];
}

+ (instancetype)fieldValueForDoubleIncrement:(double)d {
  return [[FSTNumericIncrementFieldValue alloc] initWithOperand:@(d)];
}

+ (instancetype)fieldValueForIntegerIncrement:(int64_t)l {
  return [[FSTNumericIncrementFieldValue alloc] initWithOperand:@(l)];
}

+ (instancetype)fieldValueForInt32Increment:(FIRInt32Value *)int32 {
  return [[FSTNumericIncrementFieldValue alloc] initWithOperand:int32];
}

+ (instancetype)fieldValueForDecimal128Increment:(FIRDecimal128Value *)decimal128 {
  return [[FSTNumericIncrementFieldValue alloc] initWithOperand:decimal128];
}

+ (instancetype)fieldValueForDoubleMinimum:(double)d {
  return [[FSTNumericMinimumFieldValue alloc] initWithOperand:@(d)];
}

+ (instancetype)fieldValueForIntegerMinimum:(int64_t)l {
  return [[FSTNumericMinimumFieldValue alloc] initWithOperand:@(l)];
}

+ (instancetype)fieldValueForInt32Minimum:(FIRInt32Value *)int32 {
  return [[FSTNumericMinimumFieldValue alloc] initWithOperand:int32];
}

+ (instancetype)fieldValueForDecimal128Minimum:(FIRDecimal128Value *)decimal128 {
  return [[FSTNumericMinimumFieldValue alloc] initWithOperand:decimal128];
}

+ (instancetype)fieldValueForDoubleMaximum:(double)d {
  return [[FSTNumericMaximumFieldValue alloc] initWithOperand:@(d)];
}

+ (instancetype)fieldValueForIntegerMaximum:(int64_t)l {
  return [[FSTNumericMaximumFieldValue alloc] initWithOperand:@(l)];
}

+ (instancetype)fieldValueForInt32Maximum:(FIRInt32Value *)int32 {
  return [[FSTNumericMaximumFieldValue alloc] initWithOperand:int32];
}

+ (instancetype)fieldValueForDecimal128Maximum:(FIRDecimal128Value *)decimal128 {
  return [[FSTNumericMaximumFieldValue alloc] initWithOperand:decimal128];
}

+ (nonnull FIRVectorValue *)vectorWithArray:(nonnull NSArray<NSNumber *> *)array {
  return [[FIRVectorValue alloc] initWithArray:array];
}

@end

NS_ASSUME_NONNULL_END
