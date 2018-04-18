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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MUTATIONS_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MUTATIONS_H_

#include <memory>
#include <vector>

#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace model {

/** Represents the result from a Mutation. */
class MutationResult {
 public:
  MutationResult(absl::optional<SnapshotVersion> version = absl::nullopt,
                 absl::optional<std::vector<FieldValue>> transform_results =
                     absl::nullopt);

  const absl::optional<SnapshotVersion>& version() const {
    return version_;
  }

  const absl::optional<std::vector<FieldValue>>& transform_results() const {
    return transform_results_;
  }

 private:
  // The version at which the mutation was committed or absl::nullopt
  // for a delete.
  absl::optional<SnapshotVersion> version_;

  // The resulting fields returned from the backend after a TransformMutation
  // has been committed. Contains one FieldValue for each FieldTransform that
  // was in the mutation.
  //
  // Will be absl::nullopt if the mutation was not a TransformMutation.
  absl::optional<std::vector<FieldValue>> transform_results_;
};

// TODO(zxu123): We might want to refactor mutations.h into several
// files when the number of different types of mutations grows gigantically.
// For now, put the interface and the only operation here.

/**
 * A mutation describes a self-contained change to a document. Mutations can
 * create, replace, delete, and update subsets of documents.
 *
 * ## Subclassing Notes
 *
 * Subclasses of Mutation need to implement -applyTo:hasLocalMutations: to
 * implement the actual the behavior of mutation as applied to some source
 * document.
 */
class Mutation {
 public:
  enum class Type {
    Set,
    Patch,
    Transform,
    Delete,
  };

  virtual ~Mutation() {
  }

  /** Provides the actual type of the mutation. */
  virtual Type type() const = 0;

  /** Provides equality check. */
  virtual bool operator==(const Mutation& other) const {
    return type() == other.type() && key_ == other.key_ &&
           precondition_ == other.precondition_;
  }

  /**
   * Applies this mutation to the given Document or NoDocument.,
   * if we don't have information about this document.
   *
   * @param maybe_doc The current state of the document to mutate.
   * @param base_doc The state of the document prior to this mutation batch. The
   * input document should be nil if it the document did not exist.
   * @param local_write_time A timestamp indicating the local write time of the
   * batch this mutation is a part of.
   * @param mutation_result Optional result info from the backend. If omitted,
   * it's assumed that this is merely a local (latency-compensated) application,
   * and the resulting document will have its has_local_mutations flag set.
   *
   * @return The mutated document. The returned document may be nil, but only if
   * maybe_doc was nil and the mutation would not create a new document.
   *
   * NOTE: We preserve the version of the base document only in case of Set or
   * Patch mutation to denote what version of original document we've changed.
   * In case of DeleteMutation we always reset the version.
   *
   * Here's the expected transition table.
   *
   * MUTATION         APPLIED TO            RESULTS IN
   *
   * SetMutation        Document(v3)          Document(v3)
   * SetMutation        NoDocument(v3)        Document(v0)
   * PatchMutation      Document(v3)          Document(v3)
   * PatchMutation      NoDocument(v3)        NoDocument(v3)
   * TransformMutation  Document(v3)          Document(v3)
   * TransformMutation  NoDocument(v3)        NoDocument(v3)
   * DeleteMutation     Document(v3)          NoDocument(v0)
   * DeleteMutation     NoDocument(v3)        NoDocument(v0)
   *
   * Note that TransformMutations don't create Document (in the case of
   * being applied to an NoDocument), even though they would on the
   * backend. This is because the client always combines the
   * TransformMutation with a SetMutation or PatchMutation and we only
   * want to apply the transform if the prior mutation resulted in an
   * Document (always true for an apply the transform if the prior mutation
   * resulted in a Document (always true for an SetMutation, but not
   * necessarily for an PatchMutation).
   */
  virtual MaybeDocumentPointer ApplyTo(
      const MaybeDocumentPointer& maybe_doc,
      const MaybeDocumentPointer& base_doc,
      const Timestamp& local_write_time,
      const absl::optional<MutationResult>& mutation_result) const = 0;

  /**
   * A helper version of applyTo for applying mutations locally (without a
   * mutation result from the backend).
   */
  virtual MaybeDocumentPointer ApplyTo(
      const MaybeDocumentPointer& maybe_doc,
      const MaybeDocumentPointer& base_doc,
      const Timestamp& local_write_time) const {
    return ApplyTo(maybe_doc, base_doc, local_write_time, absl::nullopt);
  }

  const DocumentKey& key() const {
    return key_;
  }

  const Precondition& precondition() const {
    return precondition_;
  }

 protected:
  Mutation(DocumentKey key, Precondition precondition);

  DocumentKey key_;
  Precondition precondition_;
};

/**
 * A mutation that creates or replaces the document at the given key with the
 * object value contents.
 */
class SetMutation : public Mutation {
 public:
  /**
   * Initializes the set mutation.
   *
   * @param key Identifies the location of the document to mutate.
   * @param value An object value that describes the contents to store at the
   * location named by the key.
   * @param precondition The precondition for this mutation.
   */
  SetMutation(DocumentKey key, FieldValue value, Precondition precondition);

  Type type() const override {
    return Type::Set;
  }

  bool operator==(const Mutation& other) const override {
    return Mutation::operator==(other) &&
           value_ == dynamic_cast<const SetMutation&>(other).value_;
  }

  MaybeDocumentPointer ApplyTo(
      const MaybeDocumentPointer& maybe_doc,
      const MaybeDocumentPointer& base_doc,
      const Timestamp& local_write_time,
      const absl::optional<MutationResult>& mutation_result) const override;

 private:
  // The object value to use when setting the document.
  FieldValue value_;
};

/**
 * A mutation that modifies fields of the document at the given key with the
 * given values. The values are applied through a field mask:
 *
 *  * When a field is in both the mask and the values, the corresponding field
 * is updated.
 *  * When a field is in neither the mask nor the values, the corresponding
 * field is unmodified.
 *  * When a field is in the mask but not in the values, the corresponding field
 * is deleted.
 *  * When a field is not in the mask but is in the values, the values map is
 * ignored.
 */
class PatchMutation : public Mutation {
 public:
  /**
   * Initializes a new patch mutation with an explicit FieldMask and FieldValue
   * representing the updates to perform
   *
   * @param key Identifies the location of the document to mutate.
   * @param field_mask The field mask specifying at what locations the data in
   * value should be applied.
   * @param value An object value containing the data to be written (using the
   * paths in field_mask to determine the locations at which it should be
   * applied).
   * @param precondition The precondition for this mutation.
   */
  PatchMutation(DocumentKey key,
                FieldMask field_mask,
                FieldValue value,
                Precondition precondition);

  Type type() const override {
    return Type::Patch;
  }

  bool operator==(const Mutation& other) const override {
    return Mutation::operator==(other) &&
           field_mask_ ==
               dynamic_cast<const PatchMutation&>(other).field_mask_ &&
           value_ == dynamic_cast<const PatchMutation&>(other).value_;
  }

  MaybeDocumentPointer ApplyTo(
      const MaybeDocumentPointer& maybe_doc,
      const MaybeDocumentPointer& base_doc,
      const Timestamp& local_write_time,
      const absl::optional<MutationResult>& mutation_result) const override;

 private:
  FieldValue PatchObject(FieldValue value) const;

  // A mask to apply to |value|, where only fields that are in both the
  // fieldMask and the value will be updated.
  FieldMask field_mask_;

  // The fields and associated values to use when patching the document.
  FieldValue value_;
};

/**
 * A mutation that modifies specific fields of the document with transform
 * operations. Currently the only supported transform is a server timestamp, but
 * IP Address, increment(n), etc. could be supported in the future.
 *
 * It is somewhat similar to a PatchMutation in that it patches specific fields
 * and has no effect when applied to nil or an NoDocument (see comment on
 * Mutation::ApplyTo() for rationale).
 */
class TransformMutation : public Mutation {
 public:
  /**
   * Initializes a new transform mutation with the specified field transforms.
   *
   * @param key Identifies the location of the document to mutate.
   * @param field_transforms A list of FieldTransform objects to perform to the
   * document.
   */
  TransformMutation(DocumentKey key,
                    std::vector<FieldTransform> field_transforms);

  Type type() const override {
    return Type::Transform;
  }

  bool operator==(const Mutation& other) const override {
    return Mutation::operator==(other) &&
           field_transforms_ ==
               dynamic_cast<const TransformMutation&>(other).field_transforms_;
  }

  MaybeDocumentPointer ApplyTo(
      const MaybeDocumentPointer& maybe_doc,
      const MaybeDocumentPointer& base_doc,
      const Timestamp& local_write_time,
      const absl::optional<MutationResult>& mutation_result) const override;

 private:
  /**
   * Creates an array of "transform results" (a transform result is a field
   * value representing the result of applying a transform) for use when
   * applying a TransformMutation locally.
   *
   * @param base_doc The document prior to applying this mutation batch.
   * @param local_write_time The local time of the transform mutation (used to
   * generate ServerTimestampValues).
   * @return The transform results array.
   */
  std::vector<FieldValue> LocalTransformResults(
      const MaybeDocumentPointer& base_doc,
      const Timestamp& local_write_time) const;

  FieldValue TransformObject(
      FieldValue value, const std::vector<FieldValue>& transform_results) const;

  // The field transforms to use when transforming the document.
  std::vector<FieldTransform> field_transforms_;
};

class DeleteMutation : public Mutation {
 public:
  DeleteMutation(DocumentKey key, Precondition precondition);

  Type type() const override {
    return Type::Delete;
  }

  MaybeDocumentPointer ApplyTo(
      const MaybeDocumentPointer& maybe_doc,
      const MaybeDocumentPointer& base_doc,
      const Timestamp& local_write_time,
      const absl::optional<MutationResult>& mutation_result) const override;
};

inline bool operator!=(const Mutation& lhs, const Mutation& rhs) {
  return !(lhs == rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MUTATIONS_H_
