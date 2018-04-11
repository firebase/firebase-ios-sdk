/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/model/mutations.h"

#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace model {

MutationResult::MutationResult(SnapshotVersion version,
                               std::vector<FieldValue> transform_results)
    : version_(std::move(version)),
      transform_results_(std::move(transform_results)) {
}

Mutation::Mutation(DocumentKey key, Precondition precondition)
    : key_(std::move(key)), precondition_(std::move(precondition)) {
}

SetMutation::SetMutation(DocumentKey key,
                         FieldValue value,
                         Precondition precondition)
    : Mutation(std::move(key), std::move(precondition)),
      value_(std::move(value)) {
}

MaybeDocument SetMutation::ApplyTo(
    const MaybeDocument& maybe_doc,
    const MaybeDocument& base_doc,
    const Timestamp& local_write_time,
    const MutationResult& mutation_result) const {
  FIREBASE_ASSERT_MESSAGE(mutation_result.transform_results.empty(), "Transform results received by FSTSetMutation.");

  if (!precondition_.IsValidFor(maybeDoc)) {
    return maybeDoc;
  }

  BOOL hasLocalMutations = (mutationResult == nil);
  if (!maybeDoc || [maybeDoc isMemberOfClass:[FSTDeletedDocument class]]) {
    // If the document didn't exist before, create it.
    return [FSTDocument documentWithData:self.value
                                     key:self.key
                                 version:[FSTSnapshotVersion noVersion]
                       hasLocalMutations:hasLocalMutations];
  }

  FSTAssert([maybeDoc isMemberOfClass:[FSTDocument class]], @"Unknown
  MaybeDocument type %@", [maybeDoc class]); FSTDocument *doc = (FSTDocument
  *)maybeDoc;

  FSTAssert([doc.key isEqual:self.key], @"Can only set a document with the same
  key"); return [FSTDocument documentWithData:self.value key:doc.key
                               version:doc.version
                     hasLocalMutations:hasLocalMutations];
  */
  return MaybeDocument{key_, SnapshotVersion::None()};
}

PatchMutation::PatchMutation(DocumentKey key,
                             FieldMask field_mask,
                             FieldValue value,
                             Precondition precondition)
    : Mutation(std::move(key), std::move(precondition)),
      field_mask_(std::move(field_mask)),
      value_(std::move(value)) {
}

MaybeDocument PatchMutation::ApplyTo(
    const MaybeDocument& maybe_doc,
    const MaybeDocument& base_doc,
    const Timestamp& local_write_time,
    const MutationResult& mutation_result) const {
  /*
    if (mutationResult) {
    FSTAssert(!mutationResult.transformResults, @"Transform results received by
  FSTPatchMutation.");
  }

  if (!self.precondition.IsValidFor(maybeDoc)) {
    return maybeDoc;
  }

  BOOL hasLocalMutations = (mutationResult == nil);
  if (!maybeDoc || [maybeDoc isMemberOfClass:[FSTDeletedDocument class]]) {
    // Precondition applied, so create the document if necessary
    const DocumentKey &key = maybeDoc ? maybeDoc.key : self.key;
    FSTSnapshotVersion *version = maybeDoc ? maybeDoc.version :
  [FSTSnapshotVersion noVersion]; maybeDoc = [FSTDocument
  documentWithData:[FSTObjectValue objectValue] key:key version:version
                           hasLocalMutations:hasLocalMutations];
  }

  FSTAssert([maybeDoc isMemberOfClass:[FSTDocument class]], @"Unknown
  MaybeDocument type %@", [maybeDoc class]); FSTDocument *doc = (FSTDocument
  *)maybeDoc;

  FSTAssert([doc.key isEqual:self.key], @"Can only patch a document with the
  same key");

  FSTObjectValue *newData = [self patchObjectValue:doc.data];
  return [FSTDocument documentWithData:newData
                                   key:doc.key
                               version:doc.version
                     hasLocalMutations:hasLocalMutations];
  */
  return MaybeDocument{key_, SnapshotVersion::None()};
}

TransformMutation::TransformMutation(
    DocumentKey key, std::vector<FieldTransform> field_transforms)
    // NOTE: We set a precondition of exists: true as a safety-check, since we
    // always combine TransformMutations with a SetMutation or PatchMutation
    // which (if successful) should end up with an existing document.
    : Mutation(std::move(key), Precondition::Exists(true)),
      field_transforms_(std::move(field_transforms)) {
}

MaybeDocument TransformMutation::ApplyTo(
    const MaybeDocument& maybe_doc,
    const MaybeDocument& base_doc,
    const Timestamp& local_write_time,
    const MutationResult& mutation_result) const {
  /*
    if (mutationResult) {
    FSTAssert(mutationResult.transformResults,
              @"Transform results missing for FSTTransformMutation.");
  }

  if (!self.precondition.IsValidFor(maybeDoc)) {
    return maybeDoc;
  }

  // We only support transforms with precondition exists, so we can only apply
  it to an existing
  // document
  FSTAssert([maybeDoc isMemberOfClass:[FSTDocument class]], @"Unknown
  MaybeDocument type %@", [maybeDoc class]); FSTDocument *doc = (FSTDocument
  *)maybeDoc;

  FSTAssert([doc.key isEqual:self.key], @"Can only patch a document with the
  same key");

  BOOL hasLocalMutations = (mutationResult == nil);
  NSArray<FSTFieldValue *> *transformResults =
      mutationResult
          ? mutationResult.transformResults
          : [self localTransformResultsWithBaseDocument:baseDoc
  writeTime:localWriteTime]; FSTObjectValue *newData = [self
  transformObject:doc.data transformResults:transformResults]; return
  [FSTDocument documentWithData:newData key:doc.key version:doc.version
                     hasLocalMutations:hasLocalMutations];
  */
  return MaybeDocument{key_, SnapshotVersion::None()};
}

DeleteMutation::DeleteMutation(DocumentKey key, Precondition precondition)
    : Mutation(std::move(key), std::move(precondition)) {
}

MaybeDocument DeleteMutation::ApplyTo(
    const MaybeDocument& maybe_doc,
    const MaybeDocument& base_doc,
    const Timestamp& local_write_time,
    const MutationResult& mutation_result) const {
  /*
    if (mutationResult) {
    FSTAssert(!mutationResult.transformResults,
              @"Transform results received by FSTDeleteMutation.");
  }

  if (!self.precondition.IsValidFor(maybeDoc)) {
    return maybeDoc;
  }

  if (maybeDoc) {
    FSTAssert([maybeDoc.key isEqual:self.key], @"Can only delete a document with
  the same key");
  }

  return [FSTDeletedDocument documentWithKey:self.key
  version:[FSTSnapshotVersion noVersion]];
  */
  return MaybeDocument{key_, SnapshotVersion::None()};
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
