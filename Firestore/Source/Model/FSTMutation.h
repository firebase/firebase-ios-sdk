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

#include <memory>
#include <vector>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"

#include "absl/types/optional.h"

@class FSTDocument;
@class FSTFieldValue;
@class FSTMaybeDocument;
@class FSTObjectValue;
@class FIRTimestamp;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTMutationResult

@interface FSTMutationResult : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithVersion:(firebase::firestore::model::SnapshotVersion)version
               transformResults:(NSArray<FSTFieldValue *> *_Nullable)transformResults
    NS_DESIGNATED_INITIALIZER;

/** The version at which the mutation was committed. */
- (const firebase::firestore::model::SnapshotVersion &)version;

/**
 * The resulting fields returned from the backend after a FSTTransformMutation has been committed.
 * Contains one FieldValue for each FieldTransform that was in the mutation.
 *
 * Will be nil if the mutation was not a FSTTransformMutation.
 */
@property(nonatomic, strong, readonly) NSArray<FSTFieldValue *> *_Nullable transformResults;

@end

#pragma mark - FSTMutation

/**
 * A mutation describes a self-contained change to a document. Mutations can create, replace,
 * delete, and update subsets of documents.
 *
 * ## Subclassing Notes
 *
 * Subclasses of FSTMutation need to implement -applyTo:hasLocalMutations: to implement the
 * actual the behavior of mutation as applied to some source document.
 */
@interface FSTMutation : NSObject

- (id)init NS_UNAVAILABLE;

- (instancetype)initWithKey:(firebase::firestore::model::DocumentKey)key
               precondition:(firebase::firestore::model::Precondition)precondition
    NS_DESIGNATED_INITIALIZER;

/**
 * Applies this mutation to the given FSTDocument, FSTDeletedDocument or nil, if we don't have
 * information about this document. Both the input and returned documents can be nil.
 *
 * @param maybeDoc The current state of the document to mutate. The input document should be nil if
 * it does not currently exist.
 * @param baseDoc The state of the document prior to this mutation batch. The input document should
 * be nil if it the document did not exist.
 * @param localWriteTime A timestamp indicating the local write time of the batch this mutation is
 * a part of.
 * @param mutationResult Optional result info from the backend. If omitted, it's assumed that
 * this is merely a local (latency-compensated) application, and the resulting document will
 * have its hasLocalMutations flag set.
 *
 * @return The mutated document. The returned document may be nil, but only if maybeDoc was nil
 * and the mutation would not create a new document.
 *
 * NOTE: We preserve the version of the base document only in case of Set or Patch mutation to
 * denote what version of original document we've changed. In case of DeleteMutation we always reset
 * the version.
 *
 * Here's the expected transition table.
 *
 * MUTATION         APPLIED TO            RESULTS IN
 *
 * SetMutation        Document(v3)          Document(v3)
 * SetMutation        DeletedDocument(v3)   Document(v0)
 * SetMutation        nil                   Document(v0)
 * PatchMutation      Document(v3)          Document(v3)
 * PatchMutation      DeletedDocument(v3)   DeletedDocument(v3)
 * PatchMutation      nil                   nil
 * TransformMutation  Document(v3)          Document(v3)
 * TransformMutation  DeletedDocument(v3)   DeletedDocument(v3)
 * TransformMutation  nil                   nil
 * DeleteMutation     Document(v3)          DeletedDocument(v0)
 * DeleteMutation     DeletedDocument(v3)   DeletedDocument(v0)
 * DeleteMutation     nil                   DeletedDocument(v0)
 *
 * Note that FSTTransformMutations don't create FSTDocuments (in the case of being applied to an
 * FSTDeletedDocument), even though they would on the backend. This is because the client always
 * combines the FSTTransformMutation with a FSTSetMutation or FSTPatchMutation and we only want to
 * apply the transform if the prior mutation resulted in an FSTDocument (always true for an
 * FSTSetMutation, but not necessarily for an FSTPatchMutation).
 */
- (nullable FSTMaybeDocument *)applyTo:(nullable FSTMaybeDocument *)maybeDoc
                          baseDocument:(nullable FSTMaybeDocument *)baseDoc
                        localWriteTime:(FIRTimestamp *)localWriteTime
                        mutationResult:(nullable FSTMutationResult *)mutationResult;

/**
 * A helper version of applyTo for applying mutations locally (without a mutation result from the
 * backend).
 */
- (nullable FSTMaybeDocument *)applyTo:(nullable FSTMaybeDocument *)maybeDoc
                          baseDocument:(nullable FSTMaybeDocument *)baseDoc
                        localWriteTime:(nullable FIRTimestamp *)localWriteTime;

- (const firebase::firestore::model::DocumentKey &)key;

- (const firebase::firestore::model::Precondition &)precondition;

@end

#pragma mark - FSTSetMutation

/**
 * A mutation that creates or replaces the document at the given key with the object value
 * contents.
 */
@interface FSTSetMutation : FSTMutation

- (instancetype)initWithKey:(firebase::firestore::model::DocumentKey)key
               precondition:(firebase::firestore::model::Precondition)precondition NS_UNAVAILABLE;

/**
 * Initializes the set mutation.
 *
 * @param key Identifies the location of the document to mutate.
 * @param value An object value that describes the contents to store at the location named by the
 * key.
 * @param precondition The precondition for this mutation.
 */
- (instancetype)initWithKey:(firebase::firestore::model::DocumentKey)key
                      value:(FSTObjectValue *)value
               precondition:(firebase::firestore::model::Precondition)precondition
    NS_DESIGNATED_INITIALIZER;

/** The object value to use when setting the document. */
@property(nonatomic, strong, readonly) FSTObjectValue *value;
@end

#pragma mark - FSTPatchMutation

/**
 * A mutation that modifies fields of the document at the given key with the given values. The
 * values are applied through a field mask:
 *
 *  * When a field is in both the mask and the values, the corresponding field is updated.
 *  * When a field is in neither the mask nor the values, the corresponding field is unmodified.
 *  * When a field is in the mask but not in the values, the corresponding field is deleted.
 *  * When a field is not in the mask but is in the values, the values map is ignored.
 */
@interface FSTPatchMutation : FSTMutation

/** Returns the precondition for the given Precondition. */
- (instancetype)initWithKey:(firebase::firestore::model::DocumentKey)key
               precondition:(firebase::firestore::model::Precondition)precondition NS_UNAVAILABLE;

/**
 * Initializes a new patch mutation with an explicit FieldMask and FSTObjectValue representing
 * the updates to perform
 *
 * @param key Identifies the location of the document to mutate.
 * @param fieldMask The field mask specifying at what locations the data in value should be
 * applied.
 * @param value An FSTObjectValue containing the data to be written (using the paths in fieldMask
 * to determine the locations at which it should be applied).
 * @param precondition The precondition for this mutation.
 */
- (instancetype)initWithKey:(firebase::firestore::model::DocumentKey)key
                  fieldMask:(firebase::firestore::model::FieldMask)fieldMask
                      value:(FSTObjectValue *)value
               precondition:(firebase::firestore::model::Precondition)precondition
    NS_DESIGNATED_INITIALIZER;

/**
 * A mask to apply to |value|, where only fields that are in both the fieldMask and the value
 * will be updated.
 */
- (const firebase::firestore::model::FieldMask &)fieldMask;

/** The fields and associated values to use when patching the document. */
@property(nonatomic, strong, readonly) FSTObjectValue *value;

@end

#pragma mark - FSTTransformMutation

/**
 * A mutation that modifies specific fields of the document with transform operations. Currently
 * the only supported transform is a server timestamp, but IP Address, increment(n), etc. could
 * be supported in the future.
 *
 * It is somewhat similar to an FSTPatchMutation in that it patches specific fields and has no
 * effect when applied to nil or an FSTDeletedDocument (see comment on [FSTMutation applyTo] for
 * rationale).
 */
@interface FSTTransformMutation : FSTMutation

- (instancetype)initWithKey:(firebase::firestore::model::DocumentKey)key
               precondition:(firebase::firestore::model::Precondition)precondition NS_UNAVAILABLE;

/**
 * Initializes a new transform mutation with the specified field transforms.
 *
 * @param key Identifies the location of the document to mutate.
 * @param fieldTransforms A list of FieldTransform objects to perform to the document.
 */
- (instancetype)initWithKey:(firebase::firestore::model::DocumentKey)key
            fieldTransforms:(std::vector<firebase::firestore::model::FieldTransform>)fieldTransforms
    NS_DESIGNATED_INITIALIZER;

/** The field transforms to use when transforming the document. */
- (const std::vector<firebase::firestore::model::FieldTransform> &)fieldTransforms;

@end

#pragma mark - FSTDeleteMutation

@interface FSTDeleteMutation : FSTMutation

@end

NS_ASSUME_NONNULL_END
