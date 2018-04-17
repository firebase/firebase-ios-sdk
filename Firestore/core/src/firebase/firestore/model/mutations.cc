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

#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace model {

MutationResult::MutationResult(
    absl::optional<SnapshotVersion> version,
    absl::optional<std::vector<FieldValue>> transform_results)
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

MaybeDocumentPointer SetMutation::ApplyTo(
    const MaybeDocumentPointer& maybe_doc,
    const MaybeDocumentPointer& /* base_doc */,
    const Timestamp& /* local_write_time */,
    const absl::optional<MutationResult>& mutation_result) const {
  if (mutation_result) {
    FIREBASE_ASSERT_MESSAGE(!mutation_result->transform_results(),
                            "Transform results received by SetMutation.");
  }

  if (!precondition_.IsValidFor(maybe_doc)) {
    return maybe_doc;
  }

  bool has_local_mutations = mutation_result.has_value();
  if (!maybe_doc || maybe_doc->type() == MaybeDocument::Type::NoDocument) {
    // If the document didn't exist before, create it.
    return std::make_shared<Document>(
        FieldValue{value_}, key_, SnapshotVersion::None(), has_local_mutations);
  }

  FIREBASE_ASSERT_MESSAGE(maybe_doc->type() == MaybeDocument::Type::Document,
                          "Unknown MaybeDocument type %d", maybe_doc->type());
  const Document* doc = static_cast<Document*>(maybe_doc.get());

  FIREBASE_ASSERT_MESSAGE(doc->key() == key_,
                          "Can only set a document with the same key");
  return std::make_shared<Document>(FieldValue{value_}, key_, doc->version(),
                                    has_local_mutations);
}

PatchMutation::PatchMutation(DocumentKey key,
                             FieldMask field_mask,
                             FieldValue value,
                             Precondition precondition)
    : Mutation(std::move(key), std::move(precondition)),
      field_mask_(std::move(field_mask)),
      value_(std::move(value)) {
}

MaybeDocumentPointer PatchMutation::ApplyTo(
    const MaybeDocumentPointer& maybe_doc,
    const MaybeDocumentPointer& /* base_doc */,
    const Timestamp& /* local_write_time */,
    const absl::optional<MutationResult>& mutation_result) const {
  if (mutation_result) {
    FIREBASE_ASSERT_MESSAGE(!mutation_result->transform_results(),
                            "Transform results received by PatchMutation.");
  }

  if (!precondition_.IsValidFor(maybe_doc)) {
    return maybe_doc;
  }

  bool has_local_mutations = mutation_result.has_value();
  if (!maybe_doc || maybe_doc->type() == MaybeDocument::Type::NoDocument) {
    // Precondition applied, so create the document if necessary
    const DocumentKey& key = maybe_doc ? maybe_doc->key() : key_;
    const SnapshotVersion& version =
        maybe_doc ? maybe_doc->version() : SnapshotVersion::None();
    FIREBASE_ASSERT_MESSAGE(key == key_,
                            "Can only patch a document with the same key");
    return std::make_shared<Document>(
        PatchObject(FieldValue::ObjectValueFromMap({})), key, version,
        has_local_mutations);
  }

  FIREBASE_ASSERT_MESSAGE(maybe_doc->type() == MaybeDocument::Type::Document,
                          "Unknown MaybeDocument type %d", maybe_doc->type());
  const Document* doc = static_cast<Document*>(maybe_doc.get());

  FIREBASE_ASSERT_MESSAGE(doc->key() == key_,
                          "Can only patch a document with the same key");
  return std::make_shared<Document>(PatchObject(doc->data()), doc->key(),
                                    doc->version(), has_local_mutations);
}

FieldValue PatchMutation::PatchObject(FieldValue value) const {
  for (auto iter = field_mask_.begin(); iter != field_mask_.end(); ++iter) {
    const FieldPath& field_path = *iter;
    absl::optional<FieldValue> new_value = value_.Get(field_path);
    if (new_value == absl::nullopt) {
      value = value.Delete(field_path);
    } else {
      value = value.Set(field_path, new_value.value());
    }
  }
  return value;
}

TransformMutation::TransformMutation(
    DocumentKey key, std::vector<FieldTransform> field_transforms)
    // NOTE: We set a precondition of exists: true as a safety-check, since
    // we always combine TransformMutations with a SetMutation or
    // PatchMutation which (if successful) should end up with an existing
    // document.
    : Mutation(std::move(key), Precondition::Exists(true)),
      field_transforms_(std::move(field_transforms)) {
}

MaybeDocumentPointer TransformMutation::ApplyTo(
    const MaybeDocumentPointer& maybe_doc,
    const MaybeDocumentPointer& base_doc,
    const Timestamp& local_write_time,
    const absl::optional<MutationResult>& mutation_result) const {
  if (mutation_result) {
    FIREBASE_ASSERT_MESSAGE(mutation_result->transform_results(),
                            "Transform results missing for TransformMutation.");
  }

  if (precondition_.IsValidFor(maybe_doc)) {
    return maybe_doc;
  }

  // We only support transforms with precondition exists, so we can only
  // apply it to an existing document.
  FIREBASE_ASSERT_MESSAGE(maybe_doc->type() == MaybeDocument::Type::Document,
                          "Unknown MaybeDocument type %d", maybe_doc->type());
  const Document* doc = static_cast<Document*>(maybe_doc.get());

  FIREBASE_ASSERT_MESSAGE(doc->key() == key_,
                          "Can only transform a document with the same key");
  bool has_local_mutations = mutation_result.has_value();
  FieldValue new_data;
  if (mutation_result) {
    new_data = TransformObject(doc->data(),
                               mutation_result->transform_results().value());
  } else {
    new_data = TransformObject(
        doc->data(), LocalTransformResults(base_doc, local_write_time));
  }
  return std::make_shared<Document>(std::move(new_data), doc->key(),
                                    doc->version(), has_local_mutations);
}

std::vector<FieldValue> TransformMutation::LocalTransformResults(
    const MaybeDocumentPointer& base_doc,
    const Timestamp& local_write_time) const {
  std::vector<FieldValue> transform_results;
  for (const FieldTransform& field_transform : field_transforms_) {
    if (field_transform.transformation().type() ==
        TransformOperation::Type::ServerTimestamp) {
      if (base_doc && base_doc->type() == MaybeDocument::Type::Document) {
        const absl::optional<FieldValue> value =
            static_cast<Document*>(base_doc.get())
                ->field(field_transform.path());
        if (value && value->type() == FieldValue::Type::Timestamp) {
          transform_results.push_back(FieldValue::ServerTimestampValue(
              local_write_time, value->timestamp_value()));
          continue;
        }
      }
      transform_results.push_back(
          FieldValue::ServerTimestampValue(local_write_time));
    } else {
      FIREBASE_ASSERT_MESSAGE(false, "Encountered unknown transform: %d type",
                              field_transform.transformation().type());
    }
  }
  return transform_results;
}

FieldValue TransformMutation::TransformObject(
    FieldValue value, const std::vector<FieldValue>& transform_results) const {
  FIREBASE_ASSERT_MESSAGE(transform_results.size() == field_transforms_.size(),
                          "Transform results length mismatch.");

  for (size_t i = 0; i < field_transforms_.size(); i++) {
    const FieldTransform& field_transform = field_transforms_[i];
    const TransformOperation& transform = field_transform.transformation();
    const FieldPath& field_path = field_transform.path();
    if (transform.type() == TransformOperation::Type::ServerTimestamp) {
      value = value.Set(field_path, transform_results[i]);
    } else {
      FIREBASE_ASSERT_MESSAGE(false, "Encountered unknown transform: %d type",
                              transform.type());
    }
  }
  return value;
}

DeleteMutation::DeleteMutation(DocumentKey key, Precondition precondition)
    : Mutation(std::move(key), std::move(precondition)) {
}

MaybeDocumentPointer DeleteMutation::ApplyTo(
    const MaybeDocumentPointer& maybe_doc,
    const MaybeDocumentPointer& /* base_doc */,
    const Timestamp& /* local_write_time */,
    const absl::optional<MutationResult>& mutation_result) const {
  if (mutation_result) {
    FIREBASE_ASSERT_MESSAGE(!mutation_result->transform_results(),
                            "Transform results received by DeleteMutation.");
  }

  if (precondition_.IsValidFor(maybe_doc)) {
    return maybe_doc;
  }

  if (maybe_doc) {
    FIREBASE_ASSERT_MESSAGE(maybe_doc->key() == key_,
                            "Can only delete a document with the same key");
  }

  return std::make_shared<NoDocument>(key_, SnapshotVersion::None());
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
