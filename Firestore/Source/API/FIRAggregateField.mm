/*
 * Copyright 2022 Google LLC
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

#import "FIRAggregateField.h"

@implementation FIRAggregateField

+ (FIRCountAggregateField *)aggregateFieldForCount {
  return nil;
}

+ (FIRCountAggregateField *)aggregateFieldForCountUpTo:(int32_t)upTo {
  return nil;
}

+ (FIRMinAggregateField *)aggregateFieldForMinOfField:(NSString *)ofField {
  return nil;
}

+ (FIRMinAggregateField *)aggregateFieldForMinOfFieldPath:(FIRFieldPath *)ofFieldPath {
  return nil;
}

+ (FIRMaxAggregateField *)aggregateFieldForMaxOfField:(NSString *)ofField {
  return nil;
}

+ (FIRMaxAggregateField *)aggregateFieldForMaxOfFieldPath:(FIRFieldPath *)ofFieldPath {
  return nil;
}

+ (FIRSumAggregateField *)aggregateFieldForSumOfField:(NSString *)ofField {
  return nil;
}

+ (FIRSumAggregateField *)aggregateFieldForSumOfFieldPath:(FIRFieldPath *)ofFieldPath {
  return nil;
}

+ (FIRAverageAggregateField *)aggregateFieldForAverageOfField:(NSString *)ofField {
  return nil;
}

+ (FIRAverageAggregateField *)aggregateFieldForAverageOfFieldPath:(FIRFieldPath *)ofFieldPath {
  return nil;
}

+ (FIRFirstAggregateField *)aggregateFieldForFirstOfField:(NSString *)ofField {
  return nil;
}

+ (FIRFirstAggregateField *)aggregateFieldForFirstOfFieldPath:(FIRFieldPath *)ofFieldPath {
  return nil;
}

+ (FIRLastAggregateField *)aggregateFieldForLastOfField:(NSString *)ofField {
  return nil;
}

+ (FIRLastAggregateField *)aggregateFieldForLastOfFieldPath:(FIRFieldPath *)ofFieldPath {
  return nil;
}

@end

@implementation FIRCountAggregateField
@end

@implementation FIRMinAggregateField
@end

@implementation FIRMaxAggregateField
@end

@implementation FIRSumAggregateField
@end

@implementation FIRAverageAggregateField
@end

@implementation FIRFirstAggregateField
@end

@implementation FIRLastAggregateField
@end
