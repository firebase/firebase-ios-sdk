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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FIRFieldPath;

// TODO(sum/avg) move this entire file to ../Public/FirebaseFirestore when the API can be public

/**
 * Represents an aggregation that can be performed by Firestore.
 */
NS_SWIFT_NAME(AggregateField)
@interface FIRAggregateField : NSObject

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Create an `AggregateField` object that can be used to compute the count of
 * documents in the result set of a query.
 *
 * The result of a count operation will always be a 64-bit integer value.
 *
 * @return `AggregateField` object that can be used to compute the count of
 * documents in the result set of a query.
 */
+ (instancetype)aggregateFieldForCount NS_SWIFT_NAME(count());

/**
 * Create an `AggregateField` object that can be used to compute the sum of
 * a specified field over a range of documents in the result set of a query.
 *
 * The result of a sum operation will always be a 64-bit integer value, a double, or NaN.
 *
 * - Summing over zero documents or fields will result in 0L.
 * - Summing over NaN will result in a double value representing NaN.
 * - A sum that overflows the maximum representable 64-bit integer value will result in a double
 * return value. This may result in lost precision of the result.
 * - A sum that overflows the maximum representable double value will result in a double return
 * value representing infinity.
 *
 * @param field Specifies the field to sum across the result set.
 * @return `AggregateField` object that can be used to compute the sum of
 * a specified field over a range of documents in the result set of a query.
 */
+ (instancetype)aggregateFieldForSumOfField:(NSString *)field NS_SWIFT_NAME(sum(_:));

/**
 * Create an `AggregateField` object that can be used to compute the sum of
 * a specified field over a range of documents in the result set of a query.
 *
 * The result of a sum operation will always be a 64-bit integer value, a double, or NaN.
 *
 * - Summing over zero documents or fields will result in 0L.
 * - Summing over NaN will result in a double value representing NaN.
 * - A sum that overflows the maximum representable 64-bit integer value will result in a double
 * return value. This may result in lost precision of the result.
 * - A sum that overflows the maximum representable double value will result in a double return
 * value representing infinity.
 *
 * @param fieldPath Specifies the field to sum across the result set.
 * @return `AggregateField` object that can be used to compute the sum of
 * a specified field over a range of documents in the result set of a query.
 */
+ (instancetype)aggregateFieldForSumOfFieldPath:(FIRFieldPath *)fieldPath NS_SWIFT_NAME(sum(_:));

/**
 * Create an `AggregateField` object that can be used to compute the average of
 * a specified field over a range of documents in the result set of a query.
 *
 * The result of an average operation will always be a 64-bit integer value, a double, or NaN.
 *
 * - Averaging over zero documents or fields will result in a double value representing NaN.
 * - Averaging over NaN will result in a double value representing NaN.
 *
 * @param field Specifies the field to average across the result set.
 * @return `AggregateField` object that can be used to compute the average of
 * a specified field over a range of documents in the result set of a query.
 */
+ (instancetype)aggregateFieldForAverageOfField:(NSString *)field NS_SWIFT_NAME(average(_:));

/**
 * Create an `AggregateField` object that can be used to compute the average of
 * a specified field over a range of documents in the result set of a query.
 *
 * The result of an average operation will always be a 64-bit integer value, a double, or NaN.
 *
 * - Averaging over zero documents or fields will result in a double value representing NaN.
 * - Averaging over NaN will result in a double value representing NaN.
 *
 * @param fieldPath Specifies the field to average across the result set.
 * @return `AggregateField` object that can be used to compute the average of
 * a specified field over a range of documents in the result set of a query.
 */
+ (instancetype)aggregateFieldForAverageOfFieldPath:(FIRFieldPath *)fieldPath
    NS_SWIFT_NAME(average(_:));

@end

NS_ASSUME_NONNULL_END
