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

#import <Foundation/Foundation.h>

@class FIRDocumentReference;
@class FIRSnapshotMetadata;

NS_ASSUME_NONNULL_BEGIN

/**
 * A `FIRDocumentSnapshot` contains data read from a document in your Firestore database. The data
 * can be extracted with the `data` property or by using subscript syntax to access a specific
 * field.
 */
NS_SWIFT_NAME(DocumentSnapshot)
@interface FIRDocumentSnapshot : NSObject

/**   */
- (instancetype)init
    __attribute__((unavailable("FIRDocumentSnapshot cannot be created directly.")));

/** True if the document exists. */
@property(nonatomic, assign, readonly) BOOL exists;

/** A `FIRDocumentReference` to the document location. */
@property(nonatomic, strong, readonly) FIRDocumentReference *reference;

/** The ID of the document for which this `FIRDocumentSnapshot` contains data. */
@property(nonatomic, copy, readonly) NSString *documentID;

/** Metadata about this snapshot concerning its source and if it has local modifications. */
@property(nonatomic, strong, readonly) FIRSnapshotMetadata *metadata;

/**
 * Retrieves all fields in the document as an `NSDictionary`.
 *
 * @return An `NSDictionary` containing all fields in the document.
 */
- (NSDictionary<NSString *, id> *)data;

/**
 * Retrieves a specific field from the document.
 *
 * @param key The field to retrieve.
 *
 * @return The value contained in the field or `nil` if the field doesn't exist.
 */
- (nullable id)objectForKeyedSubscript:(id)key;

@end

NS_ASSUME_NONNULL_END
