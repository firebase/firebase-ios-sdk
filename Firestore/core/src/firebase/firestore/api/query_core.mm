/*
 * Copyright 2019 Google
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

#include "Firestore/core/src/firebase/firestore/api/query_core.h"

#include <future>  // NOLINT(build/c++11)
#include <memory>
#include <utility>

#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTFieldValue.h"

#include "Firestore/core/src/firebase/firestore/api/firestore.h"

namespace util = firebase::firestore::util;
using firebase::firestore::api::Firestore;
using firebase::firestore::api::ListenerRegistration;
using firebase::firestore::api::SnapshotMetadata;
using firebase::firestore::api::Source;
using firebase::firestore::api::ThrowInvalidArgument;
using firebase::firestore::core::AsyncEventListener;
using firebase::firestore::core::Direction;
using firebase::firestore::core::EventListener;
using firebase::firestore::core::Filter;
using firebase::firestore::core::ListenOptions;
using firebase::firestore::core::QueryListener;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace api {

bool operator==(const Query& lhs, const Query& rhs) {
  return lhs.firestore() == rhs.firestore() &&
         objc::Equals(lhs.query(), rhs.query());
}

size_t Query::Hash() const {
  return util::Hash(firestore_.get(), query());
}

FSTQuery* Query::query() const {
  return query_;
}

void Query::GetDocuments(Source source, QuerySnapshot::Listener&& callback) {
  if (source == Source::Cache) {
    [firestore_->client() getDocumentsFromLocalCache:*this
                                            callback:std::move(callback)];
    return;
  }

  ListenOptions options(
      /*include_query_metadata_changes=*/true,
      /*include_document_metadata_changes=*/true,
      /*wait_for_sync_when_online=*/true);

  class ListenOnce : public EventListener<QuerySnapshot> {
   public:
    ListenOnce(Source source, QuerySnapshot::Listener&& listener)
        : source_(source), listener_(std::move(listener)) {
    }

    void OnEvent(StatusOr<QuerySnapshot> maybe_snapshot) override {
      if (!maybe_snapshot.ok()) {
        listener_->OnEvent(std::move(maybe_snapshot));
        return;
      }

      QuerySnapshot snapshot = std::move(maybe_snapshot).ValueOrDie();

      // Remove query first before passing event to user to avoid user actions
      // affecting the now stale query.
      ListenerRegistration registration =
          registration_promise_.get_future().get();
      registration.Remove();

      if (snapshot.metadata().from_cache() && source_ == Source::Server) {
        listener_->OnEvent(Status{
            FirestoreErrorCode::Unavailable,
            "Failed to get documents from server. (However, these documents "
            "may exist in the local cache. Run again without setting source to "
            "FirestoreSourceServer to retrieve the cached documents.)"});
      } else {
        listener_->OnEvent(std::move(snapshot));
      }
    };

    void Resolve(ListenerRegistration&& registration) {
      registration_promise_.set_value(std::move(registration));
    }

   private:
    Source source_;
    QuerySnapshot::Listener listener_;

    std::promise<ListenerRegistration> registration_promise_;
  };

  auto listener = absl::make_unique<ListenOnce>(source, std::move(callback));
  auto listener_unowned = listener.get();

  ListenerRegistration registration =
      AddSnapshotListener(std::move(options), std::move(listener));

  listener_unowned->Resolve(std::move(registration));
}

ListenerRegistration Query::AddSnapshotListener(
    ListenOptions options, QuerySnapshot::Listener&& user_listener) {
  // Convert from ViewSnapshots to QuerySnapshots.
  class Converter : public EventListener<ViewSnapshot> {
   public:
    Converter(Query* parent, QuerySnapshot::Listener&& user_listener)
        : firestore_(parent->firestore()),
          query_(parent->query()),
          user_listener_(std::move(user_listener)) {
    }

    void OnEvent(StatusOr<ViewSnapshot> maybe_snapshot) override {
      if (!maybe_snapshot.status().ok()) {
        user_listener_->OnEvent(maybe_snapshot.status());
        return;
      }

      ViewSnapshot snapshot = std::move(maybe_snapshot).ValueOrDie();
      SnapshotMetadata metadata(snapshot.has_pending_writes(),
                                snapshot.from_cache());

      QuerySnapshot result(firestore_, query_, std::move(snapshot),
                           std::move(metadata));

      user_listener_->OnEvent(result);
    }

   private:
    std::shared_ptr<Firestore> firestore_;
    FSTQuery* query_;
    QuerySnapshot::Listener user_listener_;
  };
  auto view_listener =
      absl::make_unique<Converter>(this, std::move(user_listener));

  // Call the view_listener on the user Executor.
  auto async_listener = AsyncEventListener<ViewSnapshot>::Create(
      firestore_->client().userExecutor, std::move(view_listener));

  std::shared_ptr<QueryListener> query_listener =
      [firestore_->client() listenToQuery:this->query()
                                  options:options
                                 listener:async_listener];

  return ListenerRegistration(firestore_->client(), std::move(async_listener),
                              std::move(query_listener));
}

Query Query::Filter(FieldPath field_path,
                    Filter::Operator op,
                    FSTFieldValue* field_value,
                    const std::function<std::string()>& type_describer) const {
  if (field_path.IsKeyFieldPath()) {
    if (op == Filter::Operator::ArrayContains) {
      ThrowInvalidArgument(
          "Invalid query. You can't perform arrayContains queries on document "
          "ID since document IDs are not arrays.");
    }
    if (field_value.type == FieldValue::Type::String) {
      const std::string& document_key =
          static_cast<FSTDelegateValue*>(field_value)
              .internalValue.string_value();
      if (document_key.empty()) {
        ThrowInvalidArgument(
            "Invalid query. When querying by document ID you must provide a "
            "valid document ID, but it was an empty string.");
      }
      if (![query() isCollectionGroupQuery] &&
          document_key.find('/') != std::string::npos) {
        ThrowInvalidArgument(
            "Invalid query. When querying a collection by document ID you must "
            "provide a plain document ID, but '%s' contains a '/' character.",
            document_key);
      }
      ResourcePath path =
          query().path.Append(ResourcePath::FromString(document_key));
      if (!DocumentKey::IsDocumentKey(path)) {
        ThrowInvalidArgument(
            "Invalid query. When querying a collection group by document ID, "
            "the value provided must result in a valid document path, but '%s' "
            "is not because it has an odd number of segments.",
            path.CanonicalString());
      }
      field_value = [FSTReferenceValue
          referenceValue:[FSTDocumentKey keyWithDocumentKey:DocumentKey{path}]
              databaseID:firestore_->database_id()];
    } else if (field_value.type != FieldValue::Type::Reference) {
      ThrowInvalidArgument(
          "Invalid query. When querying by document ID you must provide a "
          "valid string or DocumentReference, but it was of type: %s",
          type_describer());
    }
  }

  FSTFilter* filter = [FSTFilter filterWithField:field_path
                                  filterOperator:op
                                           value:field_value];

  if ([filter isKindOfClass:[FSTRelationFilter class]]) {
    ValidateNewRelationFilter(static_cast<FSTRelationFilter*>(filter));
  }

  return Wrap([query_ queryByAddingFilter:filter]);
}

Query Query::OrderBy(FieldPath fieldPath, bool descending) const {
  return OrderBy(fieldPath, Direction::FromDescending(descending));
}

Query Query::OrderBy(FieldPath fieldPath, Direction direction) const {
  ValidateNewOrderByPath(fieldPath);
  if (query().startAt) {
    ThrowInvalidArgument("Invalid query. You must not specify a starting point "
                         "before specifying the order by.");
  }
  if (query().endAt) {
    ThrowInvalidArgument("Invalid query. You must not specify an ending point "
                         "before specifying the order by.");
  }
  bool ascending = direction == Direction::Ascending;
  FSTSortOrder* sortOrder = [FSTSortOrder sortOrderWithFieldPath:fieldPath
                                                       ascending:ascending];
  return Wrap([query() queryByAddingSortOrder:sortOrder]);
}

Query Query::Limit(int64_t limit) const {
  if (limit <= 0) {
    ThrowInvalidArgument(
        "Invalid Query. Query limit (%s) is invalid. Limit must be positive.",
        limit);
  }
  return Wrap([query() queryBySettingLimit:limit]);
}

Query Query::StartAt(FSTBound* bound) const {
  return Wrap([query() queryByAddingStartAt:bound]);
}

Query Query::EndAt(FSTBound* bound) const {
  return Wrap([query() queryByAddingEndAt:bound]);
}

void Query::ValidateNewRelationFilter(FSTRelationFilter* filter) const {
  if ([filter isInequality]) {
    const FieldPath* existingField = [query_ inequalityFilterField];
    if (existingField && *existingField != filter.field) {
      ThrowInvalidArgument(
          "Invalid Query. All where filters with an inequality (lessThan, "
          "lessThanOrEqual, greaterThan, or greaterThanOrEqual) must be on the "
          "same field. But you have inequality filters on '%s' and '%s'",
          existingField->CanonicalString(), filter.field.CanonicalString());
    }

    const FieldPath* firstOrderByField = [query_ firstSortOrderField];
    if (firstOrderByField) {
      ValidateOrderByField(*firstOrderByField, filter.field);
    }
  } else if (filter.filterOperator == Filter::Operator::ArrayContains) {
    if ([query_ hasArrayContainsFilter]) {
      ThrowInvalidArgument(
          "Invalid Query. Queries only support a single arrayContains filter.");
    }
  }
}

void Query::ValidateNewOrderByPath(const FieldPath& fieldPath) const {
  if (![query() firstSortOrderField]) {
    // This is the first order by. It must match any inequality.
    const FieldPath* inequalityField = [query() inequalityFilterField];
    if (inequalityField) {
      ValidateOrderByField(fieldPath, *inequalityField);
    }
  }
}

void Query::ValidateOrderByField(const FieldPath& orderByField,
                                 const FieldPath& inequalityField) const {
  if (orderByField != inequalityField) {
    ThrowInvalidArgument(
        "Invalid query. You have a where filter with an inequality "
        "(lessThan, lessThanOrEqual, greaterThan, or greaterThanOrEqual) on "
        "field '%s' and so you must also use '%s' as your first queryOrderedBy "
        "field, but your first queryOrderedBy is currently on field '%s' "
        "instead.",
        inequalityField.CanonicalString(), inequalityField.CanonicalString(),
        orderByField.CanonicalString());
  }
}

Query Query::Wrap(FSTQuery* query) const {
  return Query(query, firestore_);
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END
