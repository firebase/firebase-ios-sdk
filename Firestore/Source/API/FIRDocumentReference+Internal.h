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

#import "FIRDocumentReference.h"

#include "Firestore/core/src/firebase/firestore/api/document_reference.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRDocumentReference (/* Init */)

- (instancetype)initWithReference:(firebase::firestore::api::DocumentReference &&)reference
    NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithPath:(firebase::firestore::model::ResourcePath)path
                   firestore:(firebase::firestore::api::Firestore *)firestore;

- (instancetype)initWithKey:(firebase::firestore::model::DocumentKey)key
                  firestore:(firebase::firestore::api::Firestore *)firestore;

@end

/** Internal FIRDocumentReference API we don't want exposed in our public header files. */
@interface FIRDocumentReference (Internal)

- (const firebase::firestore::model::DocumentKey &)key;

@end

NS_ASSUME_NONNULL_END
