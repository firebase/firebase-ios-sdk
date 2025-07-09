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

#include <algorithm>
#include <memory>
#include <stdexcept>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/api/pipeline.h"
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace api {

using model::DeepClone;

CollectionSource::CollectionSource(std::string path)
    : path_(model::ResourcePath::FromStringView(path)) {
}

google_firestore_v1_Pipeline_Stage CollectionSource::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;

  result.name = nanopb::MakeBytesArray(name());

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);
  result.args[0].which_value_type =
      google_firestore_v1_Value_reference_value_tag;
  result.args[0].reference_value = nanopb::MakeBytesArray(
      util::StringFormat("/%s", this->path_.CanonicalString()));

  result.options_count = 0;
  result.options = nullptr;

  return result;
}

google_firestore_v1_Pipeline_Stage DatabaseSource::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;

  result.name = nanopb::MakeBytesArray(name());
  result.args_count = 0;
  result.args = nullptr;
  result.options_count = 0;
  result.options = nullptr;

  return result;
}

google_firestore_v1_Pipeline_Stage CollectionGroupSource::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;

  result.name = nanopb::MakeBytesArray(name());

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

  result.name = nanopb::MakeBytesArray(name());

  result.args_count = static_cast<pb_size_t>(documents_.size());
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(result.args_count);

  size_t i = 0;
  for (const auto& document : documents_) {
    result.args[i].which_value_type =
        google_firestore_v1_Value_reference_value_tag;
    result.args[i].reference_value = nanopb::MakeBytesArray(document);
    i++;
  }

  result.options_count = 0;
  result.options = nullptr;

  return result;
}

google_firestore_v1_Pipeline_Stage AddFields::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);

  result.args[0].which_value_type = google_firestore_v1_Value_map_value_tag;
  nanopb::SetRepeatedField(
      &result.args[0].map_value.fields, &result.args[0].map_value.fields_count,
      fields_, [](const std::pair<std::string, std::shared_ptr<Expr>>& entry) {
        return _google_firestore_v1_MapValue_FieldsEntry{
            nanopb::MakeBytesArray(entry.first), entry.second->to_proto()};
      });

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Pipeline_Stage AggregateStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = 2;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(2);

  // Encode accumulators map.
  result.args[0].which_value_type = google_firestore_v1_Value_map_value_tag;
  nanopb::SetRepeatedField(
      &result.args[0].map_value.fields, &result.args[0].map_value.fields_count,
      this->accumulators_,
      [](const std::pair<std::string, std::shared_ptr<AggregateFunction>>&
             entry) {
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

  result.name = nanopb::MakeBytesArray(name());

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
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = 3;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(3);
  result.args[0] = property_->to_proto();
  result.args[1] = *DeepClone(*vector_).release();
  result.args[2] = distance_measure_.proto();

  nanopb::SetRepeatedField(
      &result.options, &result.options_count, options_,
      [](const std::pair<std::string, google_firestore_v1_Value>& entry) {
        return _google_firestore_v1_Pipeline_Stage_OptionsEntry{
            nanopb::MakeBytesArray(entry.first), entry.second};
      });

  return result;
}

google_firestore_v1_Pipeline_Stage LimitStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray(name());

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
  result.name = nanopb::MakeBytesArray(name());

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
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);

  result.args[0].which_value_type = google_firestore_v1_Value_map_value_tag;
  nanopb::SetRepeatedField(
      &result.args[0].map_value.fields, &result.args[0].map_value.fields_count,
      fields_, [](const std::pair<std::string, std::shared_ptr<Expr>>& entry) {
        return _google_firestore_v1_MapValue_FieldsEntry{
            nanopb::MakeBytesArray(entry.first), entry.second->to_proto()};
      });

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Pipeline_Stage SortStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray(name());

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
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);

  result.args[0].which_value_type = google_firestore_v1_Value_map_value_tag;
  nanopb::SetRepeatedField(
      &result.args[0].map_value.fields, &result.args[0].map_value.fields_count,
      groups_, [](const std::pair<std::string, std::shared_ptr<Expr>>& entry) {
        return _google_firestore_v1_MapValue_FieldsEntry{
            nanopb::MakeBytesArray(entry.first), entry.second->to_proto()};
      });

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Pipeline_Stage RemoveFieldsStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = static_cast<pb_size_t>(fields_.size());
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(result.args_count);

  for (size_t i = 0; i < fields_.size(); ++i) {
    result.args[i] = fields_[i].to_proto();
  }

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

google_firestore_v1_Value ReplaceWith::ReplaceMode::to_proto() const {
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_string_value_tag;
  switch (mode_) {
    case FULL_REPLACE:
      result.string_value = nanopb::MakeBytesArray("full_replace");
      break;
    case MERGE_PREFER_NEST:
      result.string_value = nanopb::MakeBytesArray("merge_prefer_nest");
      break;
  }
  return result;
}

google_firestore_v1_Pipeline_Stage ReplaceWith::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = 2;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(2);
  result.args[0] = expr_->to_proto();

  result.args[1] = mode_.to_proto();

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

ReplaceWith::ReplaceWith(std::shared_ptr<Expr> expr, ReplaceMode mode)
    : expr_(std::move(expr)), mode_(mode) {
}

google_firestore_v1_Value Sample::SampleMode::to_proto() const {
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_string_value_tag;
  switch (mode_) {
    case DOCUMENTS:
      result.string_value = nanopb::MakeBytesArray("documents");
      break;
    case PERCENT:
      result.string_value = nanopb::MakeBytesArray("percent");
      break;
  }
  return result;
}

Sample::Sample(SampleMode mode, int64_t count, double percentage)
    : mode_(mode), count_(count), percentage_(percentage) {
}

google_firestore_v1_Pipeline_Stage Sample::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = 2;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(2);

  switch (mode_.mode()) {
    case SampleMode::Mode::DOCUMENTS:
      result.args[0].which_value_type =
          google_firestore_v1_Value_integer_value_tag;
      result.args[0].integer_value = count_;
      break;
    case SampleMode::Mode::PERCENT:
      result.args[0].which_value_type =
          google_firestore_v1_Value_double_value_tag;
      result.args[0].double_value = percentage_;
      break;
  }

  result.args[1] = mode_.to_proto();

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

Union::Union(std::shared_ptr<Pipeline> other) : other_(std::move(other)) {
}

google_firestore_v1_Pipeline_Stage Union::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = 1;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(1);
  result.args[0] = other_->to_proto();

  result.options_count = 0;
  result.options = nullptr;
  return result;
}

Unnest::Unnest(std::shared_ptr<Expr> field,
               std::shared_ptr<Expr> alias,
               absl::optional<std::shared_ptr<Expr>> index_field)
    : field_(std::move(field)),
      alias_(alias),
      index_field_(std::move(index_field)) {
}

google_firestore_v1_Pipeline_Stage Unnest::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = 2;
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(2);
  result.args[0] = field_->to_proto();
  result.args[1] = alias_->to_proto();

  if (index_field_.has_value()) {
    result.options_count = 1;
    result.options =
        nanopb::MakeArray<google_firestore_v1_Pipeline_Stage_OptionsEntry>(1);
    result.options[0].key = nanopb::MakeBytesArray("index_field");
    result.options[0].value = index_field_.value()->to_proto();
  } else {
    result.options_count = 0;
    result.options = nullptr;
  }

  return result;
}

RawStage::RawStage(
    std::string name,
    std::vector<google_firestore_v1_Value> params,
    std::unordered_map<std::string, std::shared_ptr<Expr>> options)
    : name_(std::move(name)),
      params_(std::move(params)),
      options_(std::move(options)) {
}

google_firestore_v1_Pipeline_Stage RawStage::to_proto() const {
  google_firestore_v1_Pipeline_Stage result;
  result.name = nanopb::MakeBytesArray(name());

  result.args_count = static_cast<pb_size_t>(params_.size());
  result.args = nanopb::MakeArray<google_firestore_v1_Value>(result.args_count);

  for (size_t i = 0; i < result.args_count; i++) {
    result.args[i] = params_[i];
  }

  nanopb::SetRepeatedField(
      &result.options, &result.options_count, options_,
      [](const std::pair<std::string, std::shared_ptr<Expr>>& entry) {
        return _google_firestore_v1_Pipeline_Stage_OptionsEntry{
            nanopb::MakeBytesArray(entry.first), entry.second->to_proto()};
      });

  return result;
}

model::PipelineInputOutputVector CollectionSource::Evaluate(
    const EvaluateContext& /*context*/,
    const model::PipelineInputOutputVector& inputs) const {
  model::PipelineInputOutputVector results;
  std::copy_if(inputs.begin(), inputs.end(), std::back_inserter(results),
               [this](const model::MutableDocument& doc) {
                 return doc.is_found_document() &&
                        doc.key().path().PopLast().CanonicalString() ==
                            path_.CanonicalString();
               });
  return results;
}

model::PipelineInputOutputVector CollectionGroupSource::Evaluate(
    const EvaluateContext& /*context*/,
    const model::PipelineInputOutputVector& inputs) const {
  model::PipelineInputOutputVector results;
  std::copy_if(inputs.begin(), inputs.end(), std::back_inserter(results),
               [this](const model::MutableDocument& doc) {
                 return doc.is_found_document() &&
                        doc.key().GetCollectionGroup() == collection_id_;
               });
  return results;
}

model::PipelineInputOutputVector DatabaseSource::Evaluate(
    const EvaluateContext& /*context*/,
    const model::PipelineInputOutputVector& inputs) const {
  model::PipelineInputOutputVector results;
  std::copy_if(inputs.begin(), inputs.end(), std::back_inserter(results),
               [](const model::MutableDocument& doc) {
                 return doc.is_found_document();
               });
  return results;
}

model::PipelineInputOutputVector DocumentsSource::Evaluate(
    const EvaluateContext& /*context*/,
    const model::PipelineInputOutputVector& inputs) const {
  model::PipelineInputOutputVector results;
  for (const model::PipelineInputOutput& input : inputs) {
    if (input.is_found_document() &&
        documents_.count(input.key().path().CanonicalString()) > 0) {
      results.push_back(input);
    }
  }
  return results;
}

model::PipelineInputOutputVector Where::Evaluate(
    const EvaluateContext& context,
    const model::PipelineInputOutputVector& inputs) const {
  model::PipelineInputOutputVector results;
  const auto evaluable_expr = expr_->ToEvaluable();
  const auto true_value = model::TrueValue();

  for (const auto& doc : inputs) {
    auto result = evaluable_expr->Evaluate(context, doc);
    if (!result.IsErrorOrUnset() &&
        model::Equals(*result.value(), true_value)) {
      results.push_back(doc);
    }
  }

  return results;
}

model::PipelineInputOutputVector LimitStage::Evaluate(
    const EvaluateContext& /*context*/,
    const model::PipelineInputOutputVector& inputs) const {
  model::PipelineInputOutputVector::const_iterator begin;
  model::PipelineInputOutputVector::const_iterator end;
  size_t count;

  if (limit_ < 0) {
    // if limit_ is negative, we treat it as limit to last, returns the last
    // limit_ documents.
    count = static_cast<size_t>(-limit_);
    if (count > inputs.size()) {
      count = inputs.size();
    }
    begin = inputs.end() - count;
    end = inputs.end();
  } else {
    count = static_cast<size_t>(limit_);
    if (count > inputs.size()) {
      count = inputs.size();
    }
    begin = inputs.begin();
    end = inputs.begin() + count;
  }

  return model::PipelineInputOutputVector(begin, end);
}

model::PipelineInputOutputVector SortStage::Evaluate(
    const EvaluateContext& context,
    const model::PipelineInputOutputVector& inputs) const {
  model::PipelineInputOutputVector input_copy = inputs;
  std::sort(
      input_copy.begin(), input_copy.end(),
      [this, &context](const model::PipelineInputOutput& left,
                       const model::PipelineInputOutput& right) -> bool {
        for (const auto& ordering : this->orders_) {
          const auto left_result =
              ordering.expr()->ToEvaluable()->Evaluate(context, left);
          const auto right_result =
              ordering.expr()->ToEvaluable()->Evaluate(context, right);

          auto left_val = left_result.IsErrorOrUnset() ? model::MinValue()
                                                       : *left_result.value();
          auto right_val = right_result.IsErrorOrUnset()
                               ? model::MinValue()
                               : *right_result.value();
          const auto compare_result = model::Compare(left_val, right_val);
          if (compare_result != util::ComparisonResult::Same) {
            return ordering.direction() == Ordering::ASCENDING
                       ? compare_result == util::ComparisonResult::Ascending
                       : compare_result == util::ComparisonResult::Descending;
          }
        }

        return false;
      });

  return input_copy;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
