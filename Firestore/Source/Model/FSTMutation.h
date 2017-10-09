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

@class FSTDocument;
@class FSTDocumentKey;
@class FSTFieldPath;
@class FSTFieldValue;
@class FSTMaybeDocument;
@class FSTObjectValue;
@class FSTSnapshotVersion;
@class FSTTimestamp;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTFieldMask

/**
 * Provides a set of fields that can be used to partially patch a document. FieldMask is used in
 * conjunction with ObjectValue.
 *
 * Examples:
 *   foo - Overwrites foo entirely with the provided value. If foo is not present in the companion
 *       ObjectValue, the field is deleted.
 *   foo.bar - Overwrites only the field bar of the object foo. If foo is not an object, foo is
 *       replaced with an object containing bar.
 */
@interface FSTFieldMask : NSObject
- (id)init __attribute__((unavailable("Use initWithFields:")));

/**
 * Initializes the field mask with the given field paths. Caller is expected to either copy or
 * or release the array of fields.
 */
- (instancetype)initWithFields:(NSArray<FSTFieldPath *> *)fields NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) NSArray<FSTFieldPath *> *fields;
@end

#pragma mark - FSTFieldTransform

/** Represents a transform within a TransformMutation. */
@protocol FSTTransformOperation <NSObject>
@end

/** Transforms a value into a server-generated timestamp. */
@interface FSTServerTimestampTransform : NSObject <FSTTransformOperation>
+ (instancetype)serverTimestampTransform;
@end

/** A field path and the FSTTransformOperation to perform upon it. */
@interface FSTFieldTransform : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPath:(FSTFieldPath *)path
                   transform:(id<FSTTransformOperation>)transform NS_DESIGNATED_INITIALIZER;
@property(nonatomic, strong, readonly) FSTFieldPath *path;
@property(nonatomic, strong, readonly) id<FSTTransformOperation> transform;
@end

#pragma mark - FSTPrecondition

typedef NS_ENUM(NSUInteger, FSTPreconditionExists) {
  FSTPreconditionExistsNotSet,
  FSTPreconditionExistsYes,
  FSTPreconditionExistsNo,
};

/**
 * Encodes a precondition for a mutation. This follows the model that the backend accepts with the
 * special case of an explicit "empty" precondition (meaning no precondition).
 */
@interface FSTPrecondition : NSObject

/** Creates a new FSTPrecondition with an exists flag. */
+ (FSTPrecondition *)preconditionWithExists:(BOOL)exists;

/** Creates a new FSTPrecondition based on a time the document exists at. */
+ (FSTPrecondition *)preconditionWithUpdateTime:(FSTSnapshotVersion *)updateTime;

/** Returns a precondition representing no precondition. */
+ (FSTPrecondition *)none;

/**
 * Returns true if the preconditions is valid for the given document (or null if no document is
 * available).
 */
- (BOOL)isValidForDocument:(FSTMaybeDocument *_Nullable)maybeDoc;

/** Returns whether this Precondition represents no precondition. */
- (BOOL)isNone;

/** If set, preconditions a mutation based on the last updateTime. */
@property(nonatomic, strong, readonly, nullable) FSTSnapshotVersion *updateTime;

/**
 * If set, preconditions a mutation based on whether the document exists.
 * Uses FSTPreconditionExistsNotSet to mark as unset.
 */
@property(nonatomic, assign, readonly) FSTPreconditionExists exists;

@end

#pragma mark - FSTMutationResult

@interface FSTMutationResult : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithVersion:(FSTSnapshotVersion *_Nullable)version
               transformResults:(NSArray<FSTFieldValue *> *_Nullable)transformResults
    NS_DESIGNATED_INITIALIZER;

/** The version at which the mutation was committed or null for a delete. */
@property(nonatomic, strong, readonly, nullable) FSTSnapshotVersion *version;

/**
 * The resulting fields returned from the backend after a FSTTransformMutation has been committed.
 * Contains one FieldValue for each FSTFieldTransform that was in the mutation.
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

- (instancetype)initWithKey:(FSTDocumentKey *)key
               precondition:(FSTPrecondition *)precondition NS_DESIGNATED_INITIALIZER;

/**
 * Applies this mutation to the given FSTDocument, FSTDeletedDocument or nil, if we don't have
 * information about this document. Both the input and returned documents can be nil.
 *
 * @param maybeDoc The document to mutate. The input document should nil if it does not currently
 * exist.
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
- (FSTMaybeDocument *_Nullable)applyTo:(FSTMaybeDocument *_Nullable)maybeDoc
                        localWriteTime:(FSTTimestamp *)localWriteTime
                        mutationResult:(FSTMutationResult *_Nullable)mutationResult;

/**
 * A helper version of applyTo for applying mutations locally (without a mutation result from the
 * backend).
 */
- (FSTMaybeDocument *_Nullable)applyTo:(FSTMaybeDocument *_Nullable)maybeDoc
                        localWriteTime:(FSTTimestamp *)localWriteTime;

@property(nonatomic, strong, readonly) FSTDocumentKey *key;

/** The precondition for this mutation. */
@property(nonatomic, strong, readonly) FSTPrecondition *precondition;

@end

#pragma mark - FSTSetMutation

/**
 * A mutation that creates or replaces the document at the given key with the object value
 * contents.
 */
@interface FSTSetMutation : FSTMutation

- (instancetype)initWithKey:(FSTDocumentKey *)key
               precondition:(FSTPrecondition *)precondition NS_UNAVAILABLE;

/**
 * Initializes the set mutation.
 *
 * @param key Identifies the location of the document to mutate.
 * @param value An object value that describes the contents to store at the location named by the
 * key.
 * @param precondition The precondition for this mutation.
 */
- (instancetype)initWithKey:(FSTDocumentKey *)key
                      value:(FSTObjectValue *)value
               precondition:(FSTPrecondition *)precondition NS_DESIGNATED_INITIALIZER;

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

/** Returns the precondition for the given FSTPrecondition. */
- (instancetype)initWithKey:(FSTDocumentKey *)key
               precondition:(FSTPrecondition *)precondition NS_UNAVAILABLE;

/**
 * Initializes a new patch mutation with an explicit FSTFieldMask and FSTObjectValue representing
 * the updates to perform
 *
 * @param key Identifies the location of the document to mutate.
 * @param fieldMask The field mask specifying at what locations the data in value should be
 * applied.
 * @param value An FSTObjectValue containing the data to be written (using the paths in fieldMask
 * to determine the locations at which it should be applied).
 * @param precondition The precondition for this mutation.
 */
- (instancetype)initWithKey:(FSTDocumentKey *)key
                  fieldMask:(FSTFieldMask *)fieldMask
                      value:(FSTObjectValue *)value
               precondition:(FSTPrecondition *)precondition NS_DESIGNATED_INITIALIZER;

/** The fields and associated values to use when patching the document. */
@property(nonatomic, strong, readonly) FSTObjectValue *value;

/**
 * A mask to apply to |value|, where only fields that are in both the fieldMask and the value
 * will be updated.
 */
@property(nonatomic, strong, readonly) FSTFieldMask *fieldMask;

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

- (instancetype)initWithKey:(FSTDocumentKey *)key
               precondition:(FSTPrecondition *)precondition NS_UNAVAILABLE;

/**
 * Initializes a new transform mutation with the specified field transforms.
 *
 * @param key Identifies the location of the document to mutate.
 * @param fieldTransforms A list of FSTFieldTransform objects to perform to the document.
 */
- (instancetype)initWithKey:(FSTDocumentKey *)key
            fieldTransforms:(NSArray<FSTFieldTransform *> *)fieldTransforms
    NS_DESIGNATED_INITIALIZER;

/** The field transforms to use when transforming the document. */
@property(nonatomic, strong, readonly) NSArray<FSTFieldTransform *> *fieldTransforms;

@end

#pragma mark - FSTDeleteMutation

@interface FSTDeleteMutation : FSTMutation

@end

NS_ASSUME_NONNULL_END
