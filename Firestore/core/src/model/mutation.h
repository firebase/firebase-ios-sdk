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

#ifndef FIRESTORE_CORE_SRC_MODEL_MUTATION_H_
#define FIRESTORE_CORE_SRC_MODEL_MUTATION_H_

#include <iosfwd>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/field_transform.h"
#include "Firestore/core/src/model/field_value.h"
#include "Firestore/core/src/model/precondition.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace model {

class MaybeDocument;

/**
 * The result of applying a mutation to the server. This is a model of the
 * WriteResult proto message.
 *
 * Note that MutationResult does not name which document was mutated. The
 * association is implied positionally: for each entry in the array of
 * Mutations, there's a corresponding entry in the array of MutationResults.
 */
class MutationResult {
 public:
  MutationResult(
      SnapshotVersion version,
      absl::optional<const std::vector<FieldValue>> transform_results)
      : version_(version), transform_results_(std::move(transform_results)) {
  }

  /**
   * The version at which the mutation was committed.
   *
   * - For most operations, this is the update_time in the WriteResult.
   * - For deletes, it is the commit_time of the WriteResponse (because
   *   deletes are not stored and have no update_time).
   *
   * Note that these versions can be different: No-op writes will not change
   * the update_time even though the commit_time advances.
   */
  const SnapshotVersion& version() const {
    return version_;
  }

  /**
   * The resulting fields returned from the backend after a TransformMutation
   * has been committed. Contains one FieldValue for each FieldTransform that
   * was in the mutation.
   *
   * Will be nullopt if the mutation was not a TransformMutation.
   */
  const absl::optional<const std::vector<FieldValue>>& transform_results()
      const {
    return transform_results_;
  }

  std::string ToString() const;

  friend std::ostream& operator<<(std::ostream& os,
                                  const MutationResult& result);

  friend bool operator==(const MutationResult& lhs, const MutationResult& rhs);

 private:
  SnapshotVersion version_;
  absl::optional<const std::vector<FieldValue>> transform_results_;
};

/**
 * Represents a Mutation of a document. Different subclasses of Mutation will
 * perform different kinds of changes to a base document. For example, a
 * SetMutation replaces the value of a document and a DeleteMutation deletes a
 * document.
 *
 * In addition to the value of the document mutations also operate on the
 * version. For local mutations (mutations that haven't been committed yet), we
 * preserve the existing version for Set and Patch mutations. For
 * local deletes, we reset the version to 0.
 *
 * Here's the expected transition table.
 *
 * MUTATION           APPLIED TO      RESULTS IN
 * SetMutation        Document(v3)    Document(v3)
 * SetMutation        NoDocument(v3)  Document(v0)
 * SetMutation        null            Document(v0)
 * PatchMutation      Document(v3)    Document(v3)
 * PatchMutation      NoDocument(v3)  NoDocument(v3)
 * PatchMutation      null            null
 * DeleteMutation     Document(v3)    NoDocument(v0)
 * DeleteMutation     NoDocument(v3)  NoDocument(v0)
 * DeleteMutation     null            NoDocument(v0)
 *
 * For acknowledged mutations, we use the update_time of the WriteResponse as
 * the resulting version for Set and Patch mutations. As deletes have no
 * explicit update time, we use the commit_time of the WriteResponse for
 * acknowledged deletes.
 *
 * If a mutation is acknowledged by the backend but fails the precondition
 * check locally, we return an `UnknownDocument` and rely on Watch to send us
 * the updated version.
 *
 * Field transforms are used only with Patch and Set Mutations. We use the
 * `updateTransforms` field to store transforms, rather than the `transforms`
 * message.
 *
 * Note: Mutation and its subclasses are specially designed to avoid slicing.
 * You can assign a subclass of Mutation to an instance of Mutation and the
 * full value is preserved, unsliced. Each subclass declares an explicit
 * constructor that can recover the derived type. This means that code like
 * this will work:
 *
 *     SetMutation set(...);
 *     Mutation mutation = set;
 *     SetMutation recovered(mutation);
 *
 * The final line results in an explicit check that will fail if the type of
 * the underlying data is not actually Type::Set.
 */
class Mutation {
 public:
  /**
   * Represents the mutation type. This is used in place of dynamic_cast.
   */
  enum class Type { Set, Patch, Delete, Verify };

  /** Creates an invalid mutation. */
  Mutation() = default;

  /**
   * Returns true if the given mutation is a valid instance. Default constructed
   * and moved-from Mutations are not valid.
   */
  bool is_valid() const {
    return rep_ != nullptr;
  }

  /** The runtime type of this mutation. */
  Type type() const {
    return rep().type();
  }

  const DocumentKey& key() const {
    return rep().key();
  }
  const Precondition& precondition() const {
    return rep().precondition();
  }

  const std::vector<FieldTransform>& field_transforms() const {
    return rep().field_transforms();
  }

  /**
   * Applies this mutation to the given MaybeDocument for the purposes of
   * computing the committed state of the document after the server has
   * acknowledged that this mutation has been successfully committed.  This
   * means that if the input document doesn't match the expected state (e.g. it
   * is `nullopt` or outdated), the local cache must have been incorrect so an
   * `UnknownDocument` is returned.
   *
   * @param maybe_doc The document to mutate. The input document can be
   *     `nullopt` if the client has no knowledge of the pre-mutation state of
   *     the document.
   * @param mutation_result The backend's response of successfully applying the
   *     mutation.
   * @return The mutated document. The returned document is not optional
   *     because the server successfully committed this mutation. If the local
   *     cache might have caused a `nullopt` result, this method will return an
   *     `UnknownDocument` instead.
   */
  MaybeDocument ApplyToRemoteDocument(
      const absl::optional<MaybeDocument>& maybe_doc,
      const MutationResult& mutation_result) const;

  /**
   * Estimates the latency compensated view of this mutation applied to the
   * given MaybeDocument.
   *
   * Unlike ApplyToRemoteDocument, this method is used before the mutation has
   * been committed and so it's possible that the mutation is operating on a
   * locally non-existent document and may produce a non-existent document.
   *
   * Note: `maybe_doc` and `base_doc` are similar but not the same:
   *
   *   - `base_doc` is the pristine version of the document as it was _before_
   *     applying any of the mutations in the batch. This means that for each
   *     mutation in the batch, `base_doc` stays unchanged;
   *   - `maybe_doc` is the state of the document _after_ applying all the
   *     preceding mutations from the batch. In other words, `maybe_doc` is
   *     passed on from one mutation in the batch to the next, accumulating
   *     changes.
   *
   * The only time `maybe_doc` and `base_doc` are guaranteed to be the same is
   * for the very first mutation in the batch. The distinction between
   * `maybe_doc` and `base_doc` helps ServerTimestampTransform determine the
   * "previous" value in a way that makes sense to users.
   *
   * @param maybe_doc The document to mutate. The input document can be
   *     `nullopt` if the client has no knowledge of the pre-mutation state of
   *     the document.
   * @param local_write_time A timestamp indicating the local write time of the
   *     batch this mutation is a part of.
   * @return The mutated document. The returned document may be nullopt, but
   *     only if maybe_doc was nullopt and the mutation would not create a new
   *     document.
   */
  absl::optional<MaybeDocument> ApplyToLocalView(
      const absl::optional<MaybeDocument>& maybe_doc,
      const Timestamp& local_write_time) const;

  /**
   * If this mutation is not idempotent, returns the base value to persist with
   * this mutation.  If a base value is returned, the mutation is always
   * applied to this base value, even if document has already been updated.
   *
   * The base value is a sparse object that consists of only the document
   * fields for which this mutation contains a non-idempotent transformation
   * (e.g. a numeric increment). The provided value guarantees consistent
   * behavior for non-idempotent transforms and allow us to return the same
   * latency-compensated value even if the backend has already applied the
   * mutation. The base value is empty for idempotent mutations, as they can be
   * re-played even if the backend has already applied them.
   *
   * @return a base value to store along with the mutation, or empty for
   *     idempotent mutations.
   */
  absl::optional<ObjectValue> ExtractTransformBaseValue(
      const absl::optional<MaybeDocument>& maybe_doc) const {
    return rep_->ExtractTransformBaseValue(maybe_doc);
  }

  friend bool operator==(const Mutation& lhs, const Mutation& rhs);

  size_t Hash() const {
    return rep().Hash();
  }

  std::string ToString() const {
    return rep_ ? rep().ToString() : "(invalid)";
  }

  friend std::ostream& operator<<(std::ostream& os, const Mutation& mutation);

 protected:
  class Rep {
   public:
    Rep(DocumentKey&& key, Precondition&& precondition);

    Rep(DocumentKey&& key,
        Precondition&& precondition,
        std::vector<FieldTransform>&& field_transforms);

    virtual ~Rep() = default;

    virtual Type type() const = 0;

    const DocumentKey& key() const {
      return key_;
    }

    const Precondition& precondition() const {
      return precondition_;
    }

    const std::vector<FieldTransform>& field_transforms() const {
      return field_transforms_;
    }

    virtual MaybeDocument ApplyToRemoteDocument(
        const absl::optional<MaybeDocument>& maybe_doc,
        const MutationResult& mutation_result) const = 0;

    virtual absl::optional<MaybeDocument> ApplyToLocalView(
        const absl::optional<MaybeDocument>& maybe_doc,
        const Timestamp& local_write_time) const = 0;

    virtual absl::optional<ObjectValue> ExtractTransformBaseValue(
        const absl::optional<MaybeDocument>&) const;

    /**
     * Creates an array of "transform results" (a transform result is a field
     * value representing the result of applying a transform) for use after a
     * mutation containing transforms has been acknowledged by the server.
     *
     * @param maybe_doc The current state of the document after applying all
     *     previous mutations.
     * @param server_transform_results The transform results received by the
     *     server.
     * @return The transform results array.
     */
    virtual std::vector<FieldValue> ServerTransformResults(
        const absl::optional<MaybeDocument>& maybe_doc,
        const std::vector<FieldValue>& server_transform_results) const;

    /**
     * Creates an array of "transform results" (a transform result is a field
     * value representing the result of applying a transform) for use when
     * applying a transform locally.
     *
     * @param maybe_doc The current state of the document after applying all
     *     previous mutations.
     * @param local_write_time The local time of the transform (used to
     *     generate ServerTimestampValues).
     * @return The transform results array.
     */
    virtual std::vector<FieldValue> LocalTransformResults(
        const absl::optional<MaybeDocument>& maybe_doc,
        const Timestamp& local_write_time) const;

    virtual ObjectValue TransformObject(
        ObjectValue object_value,
        const std::vector<FieldValue>& transform_results) const;

    virtual bool Equals(const Rep& other) const;

    virtual size_t Hash() const;

    virtual std::string ToString() const = 0;

   protected:
    void VerifyKeyMatches(const absl::optional<MaybeDocument>& maybe_doc) const;

    static SnapshotVersion GetPostMutationVersion(
        const absl::optional<MaybeDocument>& maybe_doc);

   private:
    DocumentKey key_;
    Precondition precondition_;
    std::vector<FieldTransform> field_transforms_;
  };

  explicit Mutation(std::shared_ptr<Rep>&& rep) : rep_(std::move(rep)) {
  }

  const Rep& rep() const {
    return *NOT_NULL(rep_);
  }

 private:
  std::shared_ptr<Rep> rep_;
};

inline bool operator!=(const Mutation& lhs, const Mutation& rhs) {
  return !(lhs == rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_MUTATION_H_
