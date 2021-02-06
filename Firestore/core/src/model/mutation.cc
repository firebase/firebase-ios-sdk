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

#include "Firestore/core/src/model/mutation.h"

#include <cstdlib>
#include <ostream>
#include <sstream>
#include <utility>

#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/field_value.h"
#include "Firestore/core/src/model/no_document.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/to_string.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace model {

std::string MutationResult::ToString() const {
  return absl::StrCat(
      "MutationResult(version=", version_.ToString(),
      ", transform_results=", util::ToString(transform_results_), ")");
}

std::ostream& operator<<(std::ostream& os, const MutationResult& result) {
  return os << result.ToString();
}

bool operator==(const MutationResult& lhs, const MutationResult& rhs) {
  return lhs.version() == rhs.version() &&
         lhs.transform_results() == rhs.transform_results();
}

MaybeDocument Mutation::ApplyToRemoteDocument(
    const absl::optional<MaybeDocument>& maybe_doc,
    const MutationResult& mutation_result) const {
  return rep().ApplyToRemoteDocument(maybe_doc, mutation_result);
}

absl::optional<MaybeDocument> Mutation::ApplyToLocalView(
    const absl::optional<MaybeDocument>& maybe_doc,
    const Timestamp& local_write_time) const {
  return rep().ApplyToLocalView(maybe_doc, local_write_time);
}

absl::optional<ObjectValue> Mutation::Rep::ExtractTransformBaseValue(
    const absl::optional<MaybeDocument>& maybe_doc) const {
  absl::optional<ObjectValue> base_object;
  absl::optional<Document> document;
  if (maybe_doc && maybe_doc->is_document()) {
    document = Document(*maybe_doc);
  }

  for (const FieldTransform& transform : field_transforms_) {
    absl::optional<FieldValue> existing_value;
    if (document) {
      existing_value = document->field(transform.path());
    }

    absl::optional<FieldValue> coerced_value =
        transform.transformation().ComputeBaseValue(existing_value);
    if (coerced_value) {
      if (!base_object) {
        base_object = ObjectValue::Empty();
      }
      base_object = base_object->Set(transform.path(), *coerced_value);
    }
  }

  return base_object;
}

Mutation::Rep::Rep(DocumentKey&& key, Precondition&& precondition)
    : key_(std::move(key)),
      precondition_(std::move(precondition)),
      field_transforms_(std::vector<FieldTransform>()) {
}

Mutation::Rep::Rep(DocumentKey&& key,
                   Precondition&& precondition,
                   std::vector<FieldTransform>&& field_transforms)
    : key_(std::move(key)),
      precondition_(std::move(precondition)),
      field_transforms_(std::move(field_transforms)) {
}

bool Mutation::Rep::Equals(const Mutation::Rep& other) const {
  return type() == other.type() && key_ == other.key_ &&
         precondition_ == other.precondition_ &&
         field_transforms_ == other.field_transforms_;
}

void Mutation::Rep::VerifyKeyMatches(
    const absl::optional<MaybeDocument>& maybe_doc) const {
  if (maybe_doc) {
    HARD_ASSERT(maybe_doc->key() == key(),
                "Can only apply a mutation to a document with the same key");
  }
}

SnapshotVersion Mutation::Rep::GetPostMutationVersion(
    const absl::optional<MaybeDocument>& maybe_doc) {
  if (maybe_doc && maybe_doc->type() == MaybeDocument::Type::Document) {
    return maybe_doc->version();
  } else {
    return SnapshotVersion::None();
  }
}

std::vector<FieldValue> Mutation::Rep::ServerTransformResults(
    const absl::optional<MaybeDocument>& maybe_doc,
    const std::vector<FieldValue>& server_transform_results) const {
  HARD_ASSERT(field_transforms_.size() == server_transform_results.size(),
              "server transform result size (%s) should match field transforms "
              "size (%s)",
              server_transform_results.size(), field_transforms_.size());

  std::vector<FieldValue> transform_results;
  for (size_t i = 0; i < server_transform_results.size(); i++) {
    const FieldTransform& field_transform = field_transforms_[i];
    const TransformOperation& transform = field_transform.transformation();

    absl::optional<model::FieldValue> previous_value;
    if (maybe_doc && maybe_doc->is_document()) {
      previous_value = Document(*maybe_doc).field(field_transform.path());
    }

    transform_results.push_back(transform.ApplyToRemoteDocument(
        previous_value, server_transform_results[i]));
  }
  return transform_results;
}

std::vector<FieldValue> Mutation::Rep::LocalTransformResults(
    const absl::optional<MaybeDocument>& maybe_doc,
    const Timestamp& local_write_time) const {
  std::vector<FieldValue> transform_results;
  for (const FieldTransform& field_transform : field_transforms_) {
    const TransformOperation& transform = field_transform.transformation();

    absl::optional<FieldValue> previous_value;
    if (maybe_doc && maybe_doc->is_document()) {
      previous_value = Document(*maybe_doc).field(field_transform.path());
    }

    transform_results.push_back(
        transform.ApplyToLocalView(previous_value, local_write_time));
  }
  return transform_results;
}

ObjectValue Mutation::Rep::TransformObject(
    ObjectValue object_value,
    const std::vector<FieldValue>& transform_results) const {
  HARD_ASSERT(transform_results.size() == field_transforms_.size(),
              "Transform results size mismatch.");

  for (size_t i = 0; i < field_transforms_.size(); i++) {
    const FieldTransform& field_transform = field_transforms_[i];
    const FieldPath& field_path = field_transform.path();
    object_value = object_value.Set(field_path, transform_results[i]);
  }
  return object_value;
}

bool operator==(const Mutation& lhs, const Mutation& rhs) {
  return lhs.rep_ == nullptr
             ? rhs.rep_ == nullptr
             : (rhs.rep_ != nullptr && lhs.rep_->Equals(*rhs.rep_));
}

size_t Mutation::Rep::Hash() const {
  return util::Hash(type(), key(), precondition(), field_transforms());
}

std::ostream& operator<<(std::ostream& os, const Mutation& mutation) {
  return os << mutation.ToString();
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
