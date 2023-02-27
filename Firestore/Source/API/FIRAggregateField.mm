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

#import "FIRAggregateField+Internal.h"
#import "FIRFieldPath+Internal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FIRAggregateField

@implementation FIRAggregateField

- (instancetype)initWithFieldPath:(FIRFieldPath *)fieldPathx {
  if (self = [super init]) {
    _fieldPath = fieldPathx;
  }
  return self;
}

- (instancetype)initPrivate {
  return [super init];
}

+ (instancetype)aggregateFieldForCount NS_SWIFT_NAME(count()) {
  return [[FSTCountAggregateField alloc] initPrivate];
}

+ (instancetype)aggregateFieldForSumOfField:(NSString *)field NS_SWIFT_NAME(sum(_:)) {
  FIRFieldPath *fieldPath = [FIRFieldPath pathWithDotSeparatedString:field];
  return [[FSTSumAggregateField alloc] initWithFieldPath:fieldPath];
}

+ (instancetype)aggregateFieldForSumOfFieldPath:(FIRFieldPath *)fieldPath NS_SWIFT_NAME(sum(_:)) {
  return [[FSTSumAggregateField alloc] initWithFieldPath:fieldPath];
}

+ (instancetype)aggregateFieldForAverageOfField:(NSString *)field NS_SWIFT_NAME(average(_:)) {
  FIRFieldPath *fieldPath = [FIRFieldPath pathWithDotSeparatedString:field];
  return [[FSTAverageAggregateField alloc] initWithFieldPath:fieldPath];
}

+ (instancetype)aggregateFieldForAverageOfFieldPath:(FIRFieldPath *)fieldPath
    NS_SWIFT_NAME(average(_:)) {
  return [[FSTAverageAggregateField alloc] initWithFieldPath:fieldPath];
}

@end

#pragma mark - FSTSumAggregateField

@interface FSTSumAggregateField ()
- (instancetype)initWithFieldPath:(FIRFieldPath *)internalFieldPath;
@end

@implementation FSTSumAggregateField
- (instancetype)initWithFieldPath:(FIRFieldPath *)internalFieldPath {
  self = [super initWithFieldPath:internalFieldPath];
  return self;
}

@end

#pragma mark - FSTAverageAggregateField

@interface FSTAverageAggregateField ()
- (instancetype)initWithFieldPath:(FIRFieldPath *)fieldPath;
@end

@implementation FSTAverageAggregateField
- (instancetype)initWithFieldPath:(FIRFieldPath *)fieldPath {
  self = [super initWithFieldPath:fieldPath];
  return self;
}

@end

#pragma mark - FSTCountAggregateField

@interface FSTCountAggregateField ()
- (instancetype)initPrivate;
@end

@implementation FSTCountAggregateField
- (instancetype)initPrivate {
  return [super initPrivate];
}

@end

NS_ASSUME_NONNULL_END
