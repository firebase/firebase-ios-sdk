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

#include "Firestore/core/src/core/query.h"

#include <algorithm>
#include <ostream>

#include "Firestore/core/src/core/bound.h"
#include "Firestore/core/src/core/operator.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/util/equality.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/hashing.h"
#include "absl/algorithm/container.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace core {

using Operator = FieldFilter::Operator;
using Type = Filter::Type;

using model::Document;
using model::DocumentComparator;
using model::DocumentKey;
using model::FieldPath;
using model::ResourcePath;
using util::ComparisonResult;

Query::Query(ResourcePath path, std::string collection_group)
    : path_(std::move(path)),
      collection_group_(
          std::make_shared<const std::string>(std::move(collection_group))) {
}

// MARK: - Accessors

bool Query::IsDocumentQuery() const {
  return DocumentKey::IsDocumentKey(path_) && !collection_group_ &&
         filters_.empty();
}

bool Query::MatchesAllDocuments() const {
  return filters_.empty() && limit_ == Target::kNoLimit && !start_at_ &&
         !end_at_ &&
         (explicit_order_bys_.empty() ||
          (explicit_order_bys_.size() == 1 &&
           explicit_order_bys_.front().field().IsKeyFieldPath()));
}

const std::set<model::FieldPath> Query::InequalityFilterFields() const {
  std::set<FieldPath> result;
  for (const Filter& filter : filters_) {
    for (const FieldFilter& subFilter : filter.GetFlattenedFilters()) {
      if (subFilter.IsInequality()) {
        result.emplace(subFilter.field());
      }
    }
  }
  return result;
}

absl::optional<Operator> Query::FindOpInsideFilters(
    const std::vector<Operator>& ops) const {
  for (const auto& filter : filters_) {
    for (const auto& field_filter : filter.GetFlattenedFilters()) {
      if (absl::c_linear_search(ops, field_filter.op())) {
        return field_filter.op();
      }
    }
  }
  return absl::nullopt;
}

const std::vector<OrderBy>& Query::normalized_order_bys() const {
  return memoized_normalized_order_bys_->memoize([&]() {
    // Any explicit order by fields should be added as is.
    std::vector<OrderBy> result = explicit_order_bys_;
    std::set<FieldPath> fieldsNormalized;
    for (const OrderBy& order_by : explicit_order_bys_) {
      fieldsNormalized.insert(order_by.field());
    }

    // The order of the implicit ordering always matches the last explicit order
    // by.
    Direction last_direction = explicit_order_bys_.empty()
                                   ? Direction::Ascending
                                   : explicit_order_bys_.back().direction();

    // Any inequality fields not explicitly ordered should be implicitly ordered
    // in a lexicographical order. When there are multiple inequality filters on
    // the same field, the field should be added only once. Note:
    // `std::set<model::FieldPath>` sorts the key field before other fields.
    // However, we want the key field to be sorted last.
    const std::set<model::FieldPath> inequality_fields =
        InequalityFilterFields();

    for (const model::FieldPath& field : inequality_fields) {
      if (fieldsNormalized.find(field) == fieldsNormalized.end() &&
          !field.IsKeyFieldPath()) {
        result.push_back(OrderBy(field, last_direction));
      }
    }

    // Add the document key field to the last if it is not explicitly ordered.
    if (fieldsNormalized.find(FieldPath::KeyFieldPath()) ==
        fieldsNormalized.end()) {
      result.push_back(OrderBy(FieldPath::KeyFieldPath(), last_direction));
    }

    return result;
  });
}

LimitType Query::limit_type() const {
  return limit_type_;
}

int32_t Query::limit() const {
  HARD_ASSERT(limit_type_ != LimitType::None,
              "Called limit() when no limit was set");
  return limit_;
}

// MARK: - Builder methods

Query Query::AddingFilter(Filter filter) const {
  HARD_ASSERT(!IsDocumentQuery(), "No filter is allowed for document query");

  std::vector<Filter> filters_copy(filters_);
  filters_copy.push_back(std::move(filter));

  return {path_,
          collection_group_,
          std::move(filters_copy),
          explicit_order_bys_,
          limit_,
          limit_type_,
          start_at_,
          end_at_};
}

Query Query::AddingOrderBy(OrderBy order_by) const {
  HARD_ASSERT(!IsDocumentQuery(), "No ordering is allowed for document query");

  std::vector<OrderBy> order_bys_copy(explicit_order_bys_);
  order_bys_copy.push_back(std::move(order_by));

  return {path_,  collection_group_, filters_,  std::move(order_bys_copy),
          limit_, limit_type_,       start_at_, end_at_};
}

Query Query::WithLimitToFirst(int32_t limit) const {
  return {path_, collection_group_, filters_,  explicit_order_bys_,
          limit, LimitType::First,  start_at_, end_at_};
}

Query Query::WithLimitToLast(int32_t limit) const {
  return {path_, collection_group_, filters_,  explicit_order_bys_,
          limit, LimitType::Last,   start_at_, end_at_};
}

Query Query::StartingAt(Bound bound) const {
  return {path_,  collection_group_, filters_,         explicit_order_bys_,
          limit_, limit_type_,       std::move(bound), end_at_};
}

Query Query::EndingAt(Bound bound) const {
  return {path_,  collection_group_, filters_,  explicit_order_bys_,
          limit_, limit_type_,       start_at_, std::move(bound)};
}

Query Query::AsCollectionQueryAtPath(ResourcePath path) const {
  return {std::move(path), /*collection_group=*/nullptr,
          filters_,        explicit_order_bys_,
          limit_,          limit_type_,
          start_at_,       end_at_};
}

// MARK: - Matching

bool Query::Matches(const Document& doc) const {
  return doc->is_found_document() && MatchesPathAndCollectionGroup(doc) &&
         MatchesOrderBy(doc) && MatchesFilters(doc) && MatchesBounds(doc);
}

bool Query::MatchesPathAndCollectionGroup(const Document& doc) const {
  const ResourcePath& doc_path = doc->key().path();
  if (collection_group_) {
    // NOTE: path_ is currently always empty since we don't expose Collection
    // Group queries rooted at a document path yet.
    return doc->key().HasCollectionGroup(*collection_group_) &&
           path_.IsPrefixOf(doc_path);
  } else if (DocumentKey::IsDocumentKey(path_)) {
    // Exact match for document queries.
    return path_ == doc_path;
  } else {
    // Shallow ancestor queries by default.
    return path_.IsImmediateParentOf(doc_path);
  }
}

bool Query::MatchesFilters(const Document& doc) const {
  return std::all_of(
      filters_.cbegin(), filters_.cend(),
      [&doc](const Filter& filter) { return filter.Matches(doc); });
}

bool Query::MatchesOrderBy(const Document& doc) const {
  // We must use `order_bys()` to get the list of all orderBys
  // (both implicit and explicit). Note that for OR queries, orderBy applies to
  // all disjunction terms and implicit orderBys must be taken into account.
  // For example, the query "a > 1 || b == 1" has an implicit "orderBy a" due
  // to the inequality, and is evaluated as "a > 1 orderBy a || b == 1 orderBy
  // a". A document with content of {b:1} matches the filters, but does not
  // match the orderBy because it's missing the field 'a'.
  for (const OrderBy& order_by : normalized_order_bys()) {
    const FieldPath& field_path = order_by.field();
    // order by key always matches
    if (field_path != FieldPath::KeyFieldPath() &&
        doc->field(field_path) == absl::nullopt) {
      return false;
    }
  }
  return true;
}

bool Query::MatchesBounds(const Document& doc) const {
  if (start_at_ &&
      !start_at_->SortsBeforeDocument(normalized_order_bys(), doc)) {
    return false;
  }
  if (end_at_ && !end_at_->SortsAfterDocument(normalized_order_bys(), doc)) {
    return false;
  }
  return true;
}

model::DocumentComparator Query::Comparator() const {
  std::vector<OrderBy> ordering = normalized_order_bys();

  bool has_key_ordering = false;
  for (const OrderBy& order_by : ordering) {
    if (order_by.field() == FieldPath::KeyFieldPath()) {
      has_key_ordering = true;
      break;
    }
  }

  if (!has_key_ordering) {
    HARD_FAIL("QueryComparator needs to have a key ordering: %s", ToString());
  }

  return DocumentComparator(
      [ordering](const Document& doc1, const Document& doc2) {
        for (const OrderBy& order_by : ordering) {
          ComparisonResult comp = order_by.Compare(doc1, doc2);
          if (!util::Same(comp)) return comp;
        }
        return ComparisonResult::Same;
      });
}

std::string Query::CanonicalId() const {
  if (limit_type_ != LimitType::None) {
    return absl::StrCat(ToTarget().CanonicalId(),
                        "|lt:", (limit_type_ == LimitType::Last) ? "l" : "f");
  }
  return ToTarget().CanonicalId();
}

size_t Query::Hash() const {
  return util::Hash(CanonicalId());
}

std::string Query::ToString() const {
  return absl::StrCat("Query(canonical_id=", CanonicalId(), ")");
}

const Target& Query::ToTarget() const& {
  return memoized_target_->memoize(
      [&]() { return ToTarget(normalized_order_bys()); });
}

const Target& Query::ToAggregateTarget() const& {
  return memoized_aggregate_target_->memoize(
      [&]() { return ToTarget(explicit_order_bys_); });
}

Target Query::ToTarget(const std::vector<OrderBy>& order_bys) const {
  if (limit_type_ == LimitType::Last) {
    // Flip the orderBy directions since we want the last results
    std::vector<OrderBy> new_order_bys;
    for (const auto& order_by : order_bys) {
      Direction dir = order_by.direction() == Direction::Descending
                          ? Direction::Ascending
                          : Direction::Descending;
      new_order_bys.emplace_back(order_by.field(), dir);
    }

    // We need to swap the cursors to match the now-flipped query ordering.
    auto new_start_at = end_at_
                            ? absl::optional<Bound>{Bound::FromValue(
                                  end_at_->position(), end_at_->inclusive())}
                            : absl::nullopt;
    auto new_end_at = start_at_
                          ? absl::optional<Bound>{Bound::FromValue(
                                start_at_->position(), start_at_->inclusive())}
                          : absl::nullopt;

    return Target(path(), collection_group(), filters(), new_order_bys, limit_,
                  new_start_at, new_end_at);
  } else {
    return Target(path(), collection_group(), filters(), order_bys, limit_,
                  start_at(), end_at());
  }
}

std::ostream& operator<<(std::ostream& os, const Query& query) {
  return os << query.ToString();
}

bool operator==(const Query& lhs, const Query& rhs) {
  return (lhs.limit_type_ == rhs.limit_type_) &&
         (lhs.ToTarget() == rhs.ToTarget());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
