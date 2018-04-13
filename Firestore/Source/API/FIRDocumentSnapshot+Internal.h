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

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

@class FIRFirestore;
@class FSTDocument;

NS_ASSUME_NONNULL_BEGIN

/** Internal FIRDocumentSnapshot API we don't want exposed in our public header files. */
@interface FIRDocumentSnapshot (Internal)

+ (instancetype)snapshotWithFirestore:(FIRFirestore *)firestore
                          documentKey:(firebase::firestore::model::DocumentKey)documentKey
                             document:(nullable FSTDocument *)document
                            fromCache:(BOOL)fromCache;

@property(nonatomic, strong, readonly, nullable) FSTDocument *internalDocument;

@end

NS_ASSUME_NONNULL_END
