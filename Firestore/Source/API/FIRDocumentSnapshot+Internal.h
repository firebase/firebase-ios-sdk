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

#import "FIRDocumentSnapshot.h"

#include "Firestore/core/src/firebase/firestore/api/document_snapshot.h"
#include "Firestore/core/src/firebase/firestore/api/snapshot_metadata.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

@class FIRFirestore;
@class FSTDocument;

using firebase::firestore::api::DocumentSnapshot;
using firebase::firestore::api::Firestore;
using firebase::firestore::api::SnapshotMetadata;
using firebase::firestore::model::DocumentKey;

NS_ASSUME_NONNULL_BEGIN

@interface FIRDocumentSnapshot (/* Init */)

- (instancetype)initWithSnapshot:(DocumentSnapshot &&)snapshot NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFirestore:(Firestore *)firestore
                      documentKey:(DocumentKey)documentKey
                         document:(nullable FSTDocument *)document
                         metadata:(SnapshotMetadata)metadata;

- (instancetype)initWithFirestore:(Firestore *)firestore
                      documentKey:(DocumentKey)documentKey
                         document:(nullable FSTDocument *)document
                        fromCache:(bool)fromCache
                 hasPendingWrites:(bool)hasPendingWrites;

@end

/** Internal FIRDocumentSnapshot API we don't want exposed in our public header files. */
@interface FIRDocumentSnapshot (Internal)

@property(nonatomic, strong, readonly, nullable) FSTDocument *internalDocument;

@end

NS_ASSUME_NONNULL_END
