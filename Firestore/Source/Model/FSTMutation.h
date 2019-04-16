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

namespace model = firebase::firestore::model;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTMutationResult

@interface FSTMutationResult : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithVersion:(model::SnapshotVersion)version
               transformResults:(NSArray<FSTFieldValue *> *_Nullable)transformResults
    NS_DESIGNATED_INITIALIZER;

/**
 * The version at which the mutation was committed.
 *
 * - For most operations, this is the updateTime in the WriteResult.
 * - For deletes, it is the commitTime of the WriteResponse (because deletes are not stored
 * and have no updateTime).
 *
 * Note that these versions can be different: No-op writes will not change the updateTime even
 * though the commitTime advances.
 */
- (const model::SnapshotVersion &)version;

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
 * Represents a Mutation of a document. Different subclasses of Mutation will perform different
 * kinds of changes to a base document. For example, an FSTSetMutation replaces the value of a
 * document and an FSTDeleteMutation deletes a document.
 *
 * Subclasses of FSTMutation need to implement `applyToRemoteDocument:mutationResult:` and
 * `applyToLocalDocument:baseDocument:localWriteTime:` to implement the actual the behavior of
 * mutations as applied to some source document.
 *
 * In addition to the value of the document mutations also operate on the version. For local
 * mutations (mutations that haven't been committed yet), we preserve the existing version for Set,
 * Patch, and Transform mutations. For local deletes, we reset the version to 0.
 *
 * Here's the expected transition table.
 *
 * MUTATION           APPLIED TO            RESULTS IN
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
 * For acknowledged mutations, we use the updateTime of the WriteResponse as the resulting version
 * for Set, Patch, and Transform mutations. As deletes have no explicit update time, we use the
 * commitTime of the WriteResponse for acknowledged deletes.
 *
 * If a mutation is acknowledged by the backend but fails the precondition check locally, we
 * return an `FSTUnknownDocument` and rely on Watch to send us the updated version.
 *
 * Note that FSTTransformMutations don't create Documents (in the case of being applied to an
 * FSTDeletedDocument), even though they would on the backend. This is because the client always
 * combines the FSTTransformMutations with a FSTSetMutation or FSTPatchMutation and we only want to
 * apply the transform if the prior mutation resulted in an FSTDocument (always true for an
 * FSTSetMutation, but not necessarily for an FSTPatchMutation).
 */
@interface FSTMutation : NSObject

- (id)init NS_UNAVAILABLE;

- (instancetype)initWithKey:(model::DocumentKey)key
               precondition:(model::Precondition)precondition NS_DESIGNATED_INITIALIZER;

/**
 * Applies this mutation to the given FSTMaybeDocument for the purposes of computing a new remote
 * document. If the input document doesn't match the expected state (e.g. it is nil or outdated),
 * an `FSTUnknownDocument` can be returned.
 *
 * @param maybeDoc The document to mutate. The input document can be nil if the client has no
 *     knowledge of the pre-mutation state of the document.
 * @param mutationResult The result of applying the mutation from the backend.
 * @return The mutated document. The returned document may be an FSTUnknownDocument if the mutation
 *     could not be applied to the locally cached base document.
 */
- (FSTMaybeDocument *)applyToRemoteDocument:(nullable FSTMaybeDocument *)maybeDoc
                             mutationResult:(FSTMutationResult *)mutationResult;

/**
 * Applies this mutation to the given FSTMaybeDocument for the purposes of computing the new local
 * view of a document. Both the input and returned documents can be nil.
 *
 * @param maybeDoc The document to mutate. The input document can be nil if the client has no
 * knowledge of the pre-mutation state of the document.
 * @param baseDoc The state of the document prior to this mutation batch. The input document can
 * be nil if the client has no knowledge of the pre-mutation state of the document.
 * @param localWriteTime A timestamp indicating the local write time of the batch this mutation is
 * a part of.
 * @return The mutated document. The returned document may be nil, but only if maybeDoc was nil
 * and the mutation would not create a new document.
 */
- (nullable FSTMaybeDocument *)applyToLocalDocument:(nullable FSTMaybeDocument *)maybeDoc
                                       baseDocument:(nullable FSTMaybeDocument *)baseDoc
                                     localWriteTime:(FIRTimestamp *)localWriteTime;

- (const model::DocumentKey &)key;

- (const model::Precondition &)precondition;

/**
 * If applicable, returns the field mask for this mutation. Fields that are not included in this
 * field mask are not modified when this mutation is applied. Mutations that replace all document
 * values return 'nullptr'.
 */
- (const model::FieldMask *)fieldMask;

/** Returns whether all operations in the mutation are idempotent. */
@property(nonatomic, readonly) BOOL idempotent;

@end

#pragma mark - FSTSetMutation

/**
 * A mutation that creates or replaces the document at the given key with the object value
 * contents.
 */
@interface FSTSetMutation : FSTMutation

- (instancetype)initWithKey:(model::DocumentKey)key
               precondition:(model::Precondition)precondition NS_UNAVAILABLE;

/**
 * Initializes the set mutation.
 *
 * @param key Identifies the location of the document to mutate.
 * @param value An object value that describes the contents to store at the location named by the
 * key.
 * @param precondition The precondition for this mutation.
 */
- (instancetype)initWithKey:(model::DocumentKey)key
                      value:(FSTObjectValue *)value
               precondition:(model::Precondition)precondition NS_DESIGNATED_INITIALIZER;

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
- (instancetype)initWithKey:(model::DocumentKey)key
               precondition:(model::Precondition)precondition NS_UNAVAILABLE;

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
- (instancetype)initWithKey:(model::DocumentKey)key
                  fieldMask:(model::FieldMask)fieldMask
                      value:(FSTObjectValue *)value
               precondition:(model::Precondition)precondition NS_DESIGNATED_INITIALIZER;

/**
 * A mask to apply to |value|, where only fields that are in both the fieldMask and the value
 * will be updated.
 */
- (const model::FieldMask *)fieldMask;

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

- (instancetype)initWithKey:(model::DocumentKey)key
               precondition:(model::Precondition)precondition NS_UNAVAILABLE;

/**
 * Initializes a new transform mutation with the specified field transforms.
 *
 * @param key Identifies the location of the document to mutate.
 * @param fieldTransforms A list of FieldTransform objects to perform to the document.
 */
- (instancetype)initWithKey:(model::DocumentKey)key
            fieldTransforms:(std::vector<model::FieldTransform>)fieldTransforms
    NS_DESIGNATED_INITIALIZER;

/** The field transforms to use when transforming the document. */
- (const std::vector<model::FieldTransform> &)fieldTransforms;

@end

#pragma mark - FSTDeleteMutation

@interface FSTDeleteMutation : FSTMutation

@end

NS_ASSUME_NONNULL_END
