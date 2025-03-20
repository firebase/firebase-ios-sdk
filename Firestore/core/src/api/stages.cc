/*
 * Copyright 2025 Google LLC
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

#include "Firestore/core/src/api/stages.h"

#include <unordered_map>
#include <utility>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace api {

google_firestore_v1_Pipeline_Stage CollectionSource::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;

  result.name = nanopb::MakeBytesArray("collection");

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);
  result.args[0].which_value_type =
      google_firestore_v1_Value_reference_value_tag;
  result.args[0].reference_value = nanopb::MakeBytesArray(this->path_);

  result.options_count = 0;
  result.options = nullptr;

  return result;
}

google_firestore_v1_Pipeline_Stage DatabaseSource::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;

  result.name = nanopb::MakeBytesArray("database");
  result.args_count = 0;
  result.args = nullptr;
  result.options_count = 0;
  result.options = nullptr;

  return result;
}

google_firestore_v1_Pipeline_Stage CollectionGroupSource::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;

  result.name = nanopb::MakeBytesArray("collection_group");

  result.args_count = 2;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(2);
  // First argument is an empty reference value.
  result.args[0].which_value_type =
      google_firestore_v1_Value_reference_value_tag;
  result.args[0].reference_value = nanopb::MakeBytesArray("");

  // Second argument is the collection ID (encoded as a string value).
  result.args[1].which_value_type = google_firestore_v1_Value_string_value_tag;
  result.args[1].string_value = nanopb::MakeBytesArray(collection_id_);

  result.options_count = 0;
  result.options = nullptr;

  return result;
}

google_firestore_v1_Pipeline_Stage DocumentsSource::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;

  result.name = nanopb::MakeBytesArray("documents");

  result.args_count = documents_.size();
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(result.args_count);

  for (size_t i = 0; i < documents_.size(); ++i) {
    result.args[i].which_value_type =
        google_firestore_v1_Value_string_value_tag;
    result.args[i].string_value = nanopb::MakeBytesArray(documents_[i]);
  }

  result.options_count = 0;
  result.options = nullptr;

  return result;
}

google_firestore_v1_Pipeline_Stage AddFields::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray("add_fields");

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);

  result.args[0].which_value_type = google_firestore_v1_Value_map_value_tag;
  nanopb::SetRepeatedField(
      &result.args[0].map_value.fields, &result.args[0].map_value.fields_count,
      fields_, [](const std::shared_ptr<Selectable>& entry) {
        return _google_firestore_v1_MapValue_FieldsEntry{
            nanopb::MakeBytesArray(entry->alias()), entry->to_proto()};
      });

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Pipeline_Stage AggregateStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray("aggregate");

  result.args_count = 2;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(2);

  // Encode accumulators map.
  result.args[0].which_value_type = google_firestore_v1_Value_map_value_tag;
  nanopb::SetRepeatedField(
      &result.args[0].map_value.fields, &result.args[0].map_value.fields_count,
      this->accumulators_,
      [](const std::pair<std::string, std::shared_ptr<AggregateExpr>>& entry) {
        return _google_firestore_v1_MapValue_FieldsEntry{
            nanopb::MakeBytesArray(entry.first), entry.second->to_proto()};
      });

  // Encode groups map.
  result.args[1].which_value_type = google_firestore_v1_Value_map_value_tag;
  nanopb::SetRepeatedField(
      &result.args[1].map_value.fields, &result.args[1].map_value.fields_count,
      this->groups_,
      [](const std::pair<std::string, std::shared_ptr<Expr>>& entry) {
        return _google_firestore_v1_MapValue_FieldsEntry{
            nanopb::MakeBytesArray(entry.first), entry.second->to_proto()};
      });

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Pipeline_Stage Where::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;

  result.name = nanopb::MakeBytesArray("where");

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);
  result.args[0] = this->expr_->to_proto();

  result.options_count = 0;
  result.options = nullptr;

  return result;
}

google_firestore_v1_Value FindNearestStage::DistanceMeasure::proto() const {
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_string_value_tag;
  switch (measure_) {
    case EUCLIDEAN:
      result.string_value = nanopb::MakeBytesArray("euclidean");
      break;
    case COSINE:
      result.string_value = nanopb::MakeBytesArray("cosine");
      break;
    case DOT_PRODUCT:
      result.string_value = nanopb::MakeBytesArray("dot_product");
      break;
  }
  return result;
}

google_firestore_v1_Pipeline_Stage FindNearestStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray("find_nearest");

  result.args_count = 3;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(3);
  result.args[0] = property_->to_proto();
  result.args[1] = *vector_;
  result.args[2] = distance_measure_.proto();

  nanopb::SetRepeatedField(
      &result.options, &result.options_count, options_,
      [](const std::pair<std::string,
                         nanopb::SharedMessage<google_firestore_v1_Value>>&
             entry) {
        return _google_firestore_v1_Pipeline_Stage_OptionsEntry{
            nanopb::MakeBytesArray(entry.first), *entry.second};
      });

  return result;
}

google_firestore_v1_Pipeline_Stage LimitStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray("limit");

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);
  result.args[0].which_value_type = google_firestore_v1_Value_integer_value_tag;
  result.args[0].integer_value = limit_;

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Pipeline_Stage OffsetStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray("offset");

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);
  result.args[0].which_value_type = google_firestore_v1_Value_integer_value_tag;
  result.args[0].integer_value = offset_;

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Pipeline_Stage SelectStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray("select");

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);

  result.args[0].which_value_type = google_firestore_v1_Value_map_value_tag;
  nanopb::SetRepeatedField(
      &result.args[0].map_value.fields, &result.args[0].map_value.fields_count,
      fields_, [](const std::shared_ptr<Selectable>& entry) {
        return _google_firestore_v1_MapValue_FieldsEntry{
            nanopb::MakeBytesArray(entry->alias()), entry->to_proto()};
      });

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Pipeline_Stage SortStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray("sort");

  result.args_count = static_cast<pb_size_t>(orders_.size());
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(result.args_count);

  for (size_t i = 0; i < orders_.size(); ++i) {
    result.args[i] = orders_[i].to_proto();
  }

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Pipeline_Stage DistinctStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray("distinct");

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);

  result.args[0].which_value_type = google_firestore_v1_Value_map_value_tag;
  nanopb::SetRepeatedField(
      &result.args[0].map_value.fields, &result.args[0].map_value.fields_count,
      groups_, [](const std::shared_ptr<Selectable>& entry) {
        return _google_firestore_v1_MapValue_FieldsEntry{
            nanopb::MakeBytesArray(entry->alias()), entry->to_proto()};
      });

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Pipeline_Stage RemoveFieldsStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray("remove_fields");

  result.args_count = static_cast<pb_size_t>(fields_.size());
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(result.args_count);

  for (size_t i = 0; i < fields_.size(); ++i) {
    result.args[i] = fields_[i].to_proto();
  }

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
