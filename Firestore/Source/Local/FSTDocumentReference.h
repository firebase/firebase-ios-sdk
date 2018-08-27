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

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * An immutable value used to keep track of an association between some referencing target or batch
 * and a document key that the target or batch references.
 *
 * A reference can be from either listen targets (identified by their TargetId) or mutation batches
 * (identified by their BatchId). See FSTGarbageCollector for more details.
 *
 * Not to be confused with FIRDocumentReference.
 */
@interface FSTDocumentReference : NSObject <NSCopying>

/** Initializes the document reference with the given key and ID. */
- (instancetype)initWithKey:(firebase::firestore::model::DocumentKey)key
                         ID:(int32_t)ID NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** The document key that's the target of this reference. */
- (const firebase::firestore::model::DocumentKey &)key;

/**
 * The targetID of a referring target or the batchID of a referring mutation batch. (Which this is
 * depends upon which FSTReferenceSet this reference is a part of.)
 */
@property(nonatomic, assign, readonly) int32_t ID;

@end

#pragma mark Comparators

/** Sorts document references by key then ID. */
extern const NSComparator FSTDocumentReferenceComparatorByKey;

/** Sorts document references by ID then key. */
extern const NSComparator FSTDocumentReferenceComparatorByID;

/** A callback for use when enumerating an FSTImmutableSortedSet of FSTDocumentReferences. */
typedef void (^FSTDocumentReferenceBlock)(FSTDocumentReference *reference, BOOL *stop);

NS_ASSUME_NONNULL_END
