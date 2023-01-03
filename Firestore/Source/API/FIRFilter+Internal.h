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
#include "Firestore/Protos/nanopb/google/firestore/v1/query.nanopb.h"
#import "Firestore/core/src/core/composite_filter.h"
#import "Firestore/core/src/core/field_filter.h"

// TODO(orquery): This class will become public API. Change visibility and add documentation.

@class FIRFieldPath;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Filter)
@interface FIRFilter : NSObject

#pragma mark - Public Methods

+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                      isEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isEqualTo:));

+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)field
                          isEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isEqualTo:));

+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                   isNotEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isNotEqualTo:));

+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)field
                       isNotEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isNotEqualTo:));

+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                  isGreaterThan:(nonnull id)value NS_SWIFT_NAME(whereField(_:isGreaterThan:));

+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)field
                      isGreaterThan:(nonnull id)value NS_SWIFT_NAME(whereField(_:isGreaterThan:));

+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
         isGreaterThanOrEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isGreaterOrEqualTo:));

+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)field
             isGreaterThanOrEqualTo:(nonnull id)value
    NS_SWIFT_NAME(whereField(_:isGreaterOrEqualTo:));

+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                     isLessThan:(nonnull id)value NS_SWIFT_NAME(whereField(_:isLessThan:));

+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)field
                         isLessThan:(nonnull id)value NS_SWIFT_NAME(whereField(_:isLessThan:));

+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
            isLessThanOrEqualTo:(nonnull id)value NS_SWIFT_NAME(whereField(_:isLessThanOrEqualTo:));

+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)field
                isLessThanOrEqualTo:(nonnull id)value
    NS_SWIFT_NAME(whereField(_:isLessThanOrEqualTo:));

+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                  arrayContains:(nonnull id)value NS_SWIFT_NAME(whereField(_:arrayContains:));

+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)field
                      arrayContains:(nonnull id)value NS_SWIFT_NAME(whereField(_:arrayContains:));

+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
               arrayContainsAny:(nonnull NSArray<id> *)values
    NS_SWIFT_NAME(whereField(_:arrayContainsAny:));

+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)field
                   arrayContainsAny:(nonnull NSArray<id> *)values
    NS_SWIFT_NAME(whereField(_:arrayContainsAny:));

+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                             in:(nonnull NSArray<id> *)values NS_SWIFT_NAME(whereField(_:in:));

+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)field
                                 in:(nonnull NSArray<id> *)values NS_SWIFT_NAME(whereField(_:in:));

+ (FIRFilter *)filterWhereField:(nonnull NSString *)field
                          notIn:(nonnull NSArray<id> *)values NS_SWIFT_NAME(whereField(_:notIn:));

+ (FIRFilter *)filterWhereFieldPath:(nonnull FIRFieldPath *)field
                              notIn:(nonnull NSArray<id> *)values
    NS_SWIFT_NAME(whereField(_:notIn:));

+ (FIRFilter *)orFilterWithFilters:(NSArray<FIRFilter *> *)filters NS_SWIFT_NAME(orFilter(_:));

+ (FIRFilter *)andFilterWithFilters:(NSArray<FIRFilter *> *)filters NS_SWIFT_NAME(andFilter(_:));

@end

/** Exposed internally */
@interface FSTUnaryFilter : FIRFilter

@property(nonatomic, strong, readonly) FIRFieldPath *fieldPath;
@property(nonatomic, readonly) firebase::firestore::core::FieldFilter::Operator unaryOp;
@property(nonatomic, strong, readonly) id value;

@end

@interface FSTCompositeFilter : FIRFilter

@property(nonatomic, strong, readonly) NSArray<FIRFilter *> *filters;
@property(nonatomic, readonly) firebase::firestore::core::CompositeFilter::Operator compOp;

@end

NS_ASSUME_NONNULL_END
