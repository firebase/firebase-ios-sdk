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

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

@class FIRSetOptions;
@class FSTObjectValue;
@class FSTFieldMask;
@class FSTFieldValue;
@class FSTFieldTransform;
@class FSTMutation;
@class FSTPrecondition;
@class FSTSnapshotVersion;

NS_ASSUME_NONNULL_BEGIN

/** The result of parsing document data (e.g. for a setData call). */
@interface FSTParsedSetData : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithData:(FSTObjectValue *)data
                   fieldMask:(nullable FSTFieldMask *)fieldMask
             fieldTransforms:(NSArray<FSTFieldTransform *> *)fieldTransforms
    NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) FSTObjectValue *data;
@property(nonatomic, strong, readonly, nullable) FSTFieldMask *fieldMask;
@property(nonatomic, strong, readonly) NSArray<FSTFieldTransform *> *fieldTransforms;

/**
 * Converts the parsed document data into 1 or 2 mutations (depending on whether there are any
 * field transforms) using the specified document key and precondition.
 */
- (NSArray<FSTMutation *> *)mutationsWithKey:(const firebase::firestore::model::DocumentKey &)key
                                precondition:(FSTPrecondition *)precondition;

@end

/** The result of parsing "update" data (i.e. for an updateData call). */
@interface FSTParsedUpdateData : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithData:(FSTObjectValue *)data
                   fieldMask:(FSTFieldMask *)fieldMask
             fieldTransforms:(NSArray<FSTFieldTransform *> *)fieldTransforms
    NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) FSTObjectValue *data;
@property(nonatomic, strong, readonly) FSTFieldMask *fieldMask;
@property(nonatomic, strong, readonly) NSArray<FSTFieldTransform *> *fieldTransforms;

/**
 * Converts the parsed update data into 1 or 2 mutations (depending on whether there are any
 * field transforms) using the specified document key and precondition.
 */
- (NSArray<FSTMutation *> *)mutationsWithKey:(const firebase::firestore::model::DocumentKey &)key
                                precondition:(FSTPrecondition *)precondition;

@end

/**
 * An internal representation of FIRDocumentReference, representing a key in a specific database.
 * This is necessary because keys assume a database from context (usually the current one).
 * FSTDocumentKeyReference binds a key to a specific databaseID.
 *
 * TODO(b/64160088): Make DocumentKey aware of the specific databaseID it is tied to.
 */
@interface FSTDocumentKeyReference : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithKey:(firebase::firestore::model::DocumentKey)key
                 databaseID:(const firebase::firestore::model::DatabaseId *)databaseID
    NS_DESIGNATED_INITIALIZER;

- (const firebase::firestore::model::DocumentKey &)key;

// Does not own the DatabaseId instance.
@property(nonatomic, assign, readonly) const firebase::firestore::model::DatabaseId *databaseID;

@end

/**
 * An interface that allows arbitrary pre-converting of user data.
 *
 * Returns the converted value (can return back the input to act as a no-op).
 */
typedef id _Nullable (^FSTPreConverterBlock)(id _Nullable);

/**
 * Helper for parsing raw user input (provided via the API) into internal model classes.
 */
@interface FSTUserDataConverter : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDatabaseID:(const firebase::firestore::model::DatabaseId *)databaseID
                      preConverter:(FSTPreConverterBlock)preConverter NS_DESIGNATED_INITIALIZER;

/** Parse document data from a non-merge setData call.*/
- (FSTParsedSetData *)parsedSetData:(id)input;

/** Parse document data from a setData call with '[FIRSetOptions merge]'. */
- (FSTParsedSetData *)parsedMergeData:(id)input;

/** Parse update data from an updateData call. */
- (FSTParsedUpdateData *)parsedUpdateData:(id)input;

/** Parse a "query value" (e.g. value in a where filter or a value in a cursor bound). */
- (FSTFieldValue *)parsedQueryValue:(id)input;

@end

NS_ASSUME_NONNULL_END
