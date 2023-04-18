/*
 * Copyright 2023 Google LLC
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

#import "FIRAggregateField.h"

#import "Firestore/Source/API/FIRAggregateField+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FIRAggregateField

@interface FIRAggregateField ()
@property(nonatomic, strong, readwrite) FIRFieldPath *_fieldPath;
@property(nonatomic, readwrite) model::AggregateField::OpKind _op;
- (instancetype)initWithFieldPath:(FIRFieldPath *)fieldPath opKind:(model::AggregateField::OpKind)op;
@end

@implementation FIRAggregateField
- (instancetype)initWithFieldPath:(FIRFieldPath *)fieldPath opKind:(model::AggregateField::OpKind)op {
  if (self = [super init]) {
    self._fieldPath = fieldPath;
    self._op = op;
  }
  return self;
}

- (instancetype)initPrivate {
  if (self = [super init]) {
  }
  return self;
}
- (const std::string)name {
  return model::AggregateField::OperatorKind([self _op]);
}

- (model::AggregateField)createInternalValue {
  HARD_FAIL("Use createInternalValue from FIRAggregateField sub class.");
}

- (model::AggregateAlias)createAlias {
  HARD_FAIL("Use createAlias from FIRAggregateField sub class.");
}

+ (instancetype)aggregateFieldForCount NS_SWIFT_NAME(count()) {
  return [[FSTCountAggregateField alloc] initPrivate];
}

+ (instancetype)aggregateFieldForSumOfField:(NSString *)field NS_SWIFT_NAME(sum(_:)) {
  return [self aggregateFieldForSumOfFieldPath:[FIRFieldPath pathWithDotSeparatedString:field]];
}

+ (instancetype)aggregateFieldForSumOfFieldPath:(FIRFieldPath *)fieldPath NS_SWIFT_NAME(sum(_:)) {
  return [[FSTSumAggregateField alloc] initWithFieldPath:fieldPath];
}

+ (instancetype)aggregateFieldForAverageOfField:(NSString *)field NS_SWIFT_NAME(average(_:)) {
  return [self aggregateFieldForAverageOfFieldPath:[FIRFieldPath pathWithDotSeparatedString:field]];
}

+ (instancetype)aggregateFieldForAverageOfFieldPath:(FIRFieldPath *)fieldPath
    NS_SWIFT_NAME(average(_:)) {
  return [[FSTAverageAggregateField alloc] initWithFieldPath:fieldPath];
}

@end

#pragma mark - FSTSumAggregateField
@implementation FSTSumAggregateField
- (instancetype)initWithFieldPath:(FIRFieldPath *)fieldPath {
  self = [super initWithFieldPath:fieldPath opKind:model::AggregateField::OpKind::Sum];
  return self;
}

- (model::AggregateAlias)createAlias {
  return model::AggregateAlias([self name] + std::string{"_"} +
                               super._fieldPath.internalValue.CanonicalString());
}

- (model::AggregateField)createInternalValue {
  return model::AggregateField([self _op], [self createAlias], super._fieldPath.internalValue);
}
@end

#pragma mark - FSTAverageAggregateField

@implementation FSTAverageAggregateField
- (instancetype)initWithFieldPath:(FIRFieldPath *)fieldPath {
  self = [super initWithFieldPath:fieldPath opKind:model::AggregateField::OpKind::Avg];
  return self;
}

- (model::AggregateAlias)createAlias {
  return model::AggregateAlias([self name] + std::string{"_"} +
                               super._fieldPath.internalValue.CanonicalString());
}

- (model::AggregateField)createInternalValue {
  return model::AggregateField([self _op], [self createAlias], super._fieldPath.internalValue);
}

@end

#pragma mark - FSTCountAggregateField

@implementation FSTCountAggregateField
- (instancetype)initPrivate {
  return [super initPrivate];
}

- (model::AggregateAlias)createAlias {
  return model::AggregateAlias([self name]);
}

- (model::AggregateField)createInternalValue {
  return model::AggregateField([self _op], [self createAlias]);
}

@end

NS_ASSUME_NONNULL_END
