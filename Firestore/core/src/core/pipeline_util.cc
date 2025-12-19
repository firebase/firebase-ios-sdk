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

#include "Firestore/core/src/core/pipeline_util.h"

#include <algorithm>
#include <map>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/ordering.h"
#include "Firestore/core/src/api/realtime_pipeline.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/core/bound.h"
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/src/core/order_by.h"
#include "Firestore/core/src/core/pipeline_run.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/src/util/exception.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/str_format.h"
#include "absl/strings/str_join.h"
#include "absl/types/optional.h"
#include "absl/types/variant.h"

namespace firebase {
namespace firestore {
namespace core {

namespace {

auto NewKeyOrdering() {
  return api::Ordering(
      std::make_shared<api::Field>(model::FieldPath::KeyFieldPath()),
      api::Ordering::Direction::ASCENDING);
}

// Helper to get orderings from the last effective SortStage
const std::vector<api::Ordering>& GetLastEffectiveSortOrderings(
    const api::RealtimePipeline& pipeline) {
  const auto& stages = pipeline.rewritten_stages();
  for (auto it = stages.rbegin(); it != stages.rend(); ++it) {
    if (auto sort_stage = std::dynamic_pointer_cast<api::SortStage>(*it)) {
      return sort_stage->orders();
    }
    // TODO(pipeline): Consider stages that might invalidate ordering later,
    // like fineNearest
  }
  HARD_FAIL(
      "RealtimePipeline must contain at least one Sort stage "
      "(ensured by RewriteStages).");
  // Return a reference to avoid copying, but satisfy compiler in HARD_FAIL
  // case. This line should be unreachable.
  static const std::vector<api::Ordering> empty_orderings;
  return empty_orderings;
}

}  // namespace

std::vector<std::shared_ptr<api::EvaluableStage>> RewriteStages(
    const std::vector<std::shared_ptr<api::EvaluableStage>>& stages) {
  bool has_order = false;
  std::vector<std::shared_ptr<api::EvaluableStage>> new_stages;
  for (const auto& stage : stages) {
    // For stages that provide ordering semantics
    if (stage->name() == "sort") {
      auto sort_stage = std::static_pointer_cast<api::SortStage>(stage);
      has_order = true;

      // Ensure we have a stable ordering
      bool includes_key_ordering = false;
      for (const auto& order : sort_stage->orders()) {
        auto field = dynamic_cast<const api::Field*>(order.expr());
        if (field != nullptr && field->field_path().IsKeyFieldPath()) {
          includes_key_ordering = true;
          break;
        }
      }

      if (includes_key_ordering) {
        new_stages.push_back(stage);
      } else {
        auto copy = sort_stage->orders();
        copy.push_back(NewKeyOrdering());
        new_stages.push_back(std::make_shared<api::SortStage>(std::move(copy)));
      }
    } else if (stage->name() ==
               "limit") {  // For stages whose semantics depend on ordering
      if (!has_order) {
        new_stages.push_back(std::make_shared<api::SortStage>(
            std::vector<api::Ordering>{NewKeyOrdering()}));
        has_order = true;
      }
      new_stages.push_back(stage);
    } else {
      // TODO(pipeline): Handle add_fields and select and such
      new_stages.push_back(stage);
    }
  }

  if (!has_order) {
    new_stages.push_back(std::make_shared<api::SortStage>(
        std::vector<api::Ordering>{NewKeyOrdering()}));
  }

  return new_stages;
}

// Anonymous namespace for canonicalization helpers
namespace {

std::string CanonifyConstant(const api::Constant* constant) {
  return model::CanonicalId(constant->value());
}

// Accepts raw pointer because that's what api::Ordering::expr() returns
std::string CanonifyExpr(const api::Expr* expr) {
  HARD_ASSERT(expr != nullptr, "Canonify a null expr");

  if (auto field_ref = dynamic_cast<const api::Field*>(expr)) {
    return absl::StrFormat("fld(%s)",
                           field_ref->field_path().CanonicalString());
  } else if (auto constant = dynamic_cast<const api::Constant*>(expr)) {
    return absl::StrFormat("cst(%s)", CanonifyConstant(constant));
  } else if (auto func = dynamic_cast<const api::FunctionExpr*>(expr)) {
    std::vector<std::string> param_strings;
    for (const auto& param_ptr : func->params()) {
      param_strings.push_back(
          CanonifyExpr(param_ptr.get()));  // Pass raw pointer from shared_ptr
    }
    return absl::StrFormat("fn(%s[%s])", func->name(),
                           absl::StrJoin(param_strings, ","));
  }

  HARD_FAIL("Canonify a unrecognized expr");
}

std::string CanonifySortOrderings(const std::vector<api::Ordering>& orders) {
  std::vector<std::string> entries;
  for (const auto& order : orders) {
    // Use api::Ordering::Direction::ASCENDING
    entries.push_back(absl::StrCat(
        CanonifyExpr(order.expr()),  // order.expr() returns const api::Expr*
        order.direction() == api::Ordering::Direction::ASCENDING ? "asc"
                                                                 : "desc"));
  }
  return absl::StrJoin(entries, ",");
}

std::string CanonifyStage(const std::shared_ptr<api::EvaluableStage>& stage) {
  HARD_ASSERT(stage != nullptr, "Canonify a null stage");

  // Placeholder implementation - needs details for each stage type
  // (CollectionSource, Where, Sort, Limit, Select, AddFields, Aggregate, etc.)
  // Use dynamic_pointer_cast to check types.
  if (auto collection_source =
          std::dynamic_pointer_cast<api::CollectionSource>(stage)) {
    return absl::StrFormat("%s(%s)", collection_source->name(),
                           collection_source->path());
  } else if (auto collection_group =
                 std::dynamic_pointer_cast<api::CollectionGroupSource>(stage)) {
    return absl::StrFormat("%s(%s)", collection_group->name(),
                           collection_group->collection_id());
  } else if (auto documents_source =
                 std::dynamic_pointer_cast<api::DocumentsSource>(stage)) {
    std::vector<std::string> sorted_documents = documents_source->documents();
    return absl::StrFormat("%s(%s)", documents_source->name(),
                           absl::StrJoin(sorted_documents, ","));
  } else if (auto where_stage = std::dynamic_pointer_cast<api::Where>(stage)) {
    return absl::StrFormat("%s(%s)", where_stage->name(),
                           CanonifyExpr(where_stage->expr()));
  } else if (auto sort_stage =
                 std::dynamic_pointer_cast<api::SortStage>(stage)) {
    return absl::StrFormat(
        "%s(%s)", sort_stage->name(),
        CanonifySortOrderings(sort_stage->orders()));  // Use orders() getter
  } else if (auto limit_stage =
                 std::dynamic_pointer_cast<api::LimitStage>(stage)) {
    return absl::StrFormat("%s(%d)", limit_stage->name(), limit_stage->limit());
  }

  HARD_FAIL(absl::StrFormat("Trying to canonify an unrecognized stage type %s",
                            stage->name())
                .c_str());
}

// Canonicalizes a RealtimePipeline by canonicalizing its stages.
std::string CanonifyPipeline(const api::RealtimePipeline& pipeline) {
  std::vector<std::string> stage_strings;
  for (const auto& stage : pipeline.rewritten_stages()) {
    stage_strings.push_back(CanonifyStage(stage));
  }
  return absl::StrJoin(stage_strings, "|");
}

}  // namespace

// QueryOrPipeline member function implementations

bool QueryOrPipeline::operator==(const QueryOrPipeline& other) const {
  if (data_.index() != other.data_.index()) {
    return false;  // Different types stored
  }

  if (IsPipeline()) {
    // Compare pipelines by their canonical representation
    return CanonifyPipeline(pipeline()) == CanonifyPipeline(other.pipeline());
  } else {
    // Compare queries using Query::operator==
    return query() == other.query();
  }
}

size_t QueryOrPipeline::Hash() const {
  if (IsPipeline()) {
    // Compare pipelines by their canonical representation
    return util::Hash(CanonifyPipeline(pipeline()));
  } else {
    return util::Hash(query());
  }
}

std::string QueryOrPipeline::CanonicalId() const {
  if (IsPipeline()) {
    return CanonifyPipeline(pipeline());
  } else {
    return query().CanonicalId();
  }
}

std::string QueryOrPipeline::ToString() const {
  if (IsPipeline()) {
    // Use the canonical representation as the string representation for
    // pipelines
    return CanonicalId();
  } else {
    return query().ToString();
  }
}

TargetOrPipeline QueryOrPipeline::ToTargetOrPipeline() const {
  if (IsPipeline()) {
    return TargetOrPipeline(pipeline());
  }

  return TargetOrPipeline(query().ToTarget());
}

bool QueryOrPipeline::MatchesAllDocuments() const {
  if (IsPipeline()) {
    for (const auto& stage : pipeline().rewritten_stages()) {
      // Check for LimitStage
      if (stage->name() == "limit") {
        return false;
      }

      // Check for Where stage
      if (auto where_stage = std::dynamic_pointer_cast<api::Where>(stage)) {
        // Check if it's the special 'exists(__name__)' case
        if (auto func_expr =
                dynamic_cast<const api::FunctionExpr*>(where_stage->expr())) {
          if (func_expr->name() == "exists" &&
              func_expr->params().size() == 1) {
            if (auto field_expr = dynamic_cast<const api::Field*>(
                    func_expr->params()[0].get())) {
              if (field_expr->field_path().IsKeyFieldPath()) {
                continue;  // This specific 'exists(__name__)' filter doesn't
                           // count
              }
            }
          }
        }
        return false;  // Any other Where stage means it filters documents
      }
      // TODO(pipeline) : Add checks for other filtering stages like Aggregate,
      // Distinct, FindNearest once they are implemented in C++.
    }
    return true;  // No filtering stages found (besides allowed ones)
  }

  return query().MatchesAllDocuments();
}

bool QueryOrPipeline::has_limit() const {
  if (this->IsPipeline()) {
    for (const auto& stage : this->pipeline().rewritten_stages()) {
      // Check for LimitStage
      if (stage->name() == "limit") {
        return true;
      }
      // TODO(pipeline): need to check for other stages that could have a limit,
      // like findNearest
    }

    return false;
  }

  return query().has_limit();
}

bool QueryOrPipeline::Matches(const model::Document& doc) const {
  if (IsPipeline()) {
    const auto result = RunPipeline(
        const_cast<api::RealtimePipeline&>(this->pipeline()), {doc.get()});
    return result.size() > 0;
  }

  return query().Matches(doc);
}

model::DocumentComparator QueryOrPipeline::Comparator() const {
  if (IsPipeline()) {
    // Capture pipeline by reference. Orderings captured by value inside lambda.
    const api::RealtimePipeline& p = pipeline();
    const auto& orderings = GetLastEffectiveSortOrderings(p);
    return model::DocumentComparator(
        [p, orderings](const model::Document& d1,
                       const model::Document& d2) -> util::ComparisonResult {
          auto context =
              const_cast<api::RealtimePipeline&>(p).evaluate_context();

          for (const auto& ordering : orderings) {
            const api::Expr* expr = ordering.expr();
            HARD_ASSERT(expr != nullptr, "Ordering expression cannot be null");

            // Evaluate expression for both documents using expr->Evaluate
            // (assuming this method exists) Pass const references to documents.
            EvaluateResult left_value =
                expr->ToEvaluable()->Evaluate(context, d1.get());
            EvaluateResult right_value =
                expr->ToEvaluable()->Evaluate(context, d2.get());

            // Compare results, using MinValue for error
            util::ComparisonResult comparison = model::Compare(
                left_value.IsErrorOrUnset() ? model::MinValue()
                                            : *left_value.value(),
                right_value.IsErrorOrUnset() ? model::MinValue()
                                             : *right_value.value());

            if (comparison != util::ComparisonResult::Same) {
              return ordering.direction() == api::Ordering::Direction::ASCENDING
                         ? comparison
                     // reverse comparison
                     : comparison == util::ComparisonResult::Ascending
                         ? util::ComparisonResult::Descending
                         : util::ComparisonResult::Ascending;
            }
          }
          return util::ComparisonResult::Same;
        });
  }

  return query().Comparator();
}

// TargetOrPipeline member function implementations

bool TargetOrPipeline::operator==(const TargetOrPipeline& other) const {
  if (data_.index() != other.data_.index()) {
    return false;  // Different types stored
  }

  if (IsPipeline()) {
    // Compare pipelines by their canonical representation
    return CanonifyPipeline(pipeline()) == CanonifyPipeline(other.pipeline());
  } else {
    // Compare targets using Target::operator==
    return target() == other.target();
  }
}

size_t TargetOrPipeline::Hash() const {
  if (IsPipeline()) {
    // Compare pipelines by their canonical representation
    return util::Hash(CanonifyPipeline(pipeline()));
  } else {
    return util::Hash(target());
  }
}

std::string TargetOrPipeline::CanonicalId() const {
  if (IsPipeline()) {
    return CanonifyPipeline(pipeline());
  } else {
    return target().CanonicalId();
  }
}

std::string TargetOrPipeline::ToString() const {
  if (IsPipeline()) {
    // Use the canonical representation as the string representation for
    // pipelines
    return CanonicalId();
  } else {
    // Assuming Target has a ToString() method
    return target().ToString();
  }
}

PipelineFlavor GetPipelineFlavor(const api::RealtimePipeline&) {
  // For now, it is only possible to construct RealtimePipeline that is kExact.
  // PORTING NOTE: the typescript implementation support other flavors already,
  // despite not being used. We can port that later.
  return PipelineFlavor::kExact;
}

PipelineSourceType GetPipelineSourceType(
    const api::RealtimePipeline& pipeline) {
  HARD_ASSERT(!pipeline.stages().empty(),
              "Pipeline must have at least one stage to determine its source.");
  const auto& first_stage = pipeline.stages().front();

  if (std::dynamic_pointer_cast<const api::CollectionSource>(first_stage)) {
    return PipelineSourceType::kCollection;
  } else if (std::dynamic_pointer_cast<const api::CollectionGroupSource>(
                 first_stage)) {
    return PipelineSourceType::kCollectionGroup;
  } else if (std::dynamic_pointer_cast<const api::DatabaseSource>(
                 first_stage)) {
    return PipelineSourceType::kDatabase;
  } else if (std::dynamic_pointer_cast<const api::DocumentsSource>(
                 first_stage)) {
    return PipelineSourceType::kDocuments;
  }

  return PipelineSourceType::kUnknown;
}

absl::optional<std::string> GetPipelineCollectionGroup(
    const api::RealtimePipeline& pipeline) {
  if (GetPipelineSourceType(pipeline) == PipelineSourceType::kCollectionGroup) {
    HARD_ASSERT(!pipeline.stages().empty(),
                "Pipeline source is CollectionGroup but stages are empty.");
    const auto& first_stage = pipeline.stages().front();
    if (auto collection_group_source =
            std::dynamic_pointer_cast<const api::CollectionGroupSource>(
                first_stage)) {
      return std::string{collection_group_source->collection_id()};
    }
  }
  return absl::nullopt;
}

absl::optional<std::string> GetPipelineCollection(
    const api::RealtimePipeline& pipeline) {
  if (GetPipelineSourceType(pipeline) == PipelineSourceType::kCollection) {
    HARD_ASSERT(!pipeline.stages().empty(),
                "Pipeline source is Collection but stages are empty.");
    const auto& first_stage = pipeline.stages().front();
    if (auto collection_source =
            std::dynamic_pointer_cast<const api::CollectionSource>(
                first_stage)) {
      return {collection_source->path()};
    }
  }
  return absl::nullopt;
}

absl::optional<std::vector<std::string>> GetPipelineDocuments(
    const api::RealtimePipeline& pipeline) {
  if (GetPipelineSourceType(pipeline) == PipelineSourceType::kDocuments) {
    HARD_ASSERT(!pipeline.stages().empty(),
                "Pipeline source is Documents but stages are empty.");
    const auto& first_stage = pipeline.stages().front();
    if (auto documents_stage =
            std::dynamic_pointer_cast<const api::DocumentsSource>(
                first_stage)) {
      return documents_stage->documents();
    }
  }
  return absl::nullopt;
}

api::RealtimePipeline AsCollectionPipelineAtPath(
    const api::RealtimePipeline& pipeline, const model::ResourcePath& path) {
  std::vector<std::shared_ptr<api::EvaluableStage>> new_stages;
  new_stages.reserve(pipeline.stages().size());

  for (const auto& stage_ptr : pipeline.stages()) {
    // Attempt to cast to CollectionGroupSource.
    // We use dynamic_pointer_cast because stage_ptr is a shared_ptr.
    if (auto collection_group_source =
            std::dynamic_pointer_cast<const api::CollectionGroupSource>(
                stage_ptr)) {
      // If it's a CollectionGroupSource, replace it with a CollectionSource
      // using the provided path.
      new_stages.push_back(
          std::make_shared<api::CollectionSource>(path.CanonicalString()));
    } else {
      // Otherwise, keep the original stage.
      new_stages.push_back(stage_ptr);
    }
  }

  // Construct a new RealtimePipeline with the (potentially) modified stages
  // and the original user_data_reader.
  return api::RealtimePipeline(std::move(new_stages),
                               std::make_unique<remote::Serializer>(
                                   pipeline.evaluate_context().serializer()));
}

absl::optional<int64_t> GetLastEffectiveLimit(
    const api::RealtimePipeline& pipeline) {
  const auto& stages = pipeline.rewritten_stages();
  for (auto it = stages.rbegin(); it != stages.rend(); ++it) {
    const auto& stage_ptr = *it;
    // Check if the stage is a LimitStage
    if (auto limit_stage =
            std::dynamic_pointer_cast<const api::LimitStage>(stage_ptr)) {
      return limit_stage->limit();
    }
    // TODO(pipeline): Consider other stages that might imply a limit,
    // e.g., FindNearestStage, once they are implemented.
  }
  return absl::nullopt;
}

// --- ToPipelineStages and helpers ---

namespace {  // Anonymous namespace for ToPipelineStages helpers

std::shared_ptr<api::Expr> ToPipelineBooleanExpr(const Filter& filter) {
  if (filter.type() != FieldFilter::Type::kCompositeFilter) {
    const auto& field_filter = static_cast<const FieldFilter&>(filter);
    auto api_field = std::make_shared<api::Field>(field_filter.field());
    auto exists_expr = std::make_shared<api::FunctionExpr>(
        "exists", std::vector<std::shared_ptr<api::Expr>>{api_field});

    const google_firestore_v1_Value& value = field_filter.value();
    FieldFilter::Operator op = field_filter.op();

    auto api_constant =
        std::make_shared<api::Constant>(model::DeepClone(value));
    std::shared_ptr<api::Expr> comparison_expr;
    std::string func_name;

    switch (op) {
      case FieldFilter::Operator::LessThan:
        func_name = "less_than";
        break;
      case FieldFilter::Operator::LessThanOrEqual:
        func_name = "less_than_or_equal";
        break;
      case FieldFilter::Operator::GreaterThan:
        func_name = "greater_than";
        break;
      case FieldFilter::Operator::GreaterThanOrEqual:
        func_name = "greater_than_or_equal";
        break;
      case FieldFilter::Operator::Equal:
        func_name = "equal";
        break;
      case FieldFilter::Operator::NotEqual:
        func_name = "not_equal";
        break;
      case FieldFilter::Operator::ArrayContains:
        func_name = "array_contains";
        break;
      case FieldFilter::Operator::In:
      case FieldFilter::Operator::NotIn:
      case FieldFilter::Operator::ArrayContainsAny: {
        HARD_ASSERT(
            model::IsArray(value),
            "Value for IN, NOT_IN, ARRAY_CONTAINS_ANY must be an array.");

        if (op == FieldFilter::Operator::In)
          func_name = "equal_any";
        else if (op == FieldFilter::Operator::NotIn)
          func_name = "not_equal_any";
        else if (op == FieldFilter::Operator::ArrayContainsAny)
          func_name = "array_contains_any";
        break;
      }
      default:
        HARD_FAIL("Unexpected FieldFilter operator.");
    }
    comparison_expr = std::make_shared<api::FunctionExpr>(
        func_name,
        std::vector<std::shared_ptr<api::Expr>>{api_field, api_constant});
    return std::make_shared<api::FunctionExpr>(
        "and",
        std::vector<std::shared_ptr<api::Expr>>{exists_expr, comparison_expr});

  } else if (filter.type() == FieldFilter::Type::kCompositeFilter) {
    const auto& composite_filter = static_cast<const CompositeFilter&>(filter);
    std::vector<std::shared_ptr<api::Expr>> sub_exprs;
    for (const auto& sub_filter : composite_filter.filters()) {
      sub_exprs.push_back(ToPipelineBooleanExpr(sub_filter));
    }
    HARD_ASSERT(!sub_exprs.empty(), "Composite filter must have sub-filters.");
    if (sub_exprs.size() == 1) return sub_exprs[0];

    std::string func_name =
        (composite_filter.op() == CompositeFilter::Operator::And) ? "and"
                                                                  : "or";
    return std::make_shared<api::FunctionExpr>(func_name, sub_exprs);
  }
  HARD_FAIL("Unknown filter type.");
  return nullptr;
}

std::shared_ptr<api::Expr> WhereConditionsFromCursor(
    const Bound& bound,
    const std::vector<api::Ordering>& orderings,
    bool is_before) {
  std::vector<std::shared_ptr<api::Expr>> cursors;
  const auto& pos = bound.position();
  for (size_t i = 0; i < pos->values_count; ++i) {
    cursors.push_back(
        std::make_shared<api::Constant>(model::DeepClone(pos->values[i])));
  }

  std::string func_name = is_before ? "less_than" : "greater_than";
  std::string func_inclusive_name =
      is_before ? "less_than_or_equal" : "greater_than_or_equal";

  std::vector<std::shared_ptr<api::Expr>> or_conditions;
  for (size_t sub_end = 1; sub_end <= cursors.size(); ++sub_end) {
    std::vector<std::shared_ptr<api::Expr>> conditions;
    for (size_t index = 0; index < sub_end; ++index) {
      if (index < sub_end - 1) {
        conditions.push_back(std::make_shared<api::FunctionExpr>(
            "equal", std::vector<std::shared_ptr<api::Expr>>{
                         orderings[index].expr_shared(), cursors[index]}));
      } else if (bound.inclusive() && sub_end == orderings.size() - 1) {
        conditions.push_back(std::make_shared<api::FunctionExpr>(
            func_inclusive_name,
            std::vector<std::shared_ptr<api::Expr>>{
                orderings[index].expr_shared(), cursors[index]}));
      } else {
        conditions.push_back(std::make_shared<api::FunctionExpr>(
            func_name, std::vector<std::shared_ptr<api::Expr>>{
                           orderings[index].expr_shared(), cursors[index]}));
      }
    }

    if (conditions.size() == 1) {
      or_conditions.push_back(conditions[0]);
    } else {
      or_conditions.push_back(
          std::make_shared<api::FunctionExpr>("and", std::move(conditions)));
    }
  }

  if (or_conditions.empty()) return nullptr;
  if (or_conditions.size() == 1) return or_conditions[0];
  return std::make_shared<api::FunctionExpr>("or", or_conditions);
}

}  // anonymous namespace

std::vector<std::shared_ptr<api::EvaluableStage>> ToPipelineStages(
    const Query& query) {
  std::vector<std::shared_ptr<api::EvaluableStage>> stages;

  // 1. Source Stage
  if (query.IsCollectionGroupQuery()) {
    stages.push_back(std::make_shared<api::CollectionGroupSource>(
        std::string(*query.collection_group())));
  } else if (query.IsDocumentQuery()) {
    std::vector<std::string> doc_paths;
    doc_paths.push_back(query.path().CanonicalString());
    stages.push_back(
        std::make_shared<api::DocumentsSource>(std::move(doc_paths)));
  } else {
    stages.push_back(std::make_shared<api::CollectionSource>(
        query.path().CanonicalString()));
  }

  // 2. Filter Stages
  for (const auto& filter : query.filters()) {
    stages.push_back(
        std::make_shared<api::Where>(ToPipelineBooleanExpr(filter)));
  }

  // 3. OrderBy Existence Checks
  const auto& query_order_bys = query.normalized_order_bys();
  if (!query_order_bys.empty()) {
    std::vector<std::shared_ptr<api::Expr>> exists_exprs;
    exists_exprs.reserve(query_order_bys.size());
    for (const auto& core_order_by : query_order_bys) {
      exists_exprs.push_back(std::make_shared<api::FunctionExpr>(
          "exists", std::vector<std::shared_ptr<api::Expr>>{
                        std::make_shared<api::Field>(core_order_by.field())}));
    }
    if (exists_exprs.size() == 1) {
      stages.push_back(std::make_shared<api::Where>(exists_exprs[0]));
    } else {
      stages.push_back(std::make_shared<api::Where>(
          std::make_shared<api::FunctionExpr>("and", exists_exprs)));
    }
  }

  // 4. Orderings, Cursors, Limit
  std::vector<api::Ordering> api_orderings;
  api_orderings.reserve(query_order_bys.size());
  for (const auto& core_order_by : query_order_bys) {
    api_orderings.emplace_back(
        std::make_shared<api::Field>(core_order_by.field()),
        core_order_by.direction() == Direction::Ascending
            ? api::Ordering::Direction::ASCENDING
            : api::Ordering::Direction::DESCENDING);
  }

  if (query.start_at()) {
    stages.push_back(std::make_shared<api::Where>(WhereConditionsFromCursor(
        *query.start_at(), api_orderings, /*is_before*/ false)));
  }

  if (query.end_at()) {
    stages.push_back(std::make_shared<api::Where>(WhereConditionsFromCursor(
        *query.end_at(), api_orderings, /*is_before*/ true)));
  }

  if (query.has_limit()) {
    if (query.limit_type() == LimitType::First) {
      stages.push_back(std::make_shared<api::SortStage>(api_orderings));
      stages.push_back(std::make_shared<api::LimitStage>(query.limit()));
    } else {
      if (query.explicit_order_bys().empty()) {
        util::ThrowInvalidArgument(
            "limit(toLast:) queries require specifying at least one OrderBy() "
            "clause.");
      }

      std::vector<api::Ordering> reversed_orderings;
      for (const auto& ordering : api_orderings) {
        reversed_orderings.push_back(ordering.WithReversedDirection());
      }
      stages.push_back(std::make_shared<api::SortStage>(reversed_orderings));
      stages.push_back(std::make_shared<api::LimitStage>(query.limit()));
      stages.push_back(std::make_shared<api::SortStage>(api_orderings));
    }
  } else {
    stages.push_back(std::make_shared<api::SortStage>(api_orderings));
  }

  return stages;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
