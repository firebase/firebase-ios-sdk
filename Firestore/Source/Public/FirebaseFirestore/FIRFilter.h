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

@class FIRFieldPath;

NS_ASSUME_NONNULL_BEGIN

/**
 * A Filter represents a restriction on one or more field values and can be used to refine
 * the results of a Query.
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(Filter)
@interface FIRFilter : NSObject

#pragma mark - Create Filter

/**
 * Creates a new filter for checking that the given field is equal to the given value.
 *
 * @param field The field used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                      isEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isEqualTo:));

/**
 * Creates a new filter for checking that the given field is equal to the given value.
 *
 * @param path The field path used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)path
                          isEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isEqualTo:));

/**
 * Creates a new filter for checking that the given field is not equal to the given value.
 *
 * @param field The field used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                   isNotEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isNotEqualTo:));

/**
 * Creates a new filter for checking that the given field is not equal to the given value.
 *
 * @param path The field path used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)path
                       isNotEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isNotEqualTo:));

/**
 * Creates a new filter for checking that the given field is greater than the given value.
 *
 * @param field The field used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                  isGreaterThan:(nonnull id)value NS_SWIFT_NAME(whereField(_:isGreaterThan:));

/**
 * Creates a new filter for checking that the given field is greater than the given value.
 *
 * @param path The field path used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)path
                      isGreaterThan:(nonnull id)value NS_SWIFT_NAME(whereField(_:isGreaterThan:));

/**
 * Creates a new filter for checking that the given field is greater than or equal to the given
 * value.
 *
 * @param field The field used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
         isGreaterThanOrEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isGreaterOrEqualTo:));

/**
 * Creates a new filter for checking that the given field is greater than or equal to the given
 * value.
 *
 * @param path The field path used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)path
             isGreaterThanOrEqualTo:(nonnull id)value
    NS_SWIFT_NAME(whereField(_:isGreaterOrEqualTo:));

/**
 * Creates a new filter for checking that the given field is less than the given value.
 *
 * @param field The field used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                     isLessThan:(nonnull id)value NS_SWIFT_NAME(whereField(_:isLessThan:));

/**
 * Creates a new filter for checking that the given field is less than the given value.
 *
 * @param path The field path used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)path
                         isLessThan:(nonnull id)value NS_SWIFT_NAME(whereField(_:isLessThan:));

/**
 * Creates a new filter for checking that the given field is less than or equal to the given
 * value.
 *
 * @param field The field used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
            isLessThanOrEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isLessThanOrEqualTo:));

/**
 * Creates a new filter for checking that the given field is less than or equal to the given
 * value.
 *
 * @param path The field path used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)path
                isLessThanOrEqualTo:(nonnull id)value
    NS_SWIFT_NAME(whereField(_:isLessThanOrEqualTo:));

/**
 * Creates a new filter for checking that the given array field contains the given value.
 *
 * @param field The field used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                  arrayContains:(nonnull id)value NS_SWIFT_NAME(whereField(_:arrayContains:));

/**
 * Creates a new filter for checking that the given array field contains the given value.
 *
 * @param path The field path used for the filter.
 * @param value The value used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)path
                      arrayContains:(nonnull id)value NS_SWIFT_NAME(whereField(_:arrayContains:));

/**
 * Creates a new filter for checking that the given array field contains any of the given values.
 *
 * @param field The field used for the filter.
 * @param values The list of values used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
               arrayContainsAny:(nonnull NSArray<id> *)values
    NS_SWIFT_NAME(whereField(_:arrayContainsAny:));

/**
 * Creates a new filter for checking that the given array field contains any of the given values.
 *
 * @param path The field path used for the filter.
 * @param values The list of values used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)path
                   arrayContainsAny:(nonnull NSArray<id> *)values
    NS_SWIFT_NAME(whereField(_:arrayContainsAny:));

/**
 * Creates a new filter for checking that the given field equals any of the given values.
 *
 * @param field The field used for the filter.
 * @param values The list of values used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                             in:(nonnull NSArray<id> *)values NS_SWIFT_NAME(whereField(_:in:));

/**
 * Creates a new filter for checking that the given field equals any of the given values.
 *
 * @param path The field path used for the filter.
 * @param values The list of values used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)path
                                 in:(nonnull NSArray<id> *)values NS_SWIFT_NAME(whereField(_:in:));

/**
 * Creates a new filter for checking that the given field does not equal any of the given values.
 *
 * @param field The field path used for the filter.
 * @param values The list of values used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                          notIn:(nonnull NSArray<id> *)values NS_SWIFT_NAME(whereField(_:notIn:));

/**
 * Creates a new filter for checking that the given field does not equal any of the given values.
 *
 * @param path The field path used for the filter.
 * @param values The list of values used for the filter.
 * @return The newly created filter.
 */
+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)path
                              notIn:(nonnull NSArray<id> *)values
    NS_SWIFT_NAME(whereField(_:notIn:));

/**
 * Creates a new filter that is a disjunction of the given filters. A disjunction filter includes
 * a document if it satisfies any of the given filters.
 *
 * @param filters The list of filters to perform a disjunction for.
 * @return The newly created filter.
 */
+ (FIRFilter *)orFilterWithFilters:(NSArray<FIRFilter *> *)filters NS_SWIFT_NAME(orFilter(_:));

/**
 * Creates a new filter that is a conjunction of the given filters. A conjunction filter includes
 * a document if it satisfies all of the given filters.
 *
 * @param filters The list of filters to perform a disjunction for.
 * @return The newly created filter.
 */
+ (FIRFilter *)andFilterWithFilters:(NSArray<FIRFilter *> *)filters NS_SWIFT_NAME(andFilter(_:));

@end

NS_ASSUME_NONNULL_END
