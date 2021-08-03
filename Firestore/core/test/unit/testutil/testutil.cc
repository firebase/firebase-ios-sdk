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

#include "Firestore/core/test/unit/testutil/testutil.h"

#include <algorithm>
#include <chrono>  // NOLINT(build/c++11)
#include <set>

#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/core/direction.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/order_by.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/field_mask.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/field_transform.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/precondition.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/model/transform_operation.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/model/verify_mutation.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/string_format.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace testutil {

using model::DeepClone;
using model::Document;
using model::DocumentComparator;
using model::DocumentKey;
using model::DocumentSet;
using model::FieldMask;
using model::FieldPath;
using model::FieldTransform;
using model::MutableDocument;
using model::NullValue;
using model::ObjectValue;
using model::Precondition;
using model::TransformOperation;
using nanopb::ByteString;
using nanopb::Message;
using nanopb::SetRepeatedField;
using nanopb::SharedMessage;
using util::StringFormat;

/**
 * A string sentinel that can be used with PatchMutation() to mark a field for
 * deletion.
 */
constexpr const char* kDeleteSentinel = "<DELETE>";

// We use a canonical NaN bit pattern that's common for both Objective-C and
// Java. Specifically:
//
//   - sign: 0
//   - exponent: 11 bits, all 1
//   - significand: 52 bits, MSB=1, rest=0
//
// This matches the Firestore backend which uses Double.doubleToLongBits from
// the JDK (which is defined to normalize all NaNs to this value). This also
// happens to be a common value for NAN in C++, but C++ does not require this
// specific NaN value to be used, so we normalize.
const uint64_t kCanonicalNanBits = 0x7ff8000000000000ULL;

namespace details {

Message<google_firestore_v1_Value> BlobValue(
    std::initializer_list<uint8_t> octets) {
  nanopb::ByteString contents{octets};
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_bytes_value_tag;
  result->bytes_value = nanopb::MakeBytesArray(octets.begin(), octets.size());
  return result;
}

}  // namespace details

ByteString Bytes(std::initializer_list<uint8_t> octets) {
  return ByteString(octets);
}

Message<google_firestore_v1_Value> Value(std::nullptr_t) {
  return NullValue();
}

Message<google_firestore_v1_Value> Value(double value) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_double_value_tag;
  result->double_value = value;
  return result;
}

Message<google_firestore_v1_Value> Value(Timestamp value) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result->timestamp_value.seconds = value.seconds();
  result->timestamp_value.nanos = value.nanoseconds();
  return result;
}

Message<google_firestore_v1_Value> Value(const char* value) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_string_value_tag;
  result->string_value = nanopb::MakeBytesArray(value);
  return result;
}

Message<google_firestore_v1_Value> Value(const std::string& value) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_string_value_tag;
  result->string_value = nanopb::MakeBytesArray(value);
  return result;
}

Message<google_firestore_v1_Value> Value(const nanopb::ByteString& value) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_bytes_value_tag;
  result->bytes_value = nanopb::MakeBytesArray(value.begin(), value.size());
  return result;
}

Message<google_firestore_v1_Value> Value(const GeoPoint& value) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_geo_point_value_tag;
  result->geo_point_value.latitude = value.latitude();
  result->geo_point_value.longitude = value.longitude();
  return result;
}

Message<google_firestore_v1_Value> Value(
    Message<google_firestore_v1_Value> value) {
  return value;
}

Message<google_firestore_v1_Value> Value(
    Message<google_firestore_v1_MapValue> value) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value = *value.release();
  return result;
}

Message<google_firestore_v1_Value> Value(
    Message<google_firestore_v1_ArrayValue> value) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_array_value_tag;
  result->array_value = *value.release();
  return result;
}

Message<google_firestore_v1_Value> Value(const model::ObjectValue& value) {
  return DeepClone(value.Get());
}

ObjectValue WrapObject(Message<google_firestore_v1_Value> value) {
  return ObjectValue{std::move(value)};
}

model::DocumentKey Key(absl::string_view path) {
  return model::DocumentKey::FromPathString(std::string(path));
}

model::FieldPath Field(absl::string_view field) {
  auto path = model::FieldPath::FromServerFormat(std::string(field));
  return path.ConsumeValueOrDie();
}

model::DatabaseId DbId(std::string project) {
  size_t slash = project.find('/');
  if (slash == std::string::npos) {
    return model::DatabaseId(std::move(project), model::DatabaseId::kDefault);
  } else {
    std::string database_id = project.substr(slash + 1);
    project = project.substr(0, slash);
    return model::DatabaseId(std::move(project), std::move(database_id));
  }
}

Message<google_firestore_v1_Value> Ref(std::string project,
                                       absl::string_view path) {
  model::DatabaseId database_id = DbId(std::move(project));
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_reference_value_tag;
  result->string_value = nanopb::MakeBytesArray(
      StringFormat("projects/%s/databases/%s/documents/%s",
                   database_id.project_id(), database_id.database_id(), path));
  return result;
}

model::ResourcePath Resource(absl::string_view field) {
  return model::ResourcePath::FromString(std::string(field));
}

model::SnapshotVersion Version(int64_t version) {
  namespace chr = std::chrono;
  auto timepoint =
      chr::time_point<chr::system_clock>(chr::microseconds(version));
  return model::SnapshotVersion{Timestamp::FromTimePoint(timepoint)};
}

model::MutableDocument Doc(absl::string_view key,
                           int64_t version,
                           Message<google_firestore_v1_Value> data) {
  return MutableDocument::FoundDocument(Key(key), Version(version),
                                        ObjectValue{std::move(data)});
}

model::MutableDocument Doc(absl::string_view key, int64_t version) {
  return MutableDocument::FoundDocument(Key(key), Version(version),
                                        ObjectValue{});
}

model::MutableDocument DeletedDoc(absl::string_view key, int64_t version) {
  return MutableDocument::NoDocument(Key(key), Version(version));
}

model::MutableDocument DeletedDoc(DocumentKey key, int64_t version) {
  return MutableDocument::NoDocument(std::move(key), Version(version));
}

model::MutableDocument UnknownDoc(absl::string_view key, int64_t version) {
  return MutableDocument::UnknownDocument(Key(key), Version(version));
}

model::MutableDocument InvalidDoc(absl::string_view key) {
  return MutableDocument::InvalidDocument(Key(key));
}

DocumentComparator DocComparator(absl::string_view field_path) {
  return Query("docs").AddingOrderBy(OrderBy(field_path)).Comparator();
}

DocumentSet DocSet(DocumentComparator comp, std::vector<Document> docs) {
  DocumentSet set{std::move(comp)};
  for (const Document& doc : docs) {
    set = set.insert(doc);
  }
  return set;
}

core::Filter::Operator OperatorFromString(absl::string_view s) {
  if (s == "<") {
    return core::Filter::Operator::LessThan;
  } else if (s == "<=") {
    return core::Filter::Operator::LessThanOrEqual;
  } else if (s == "==") {
    return core::Filter::Operator::Equal;
  } else if (s == "!=") {
    return core::Filter::Operator::NotEqual;
  } else if (s == ">") {
    return core::Filter::Operator::GreaterThan;
  } else if (s == ">=") {
    return core::Filter::Operator::GreaterThanOrEqual;
    // Both are accepted for compatibility with spec tests and existing
    // canonical ids.
  } else if (s == "array_contains" || s == "array-contains") {
    return core::Filter::Operator::ArrayContains;
  } else if (s == "in") {
    return core::Filter::Operator::In;
  } else if (s == "array-contains-any") {
    return core::Filter::Operator::ArrayContainsAny;
  } else if (s == "not-in") {
    return core::Filter::Operator::NotIn;
  } else {
    HARD_FAIL("Unknown operator: %s", s);
  }
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         Message<google_firestore_v1_Value> value) {
  return core::FieldFilter::Create(Field(key), OperatorFromString(op),
                                   std::move(value));
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         Message<google_firestore_v1_ArrayValue> value) {
  return core::FieldFilter::Create(Field(key), OperatorFromString(op),
                                   Value(std::move(value)));
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         std::nullptr_t) {
  return Filter(key, op, NullValue());
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         const char* value) {
  return Filter(key, op, Value(value));
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         int value) {
  return Filter(key, op, Value(value));
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         double value) {
  return Filter(key, op, Value(value));
}

core::Direction Direction(absl::string_view direction) {
  if (direction == "asc") {
    return core::Direction::Ascending;
  } else if (direction == "desc") {
    return core::Direction::Descending;
  } else {
    HARD_FAIL("Unknown direction: %s (use \"asc\" or \"desc\")", direction);
  }
}

core::OrderBy OrderBy(absl::string_view key, absl::string_view direction) {
  return core::OrderBy(Field(key), Direction(direction));
}

core::OrderBy OrderBy(model::FieldPath field_path, core::Direction direction) {
  return core::OrderBy(std::move(field_path), direction);
}

core::Query Query(absl::string_view path) {
  return core::Query(Resource(path));
}

core::Query CollectionGroupQuery(absl::string_view collection_id) {
  return core::Query(model::ResourcePath::Empty(),
                     std::make_shared<const std::string>(collection_id));
}

// TODO(chenbrian): Rewrite SetMutation to allow parsing of field
// transforms directly in the `values` parameter once the UserDataReader/
// UserDataWriter changes are ported from Web and Android.
model::SetMutation SetMutation(
    absl::string_view path,
    Message<google_firestore_v1_Value> values,
    std::vector<std::pair<std::string, TransformOperation>> transforms) {
  std::vector<FieldTransform> field_transforms;
  for (auto&& pair : transforms) {
    auto field_path = Field(std::move(pair.first));
    TransformOperation&& op_ptr = std::move(pair.second);
    FieldTransform transform(std::move(field_path), std::move(op_ptr));
    field_transforms.push_back(std::move(transform));
  }

  return model::SetMutation(Key(path), model::ObjectValue{std::move(values)},
                            model::Precondition::None(),
                            std::move(field_transforms));
}

// TODO(chenbrian): Rewrite PatchMutation to allow parsing of field
// transforms directly in the `values` parameter once the UserDataReader/
// UserDataWriter changes are ported from Web and Android.
model::PatchMutation PatchMutation(
    absl::string_view path,
    Message<google_firestore_v1_Value> values,
    // TODO(rsgowman): Investigate changing update_mask to a set.
    std::vector<std::pair<std::string, TransformOperation>> transforms) {
  return PatchMutationHelper(path, std::move(values), std::move(transforms),
                             Precondition::Exists(true), absl::nullopt);
}

// TODO(chenbrian): Rewrite MergeMutation to allow parsing of field
// transforms directly in the `values` parameter once the UserDataReader/
// UserDataWriter changes are ported from Web and Android.
model::PatchMutation MergeMutation(
    absl::string_view path,
    Message<google_firestore_v1_Value> values,
    const std::vector<model::FieldPath>& update_mask,
    std::vector<std::pair<std::string, TransformOperation>> transforms) {
  return PatchMutationHelper(path, std::move(values), std::move(transforms),
                             Precondition::None(), update_mask);
}

model::PatchMutation PatchMutationHelper(
    absl::string_view path,
    Message<google_firestore_v1_Value> values,
    std::vector<std::pair<std::string, TransformOperation>> transforms,
    Precondition precondition,
    const absl::optional<std::vector<model::FieldPath>>& update_mask) {
  ObjectValue object_value{};
  std::set<FieldPath> field_mask_paths;

  std::vector<FieldTransform> field_transforms;
  for (auto&& pair : transforms) {
    auto field_path = Field(std::move(pair.first));
    TransformOperation&& op_ptr = std::move(pair.second);
    FieldTransform transform(std::move(field_path), std::move(op_ptr));
    field_transforms.push_back(std::move(transform));
  }

  for (pb_size_t i = 0; i < values->map_value.fields_count; ++i) {
    FieldPath field_path =
        Field(nanopb::MakeStringView(values->map_value.fields[i].key));
    field_mask_paths.insert(field_path);
    const google_firestore_v1_Value& value = values->map_value.fields[i].value;
    if (value.which_value_type != google_firestore_v1_Value_string_value_tag ||
        nanopb::MakeStringView(value.string_value) != kDeleteSentinel) {
      object_value.Set(field_path, DeepClone(value));
    } else if (nanopb::MakeStringView(value.string_value) == kDeleteSentinel) {
      object_value.Delete(field_path);
    }
  }

  FieldMask mask(
      update_mask.has_value()
          ? std::set<FieldPath>(update_mask->begin(), update_mask->end())
          : field_mask_paths);

  return model::PatchMutation(Key(path), std::move(object_value),
                              std::move(mask), precondition,
                              std::move(field_transforms));
}

std::pair<std::string, TransformOperation> Increment(
    std::string field, Message<google_firestore_v1_Value> operand) {
  model::NumericIncrementTransform transform(std::move(operand));

  return std::pair<std::string, TransformOperation>(std::move(field),
                                                    std::move(transform));
}

std::pair<std::string, TransformOperation> ArrayUnion(
    std::string field,
    const std::vector<Message<google_firestore_v1_Value>>& operands) {
  Message<google_firestore_v1_ArrayValue> array_value;
  SetRepeatedField(&array_value->values, &array_value->values_count,
                   operands.begin(), operands.end(),
                   [](const Message<google_firestore_v1_Value>& value) {
                     return *DeepClone(*value).release();
                   });
  model::ArrayTransform transform(TransformOperation::Type::ArrayUnion,
                                  std::move(array_value));
  return std::pair<std::string, TransformOperation>(std::move(field),
                                                    std::move(transform));
}

model::DeleteMutation DeleteMutation(absl::string_view path) {
  return model::DeleteMutation(Key(path), Precondition::None());
}

model::VerifyMutation VerifyMutation(absl::string_view path, int64_t version) {
  return model::VerifyMutation(Key(path),
                               Precondition::UpdateTime(Version(version)));
}

model::MutationResult MutationResult(int64_t version) {
  return model::MutationResult(Version(version), Array());
}

nanopb::ByteString ResumeToken(int64_t snapshot_version) {
  if (snapshot_version == 0) {
    // TODO(rsgowman): The other platforms return null here, though I'm not sure
    // if they ever rely on that. I suspect it'd be sufficient to return '{}'.
    // But for now, we'll just abort() until we hit a test case that actually
    // makes use of this.
    HARD_FAIL("Unsupported snapshot version %s", snapshot_version);
  }

  std::string snapshot_string =
      std::string("snapshot-") + std::to_string(snapshot_version);
  return nanopb::ByteString(snapshot_string);
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
