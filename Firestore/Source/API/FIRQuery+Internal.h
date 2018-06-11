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

#import "FIRQuery.h"

@class FSTQuery;

NS_ASSUME_NONNULL_BEGIN

/** Internal FIRQuery API we don't want exposed in our public header files. */
@interface FIRQuery (Internal)
+ (FIRQuery *)referenceWithQuery:(FSTQuery *)query firestore:(FIRFirestore *)firestore;

@property(nonatomic, strong, readonly) FSTQuery *query;

@end

// TODO(array-features): Move to FIRQuery.h once backend support is available.
@interface FIRQuery ()

/**
 * Creates and returns a new `FIRQuery` with the additional filter that documents must contain
 * the specified field, it must be an array, and the array must contain the provided value.
 *
 * A query can have only one arrayContains filter.
 *
 * @param field The name of the field containing an array to search
 * @param value The value that must be contained in the array
 *
 * @return The created `FIRQuery`.
 */
// clang-format off
- (FIRQuery *)queryWhereField:(NSString *)field
                arrayContains:(id)value NS_SWIFT_NAME(whereField(_:arrayContains:));
// clang-format on

/**
 * Creates and returns a new `FIRQuery` with the additional filter that documents must contain
 * the specified field, it must be an array, and the array must contain the provided value.
 *
 * A query can have only one arrayContains filter.
 *
 * @param path The path of the field containing an array to search
 * @param value The value that must be contained in the array
 *
 * @return The created `FIRQuery`.
 */
// clang-format off
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
                    arrayContains:(id)value NS_SWIFT_NAME(whereField(_:arrayContains:));
// clang-format on

@end

NS_ASSUME_NONNULL_END
