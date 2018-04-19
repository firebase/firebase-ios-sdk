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

#include <vector>

#import "Firestore/Source/Core/FSTTypes.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

@class FSTDatastore;
@class FSTMaybeDocument;
@class FSTObjectValue;
@class FSTParsedSetData;
@class FSTParsedUpdateData;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTTransaction

/** Provides APIs to use in a transaction context. */
@interface FSTTransaction : NSObject

/** Creates a new transaction object, which can only be used for one transaction attempt. **/
+ (instancetype)transactionWithDatastore:(FSTDatastore *)datastore;

/**
 * Takes a set of keys and asynchronously attempts to fetch all the documents from the backend,
 * ignoring any local changes.
 */
- (void)lookupDocumentsForKeys:(const std::vector<firebase::firestore::model::DocumentKey> &)keys
                    completion:(FSTVoidMaybeDocumentArrayErrorBlock)completion;

/**
 * Stores mutation for the given key and set data, to be committed when commitWithCompletion is
 * called.
 */
- (void)setData:(FSTParsedSetData *)data
    forDocument:(const firebase::firestore::model::DocumentKey &)key;

/**
 * Stores mutations for the given key and update data, to be committed when commitWithCompletion
 * is called.
 */
- (void)updateData:(FSTParsedUpdateData *)data
       forDocument:(const firebase::firestore::model::DocumentKey &)key;

/**
 * Stores a delete mutation for the given key, to be committed when commitWithCompletion is called.
 */
- (void)deleteDocument:(const firebase::firestore::model::DocumentKey &)key;

/**
 * Attempts to commit the mutations set on this transaction. Calls the given completion block when
 * finished. Once this is called, no other mutations or commits are allowed on the transaction.
 */
- (void)commitWithCompletion:(FSTVoidErrorBlock)completion;

@end

NS_ASSUME_NONNULL_END
