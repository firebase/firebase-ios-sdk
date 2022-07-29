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

NS_ASSUME_NONNULL_BEGIN

@class FIRCountAggregateField;
@class FIRFieldPath;
@class FIRMinAggregateField;
@class FIRMaxAggregateField;
@class FIRSumAggregateField;
@class FIRAverageAggregateField;
@class FIRFirstAggregateField;
@class FIRLastAggregateField;

NS_SWIFT_NAME(AggregateField)
@interface FIRAggregateField : NSObject

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

+ (FIRCountAggregateField *)aggregateFieldForCount NS_SWIFT_NAME(count());
+ (FIRCountAggregateField *)aggregateFieldForCountUpTo:(int32_t)upTo NS_SWIFT_NAME(count(upTo:));
+ (FIRMinAggregateField *)aggregateFieldForMinOfField:(NSString *)ofField NS_SWIFT_NAME(min(_:));
+ (FIRMinAggregateField *)aggregateFieldForMinOfFieldPath:(FIRFieldPath *)ofFieldPath NS_SWIFT_NAME(min(_:));
+ (FIRMaxAggregateField *)aggregateFieldForMaxOfField:(NSString *)ofField NS_SWIFT_NAME(max(_:));
+ (FIRMaxAggregateField *)aggregateFieldForMaxOfFieldPath:(FIRFieldPath *)ofFieldPath NS_SWIFT_NAME(max(_:));
+ (FIRSumAggregateField *)aggregateFieldForSumOfField:(NSString *)ofField NS_SWIFT_NAME(sum(_:));
+ (FIRSumAggregateField *)aggregateFieldForSumOfFieldPath:(FIRFieldPath *)ofFieldPath NS_SWIFT_NAME(sum(_:));
+ (FIRAverageAggregateField *)aggregateFieldForAverageOfField:(NSString *)ofField NS_SWIFT_NAME(average(_:));
+ (FIRAverageAggregateField *)aggregateFieldForAverageOfFieldPath:(FIRFieldPath *)ofFieldPath NS_SWIFT_NAME(average(_:));
+ (FIRFirstAggregateField *)aggregateFieldForFirstOfField:(NSString *)ofField NS_SWIFT_NAME(first(_:));
+ (FIRFirstAggregateField *)aggregateFieldForFirstOfFieldPath:(FIRFieldPath *)ofFieldPath NS_SWIFT_NAME(first(_:));
+ (FIRLastAggregateField *)aggregateFieldForLastOfField:(NSString *)ofField NS_SWIFT_NAME(last(_:));
+ (FIRLastAggregateField *)aggregateFieldForLastOfFieldPath:(FIRFieldPath *)ofFieldPath NS_SWIFT_NAME(last(_:));

@end

NS_SWIFT_NAME(CountAggregateField)
@interface FIRCountAggregateField : FIRAggregateField

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(MinAggregateField)
@interface FIRMinAggregateField : FIRAggregateField

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(MaxAggregateField)
@interface FIRMaxAggregateField : FIRAggregateField

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(SumAggregateField)
@interface FIRSumAggregateField : FIRAggregateField

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(AverageAggregateField)
@interface FIRAverageAggregateField : FIRAggregateField

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(FirstAggregateField)
@interface FIRFirstAggregateField : FIRAggregateField

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(LastAggregateField)
@interface FIRLastAggregateField : FIRAggregateField

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end


NS_ASSUME_NONNULL_END
