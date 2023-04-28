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

#include <string>

#import "Firestore/Source/API/FIRAggregateField+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FIRAggregateField

@interface FIRAggregateField ()
@property(nonatomic, strong) FIRFieldPath *fieldPath;
@property(nonatomic, readwrite) model::AggregateField::OpKind _op;
- (instancetype)initWithFieldPath:(nullable FIRFieldPath *)fieldPath
                           opKind:(model::AggregateField::OpKind)op;
@end

@implementation FIRAggregateField
- (instancetype)initWithFieldPath:(nullable FIRFieldPath *)fieldPath
                           opKind:(model::AggregateField::OpKind)op {
  if (self = [super init]) {
    self.fieldPath = fieldPath;
    self._op = op;
  }
  return self;
}

@synthesize fieldPath;

- (const std::string)name {
  return model::AggregateField::OperatorKind([self _op]);
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
@end

#pragma mark - FSTAverageAggregateField

@implementation FSTAverageAggregateField
- (instancetype)initWithFieldPath:(FIRFieldPath *)fieldPath {
  self = [super initWithFieldPath:fieldPath opKind:model::AggregateField::OpKind::Avg];
  return self;
}

@end

#pragma mark - FSTCountAggregateField

@implementation FSTCountAggregateField
- (instancetype)initPrivate {
  self = [super initWithFieldPath:Nil opKind:model::AggregateField::OpKind::Count];
  return self;
}

@end

NS_ASSUME_NONNULL_END
