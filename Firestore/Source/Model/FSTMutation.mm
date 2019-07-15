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

#import "Firestore/Source/Model/FSTMutation.h"

#include <memory>
#include <set>
#include <string>
#include <utility>
#include <vector>

#import "FIRTimestamp.h"

#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Util/FSTClasses.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::Timestamp;
using firebase::firestore::model::ArrayTransform;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::ServerTimestampTransform;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TransformOperation;
using firebase::firestore::util::Hash;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTMutationResult

@implementation FSTMutationResult {
  SnapshotVersion _version;
  absl::optional<std::vector<FieldValue>> _transformResults;
}

- (instancetype)initWithVersion:(SnapshotVersion)version
               transformResults:(absl::optional<std::vector<FieldValue>>)transformResults {
  if (self = [super init]) {
    _version = std::move(version);
    _transformResults = std::move(transformResults);
  }
  return self;
}

- (const SnapshotVersion &)version {
  return _version;
}

@end

#pragma mark - FSTMutation

@implementation FSTMutation {
  DocumentKey _key;
  Precondition _precondition;
}

- (instancetype)initWithKey:(DocumentKey)key precondition:(Precondition)precondition {
  if (self = [super init]) {
    _key = std::move(key);
    _precondition = std::move(precondition);
  }
  return self;
}

- (FSTMaybeDocument *)applyToRemoteDocument:(nullable FSTMaybeDocument *)maybeDoc
                             mutationResult:(FSTMutationResult *)mutationResult {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (nullable FSTMaybeDocument *)applyToLocalDocument:(nullable FSTMaybeDocument *)maybeDoc
                                       baseDocument:(nullable FSTMaybeDocument *)baseDoc
                                     localWriteTime:(const Timestamp &)localWriteTime {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (absl::optional<ObjectValue>)extractBaseValue:(nullable FSTMaybeDocument *)maybeDoc {
  return absl::nullopt;
}

- (const DocumentKey &)key {
  return _key;
}

- (const firebase::firestore::model::Precondition &)precondition {
  return _precondition;
}

- (void)verifyKeyMatches:(nullable FSTMaybeDocument *)maybeDoc {
  if (maybeDoc) {
    HARD_ASSERT(maybeDoc.key == self.key, "Can only set a document with the same key");
  }
}

/**
 * Returns the version from the given document for use as the result of a mutation. Mutations are
 * defined to return the version of the base document only if it is an existing document. Deleted
 * and unknown documents have a post-mutation version of {@code SnapshotVersion::None()}.
 */
- (const SnapshotVersion &)postMutationVersionForDocument:(FSTMaybeDocument *)maybeDoc {
  return [maybeDoc isKindOfClass:[FSTDocument class]] ? maybeDoc.version : SnapshotVersion::None();
}
@end

#pragma mark - FSTSetMutation

@implementation FSTSetMutation {
}

- (instancetype)initWithKey:(DocumentKey)key
                      value:(ObjectValue)value
               precondition:(Precondition)precondition {
  if (self = [super initWithKey:std::move(key) precondition:std::move(precondition)]) {
    _value = std::move(value);
  }
  return self;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTSetMutation key=%s value=%s precondition=%@>",
                                    self.key.ToString().c_str(), self.value.ToString().c_str(),
                                    self.precondition.description()];
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTSetMutation class]]) {
    return NO;
  }

  FSTSetMutation *otherMutation = (FSTSetMutation *)other;
  return self.key == otherMutation.key && self.value == otherMutation.value &&
         self.precondition == otherMutation.precondition;
}

- (NSUInteger)hash {
  return Hash(self.key, self.precondition, self.value);
}

- (nullable FSTMaybeDocument *)applyToLocalDocument:(nullable FSTMaybeDocument *)maybeDoc
                                       baseDocument:(nullable FSTMaybeDocument *)baseDoc
                                     localWriteTime:(const Timestamp &)localWriteTime {
  [self verifyKeyMatches:maybeDoc];

  if (!self.precondition.IsValidFor(maybeDoc)) {
    return maybeDoc;
  }

  SnapshotVersion version = [self postMutationVersionForDocument:maybeDoc];
  return [FSTDocument documentWithData:self.value
                                   key:self.key
                               version:version
                                 state:DocumentState::kLocalMutations];
}

- (FSTMaybeDocument *)applyToRemoteDocument:(nullable FSTMaybeDocument *)maybeDoc
                             mutationResult:(FSTMutationResult *)mutationResult {
  [self verifyKeyMatches:maybeDoc];

  HARD_ASSERT(!mutationResult.transformResults, "Transform results received by FSTSetMutation.");

  // Unlike applyToLocalView, if we're applying a mutation to a remote document the server has
  // accepted the mutation so the precondition must have held.

  return [FSTDocument documentWithData:self.value
                                   key:self.key
                               version:mutationResult.version
                                 state:DocumentState::kCommittedMutations];
}

- (absl::optional<ObjectValue>)extractBaseValue:(nullable FSTMaybeDocument *)maybeDoc {
  return absl::nullopt;
}

@end

#pragma mark - FSTPatchMutation

@implementation FSTPatchMutation {
  FieldMask _fieldMask;
}

- (instancetype)initWithKey:(DocumentKey)key
                  fieldMask:(FieldMask)fieldMask
                      value:(ObjectValue)value
               precondition:(Precondition)precondition {
  self = [super initWithKey:std::move(key) precondition:std::move(precondition)];
  if (self) {
    _fieldMask = std::move(fieldMask);
    _value = value;
  }
  return self;
}

- (const FieldMask *)fieldMask {
  return &_fieldMask;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTPatchMutation class]]) {
    return NO;
  }

  FSTPatchMutation *otherMutation = (FSTPatchMutation *)other;
  return self.key == otherMutation.key && _fieldMask == *(otherMutation.fieldMask) &&
         self.value == otherMutation.value && self.precondition == otherMutation.precondition;
}

- (NSUInteger)hash {
  return Hash(self.key, self.precondition, _fieldMask, self.value);
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTPatchMutation key=%s mask=%s value=%s precondition=%@>",
                                    self.key.ToString().c_str(), _fieldMask.ToString().c_str(),
                                    self.value.ToString().c_str(), self.precondition.description()];
}

/**
 * Patches the data of document if available or creates a new document. Note that this does not
 * check whether or not the precondition of this patch holds.
 */
- (ObjectValue)patchDocument:(nullable FSTMaybeDocument *)maybeDoc {
  ObjectValue data;
  if ([maybeDoc isKindOfClass:[FSTDocument class]]) {
    data = ((FSTDocument *)maybeDoc).data;
  } else {
    data = ObjectValue::Empty();
  }
  return [self patchObjectValue:data];
}

- (nullable FSTMaybeDocument *)applyToLocalDocument:(nullable FSTMaybeDocument *)maybeDoc
                                       baseDocument:(nullable FSTMaybeDocument *)baseDoc
                                     localWriteTime:(const Timestamp &)localWriteTime {
  [self verifyKeyMatches:maybeDoc];

  if (!self.precondition.IsValidFor(maybeDoc)) {
    return maybeDoc;
  }

  ObjectValue newData = [self patchDocument:maybeDoc];
  SnapshotVersion version = [self postMutationVersionForDocument:maybeDoc];

  return [FSTDocument documentWithData:newData
                                   key:self.key
                               version:version
                                 state:DocumentState::kLocalMutations];
}

- (absl::optional<ObjectValue>)extractBaseValue:(nullable FSTMaybeDocument *)maybeDoc {
  return absl::nullopt;
}

- (FSTMaybeDocument *)applyToRemoteDocument:(nullable FSTMaybeDocument *)maybeDoc
                             mutationResult:(FSTMutationResult *)mutationResult {
  [self verifyKeyMatches:maybeDoc];

  HARD_ASSERT(!mutationResult.transformResults, "Transform results received by FSTPatchMutation.");

  if (!self.precondition.IsValidFor(maybeDoc)) {
    // Since the mutation was not rejected, we know that the precondition matched on the backend.
    // We therefore must not have the expected version of the document in our cache and return a
    // FSTUnknownDocument with the known updateTime.
    return [FSTUnknownDocument documentWithKey:self.key version:mutationResult.version];
  }

  ObjectValue newData = [self patchDocument:maybeDoc];

  return [FSTDocument documentWithData:newData
                                   key:self.key
                               version:mutationResult.version
                                 state:DocumentState::kCommittedMutations];
}

- (ObjectValue)patchObjectValue:(ObjectValue)objectValue {
  ObjectValue result = std::move(objectValue);
  for (const FieldPath &fieldPath : _fieldMask) {
    if (!fieldPath.empty()) {
      absl::optional<FieldValue> newValue = self.value.Get(fieldPath);
      if (newValue) {
        result = result.Set(fieldPath, *newValue);
      } else {
        result = result.Delete(fieldPath);
      }
    }
  }
  return result;
}

@end

@implementation FSTTransformMutation {
  /** The field transforms to use when transforming the document. */
  std::vector<FieldTransform> _fieldTransforms;
  FieldMask _fieldMask;
}

- (instancetype)initWithKey:(DocumentKey)key
            fieldTransforms:(std::vector<FieldTransform>)fieldTransforms {
  // NOTE: We set a precondition of exists: true as a safety-check, since we always combine
  // FSTTransformMutations with a FSTSetMutation or FSTPatchMutation which (if successful) should
  // end up with an existing document.
  if (self = [super initWithKey:std::move(key) precondition:Precondition::Exists(true)]) {
    _fieldTransforms = std::move(fieldTransforms);

    std::set<FieldPath> fields;
    for (const auto &transform : _fieldTransforms) {
      fields.insert(transform.path());
    }

    _fieldMask = FieldMask(std::move(fields));
  }
  return self;
}

- (const std::vector<FieldTransform> &)fieldTransforms {
  return _fieldTransforms;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTTransformMutation class]]) {
    return NO;
  }

  FSTTransformMutation *otherMutation = (FSTTransformMutation *)other;
  return self.key == otherMutation.key && self.fieldTransforms == otherMutation.fieldTransforms &&
         self.precondition == otherMutation.precondition;
}

- (NSUInteger)hash {
  NSUInteger result = self.key.Hash();
  result = 31 * result + self.precondition.Hash();
  for (const auto &transform : self.fieldTransforms) {
    result = 31 * result + transform.Hash();
  }
  return result;
}

- (NSString *)description {
  std::string fieldTransforms;
  for (const auto &transform : self.fieldTransforms) {
    fieldTransforms += " " + transform.path().CanonicalString();
  }
  return [NSString stringWithFormat:@"<FSTTransformMutation key=%s transforms=%s precondition=%@>",
                                    self.key.ToString().c_str(), fieldTransforms.c_str(),
                                    self.precondition.description()];
}

- (nullable FSTMaybeDocument *)applyToLocalDocument:(nullable FSTMaybeDocument *)maybeDoc
                                       baseDocument:(nullable FSTMaybeDocument *)baseDoc
                                     localWriteTime:(const Timestamp &)localWriteTime {
  [self verifyKeyMatches:maybeDoc];

  if (!self.precondition.IsValidFor(maybeDoc)) {
    return maybeDoc;
  }

  // We only support transforms with precondition exists, so we can only apply it to an existing
  // document
  HARD_ASSERT([maybeDoc isMemberOfClass:[FSTDocument class]], "Unknown MaybeDocument type %s",
              [maybeDoc class]);
  FSTDocument *doc = (FSTDocument *)maybeDoc;

  std::vector<FieldValue> transformResults =
      [self localTransformResultsWithLocalDocument:maybeDoc
                                      baseDocument:baseDoc
                                         writeTime:localWriteTime];
  ObjectValue newData = [self transformObject:doc.data transformResults:transformResults];

  return [FSTDocument documentWithData:std::move(newData)
                                   key:doc.key
                               version:doc.version
                                 state:DocumentState::kLocalMutations];
}

- (FSTMaybeDocument *)applyToRemoteDocument:(nullable FSTMaybeDocument *)maybeDoc
                             mutationResult:(FSTMutationResult *)mutationResult {
  [self verifyKeyMatches:maybeDoc];

  HARD_ASSERT(mutationResult.transformResults,
              "Transform results missing for FSTTransformMutation.");

  if (!self.precondition.IsValidFor(maybeDoc)) {
    // Since the mutation was not rejected, we know that the precondition matched on the backend.
    // We therefore must not have the expected version of the document in our cache and return an
    // FSTUnknownDocument with the known updateTime.
    return [FSTUnknownDocument documentWithKey:self.key version:mutationResult.version];
  }

  // We only support transforms with precondition exists, so we can only apply it to an existing
  // document
  HARD_ASSERT([maybeDoc isMemberOfClass:[FSTDocument class]], "Unknown MaybeDocument type %s",
              [maybeDoc class]);
  FSTDocument *doc = (FSTDocument *)maybeDoc;

  HARD_ASSERT(mutationResult.transformResults.has_value());

  std::vector<FieldValue> transformResults =
      [self serverTransformResultsWithBaseDocument:maybeDoc
                            serverTransformResults:*mutationResult.transformResults];

  ObjectValue newData = [self transformObject:doc.data transformResults:transformResults];

  return [FSTDocument documentWithData:newData
                                   key:self.key
                               version:mutationResult.version
                                 state:DocumentState::kCommittedMutations];
}

- (absl::optional<ObjectValue>)extractBaseValue:(nullable FSTMaybeDocument *)maybeDoc {
  absl::optional<ObjectValue> base_object = absl::nullopt;

  for (const FieldTransform &transform : self.fieldTransforms) {
    absl::optional<FieldValue> existing_value;
    if ([maybeDoc isKindOfClass:[FSTDocument class]]) {
      existing_value = {[((FSTDocument *)maybeDoc) fieldForPath:transform.path()]};
    }

    absl::optional<FieldValue> coerced_value =
        transform.transformation().ComputeBaseValue(existing_value);
    if (coerced_value) {
      if (!base_object) {
        base_object = {ObjectValue::Empty()};
      }
      base_object = {base_object->Set(transform.path(), *coerced_value)};
    }
  }

  return base_object;
}

/**
 * Creates an array of "transform results" (a transform result is a field value representing the
 * result of applying a transform) for use after a FSTTransformMutation has been acknowledged by
 * the server.
 *
 * @param baseDocument The document prior to applying this mutation batch.
 * @param serverTransformResults The transform results received by the server.
 * @return The transform results array.
 */
- (std::vector<FieldValue>)
    serverTransformResultsWithBaseDocument:(nullable FSTMaybeDocument *)baseDocument
                    serverTransformResults:(const std::vector<FieldValue> &)serverTransformResults {
  std::vector<FieldValue> transformResults;
  HARD_ASSERT(self.fieldTransforms.size() == serverTransformResults.size(),
              "server transform result count (%s) should match field transforms count (%s)",
              serverTransformResults.size(), self.fieldTransforms.size());

  for (size_t i = 0; i < serverTransformResults.size(); i++) {
    const FieldTransform &fieldTransform = self.fieldTransforms[i];
    const TransformOperation &transform = fieldTransform.transformation();

    absl::optional<model::FieldValue> previousValue;
    if ([baseDocument isMemberOfClass:[FSTDocument class]]) {
      previousValue = [((FSTDocument *)baseDocument) fieldForPath:fieldTransform.path()];
    }

    transformResults.push_back(
        transform.ApplyToRemoteDocument(previousValue, serverTransformResults[i]));
  }
  return transformResults;
}

/**
 * Creates an array of "transform results" (a transform result is a field value representing the
 * result of applying a transform) for use when applying an FSTTransformMutation locally.
 *
 * @param maybeDocument The current state of the document after applying all previous mutations.
 * @param baseDocument The document prior to applying this mutation batch.
 * @param localWriteTime The local time of the transform mutation (used to generate
 *     ServerTimestampValues).
 * @return The transform results array.
 */
- (std::vector<FieldValue>)
    localTransformResultsWithLocalDocument:(nullable FSTMaybeDocument *)maybeDocument
                              baseDocument:(nullable FSTMaybeDocument *)baseDocument
                                 writeTime:(const Timestamp &)localWriteTime {
  std::vector<FieldValue> transformResults;
  for (const FieldTransform &fieldTransform : self.fieldTransforms) {
    const TransformOperation &transform = fieldTransform.transformation();

    absl::optional<FieldValue> previousValue;
    if ([maybeDocument isMemberOfClass:[FSTDocument class]]) {
      previousValue = [((FSTDocument *)maybeDocument) fieldForPath:fieldTransform.path()];
    }

    if (!previousValue && [baseDocument isMemberOfClass:[FSTDocument class]]) {
      // If the current document does not contain a value for the mutated field, use the value
      // that existed before applying this mutation batch. This solves an edge case where a
      // FSTPatchMutation clears the values in a nested map before the FSTTransformMutation is
      // applied.
      previousValue = [((FSTDocument *)baseDocument) fieldForPath:fieldTransform.path()];
    }
    transformResults.push_back(transform.ApplyToLocalView(previousValue, localWriteTime));
  }
  return transformResults;
}

- (ObjectValue)transformObject:(ObjectValue)objectValue
              transformResults:(const std::vector<FieldValue> &)transformResults {
  HARD_ASSERT(transformResults.size() == self.fieldTransforms.size(),
              "Transform results length mismatch.");

  for (size_t i = 0; i < self.fieldTransforms.size(); i++) {
    const FieldTransform &fieldTransform = self.fieldTransforms[i];
    const FieldPath &fieldPath = fieldTransform.path();
    objectValue = objectValue.Set(fieldPath, transformResults[i]);
  }
  return objectValue;
}

@end

#pragma mark - FSTDeleteMutation

@implementation FSTDeleteMutation

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[FSTDeleteMutation class]]) {
    return NO;
  }

  FSTDeleteMutation *otherMutation = (FSTDeleteMutation *)other;
  return self.key == otherMutation.key && self.precondition == otherMutation.precondition;
}

- (NSUInteger)hash {
  return Hash(self.key, self.precondition);
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTDeleteMutation key=%s precondition=%@>",
                                    self.key.ToString().c_str(), self.precondition.description()];
}

- (nullable FSTMaybeDocument *)applyToLocalDocument:(nullable FSTMaybeDocument *)maybeDoc
                                       baseDocument:(nullable FSTMaybeDocument *)baseDoc
                                     localWriteTime:(const Timestamp &)localWriteTime {
  [self verifyKeyMatches:maybeDoc];

  if (!self.precondition.IsValidFor(maybeDoc)) {
    return maybeDoc;
  }

  return [FSTDeletedDocument documentWithKey:self.key
                                     version:SnapshotVersion::None()
                       hasCommittedMutations:NO];
}

- (FSTMaybeDocument *)applyToRemoteDocument:(nullable FSTMaybeDocument *)maybeDoc
                             mutationResult:(FSTMutationResult *)mutationResult {
  [self verifyKeyMatches:maybeDoc];

  if (mutationResult) {
    HARD_ASSERT(!mutationResult.transformResults,
                "Transform results received by FSTDeleteMutation.");
  }

  // Unlike applyToLocalView, if we're applying a mutation to a remote document the server has
  // accepted the mutation so the precondition must have held.

  // We store the deleted document at the commit version of the delete. Any document version
  // that the server sends us before the delete was applied is discarded
  return [FSTDeletedDocument documentWithKey:self.key
                                     version:mutationResult.version
                       hasCommittedMutations:YES];
}

- (absl::optional<ObjectValue>)extractBaseValue:(nullable FSTMaybeDocument *)maybeDoc {
  return absl::nullopt;
}

@end

NS_ASSUME_NONNULL_END
