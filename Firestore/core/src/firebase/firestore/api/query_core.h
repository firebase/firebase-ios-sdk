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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_QUERY_CORE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_QUERY_CORE_H_

#include <memory>
#include <string>
#include <utility>

#include "Firestore/core/src/firebase/firestore/api/listener_registration.h"
#include "Firestore/core/src/firebase/firestore/api/query_snapshot.h"
#include "Firestore/core/src/firebase/firestore/api/source.h"
#include "Firestore/core/src/firebase/firestore/core/direction.h"
#include "Firestore/core/src/firebase/firestore/core/event_listener.h"
#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/listen_options.h"
#include "Firestore/core/src/firebase/firestore/core/relation_filter.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/objc/objc_class.h"

OBJC_CLASS(FSTBound);
OBJC_CLASS(FSTQuery);

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace api {

class Firestore;

/**
 * A `Query` refers to a Firestore Query which you can read or listen to. You
 * can also construct refined `Query` objects by adding filters and ordering.
 */
class Query {
 public:
  Query() = default;

  Query(FSTQuery* query, std::shared_ptr<Firestore> firestore);

  size_t Hash() const;

  const std::shared_ptr<Firestore>& firestore() const {
    return firestore_;
  }

  FSTQuery* query() const;

  /**
   * Reads the documents matching this query.
   *
   * @param source indicates whether the results should be fetched from the
   *     cache only (`Source::Cache`), the server only (`Source::Server`), or to
   *     attempt the server and fall back to the cache (`Source::Default`).
   * @param callback a callback to execute once the documents have been
   *     successfully read.
   */
  void GetDocuments(Source source, QuerySnapshot::Listener&& callback);

  /**
   * Attaches a listener for QuerySnapshot events.
   *
   * @param options Whether metadata-only changes (i.e. only
   *     `DocumentSnapshot::metadata()` changed) should trigger snapshot events.
   * @param listener The listener to attach.
   *
   * @return A ListenerRegistration that can be used to remove this listener.
   */
  ListenerRegistration AddSnapshotListener(core::ListenOptions options,
                                           QuerySnapshot::Listener&& listener);

  /**
   * Creates and returns a new `Query` with the additional filter that documents
   * must contain the specified field and the value must be equal to the
   * specified value.
   *
   * @param field_path The name of the field to compare.
   * @param op The operator to apply.
   * @param field_value The value against which to compare the field.
   * @param type_describer A function that will produce a description of the
   *     type of field_value.
   *
   * @return The created `Query`.
   */
  Query Filter(model::FieldPath field_path,
               core::Filter::Operator op,
               model::FieldValue field_value,
               const std::function<std::string()>& type_describer) const;

  /**
   * Creates and returns a new `Query` that's additionally sorted by the
   * specified field.
   *
   * @param field_path The field to sort by.
   * @param descending If true, sorts descending instead of ascending.
   *
   * @return The created `Query`.
   */
  Query OrderBy(model::FieldPath field_path, bool descending) const;

  /**
   * Creates and returns a new `Query` that's additionally sorted by the
   * specified field.
   *
   * @param field_path The field to sort by.
   * @param direction The direction in which to sort.
   *
   * @return The created `Query`.
   */
  Query OrderBy(model::FieldPath field_path, core::Direction direction) const;

  /**
   * Creates and returns a new `Query` that's additionally limited to only
   * return up to the specified number of documents.
   *
   * @param limit The maximum number of items to return.
   *
   * @return The created `Query`.
   */
  Query Limit(int32_t limit) const;

  /**
   * Creates and returns a new `Query` that starts at the given bound.  The
   * starting position is relative to the order of the query.  The bound must
   * contain all of the fields provided in the orderBy of this query.
   *
   * @param bound The bound of the query to start at.
   *
   * @return The created `Query`.
   */
  Query StartAt(FSTBound* bound) const;

  /**
   * Creates and returns a new `Query` that ends at the given bound.  The ending
   * position is relative to the order of the query.  The bound must contain all
   * of the fields provided in the orderBy of this query.
   *
   * @param bound The bound of the query to end at.
   *
   * @return The created `Query`.
   */
  Query EndAt(FSTBound* bound) const;

  /**
   * Creates a new `Query` with the given internal query.
   */
  Query Wrap(FSTQuery* chained_query) {
    return Query(chained_query, firestore_);
  }

 private:
  void ValidateNewRelationFilter(const core::RelationFilter& filter) const;
  void ValidateNewOrderByPath(const model::FieldPath& fieldPath) const;
  void ValidateOrderByField(const model::FieldPath& orderByField,
                            const model::FieldPath& inequalityField) const;

  Query Wrap(FSTQuery* query) const;

  std::shared_ptr<Firestore> firestore_;
  objc::Handle<FSTQuery> query_;
};

bool operator==(const Query& lhs, const Query& rhs);

inline bool operator!=(const Query& lhs, const Query& rhs) {
  return !(lhs == rhs);
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_QUERY_CORE_H_
