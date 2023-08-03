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

#import "Firestore/core/src/model/aggregate_field.h"

using firebase::firestore::model::AggregateField;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FIRAggregateField

@interface FIRAggregateField ()
@property(nonatomic, strong) FIRFieldPath *_fieldPath;
@property(nonatomic, readwrite) model::AggregateField::OpKind _op;
- (instancetype)initWithFieldPathAndKind:(nullable FIRFieldPath *)fieldPath
                                  opKind:(model::AggregateField::OpKind)op;
@end

@implementation FIRAggregateField
- (instancetype)initWithFieldPathAndKind:(nullable FIRFieldPath *)fieldPath
                                  opKind:(model::AggregateField::OpKind)op {
  if (self = [super init]) {
    self._fieldPath = fieldPath;
    self._op = op;
  }
  return self;
}

- (FIRFieldPath *)fieldPath {
  return [self _fieldPath];
}

- (const std::string)name {
  switch ([self _op]) {
    case AggregateField::OpKind::Sum:
      return std::string("sum");
    case AggregateField::OpKind::Avg:
      return std::string("avg");
    case AggregateField::OpKind::Count:
      return std::string("count");
  }
  UNREACHABLE();
}

- (model::AggregateField)createInternalValue {
  if (self.fieldPath != Nil) {
    return model::AggregateField([self _op], [self createAlias], self.fieldPath.internalValue);
  } else {
    return model::AggregateField([self _op], [self createAlias]);
  }
}

- (model::AggregateAlias)createAlias {
  if (self.fieldPath != Nil) {
    return model::AggregateAlias([self name] + std::string{"_"} +
                                 self.fieldPath.internalValue.CanonicalString());
  } else {
    return model::AggregateAlias([self name]);
  }
}

+ (instancetype)aggregateFieldForCount {
  return [[FSTCountAggregateField alloc] initPrivate];
}

+ (instancetype)aggregateFieldForSumOfField:(NSString *)field {
  return [self aggregateFieldForSumOfFieldPath:[FIRFieldPath pathWithDotSeparatedString:field]];
}

+ (instancetype)aggregateFieldForSumOfFieldPath:(FIRFieldPath *)fieldPath {
  return [[FSTSumAggregateField alloc] initWithFieldPath:fieldPath];
}

+ (instancetype)aggregateFieldForAverageOfField:(NSString *)field {
  return [self aggregateFieldForAverageOfFieldPath:[FIRFieldPath pathWithDotSeparatedString:field]];
}

+ (instancetype)aggregateFieldForAverageOfFieldPath:(FIRFieldPath *)fieldPath {
  return [[FSTAverageAggregateField alloc] initWithFieldPath:fieldPath];
}

@end

#pragma mark - FSTSumAggregateField
@implementation FSTSumAggregateField
- (instancetype)initWithFieldPath:(FIRFieldPath *)fieldPath {
  self = [super initWithFieldPathAndKind:fieldPath opKind:model::AggregateField::OpKind::Sum];
  return self;
}
@end

#pragma mark - FSTAverageAggregateField

@implementation FSTAverageAggregateField
- (instancetype)initWithFieldPath:(FIRFieldPath *)fieldPath {
  self = [super initWithFieldPathAndKind:fieldPath opKind:model::AggregateField::OpKind::Avg];
  return self;
}

@end

#pragma mark - FSTCountAggregateField

@implementation FSTCountAggregateField
- (instancetype)initPrivate {
  self = [super initWithFieldPathAndKind:Nil opKind:model::AggregateField::OpKind::Count];
  return self;
}

@end

NS_ASSUME_NONNULL_END
