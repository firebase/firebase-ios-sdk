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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_QUERY_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_QUERY_H_

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#if defined(FIREBASE_USE_STD_FUNCTION)
#include <functional>
#endif

#include "firebase/firestore/field_path.h"
#include "firebase/firestore/field_value.h"
#include "firebase/firestore/firestore.h"
#include "firebase/firestore/firestore_errors.h"
#include "firebase/firestore/metadata_changes.h"
#include "firebase/firestore/query_snapshot.h"
#include "firebase/firestore/source.h"
#include "firebase/future.h"

namespace firebase {
struct CleanupFn;

namespace firestore {
class QueryInternal;

/**
 * A Query which you can read or listen to. You can also construct refined
 * Query objects by adding filters and ordering. However, you cannot construct
 * a valid Query directly.
 */
class Query {
 public:
  enum class Direction {
    kAscending,
    kDescending,
  };

  /**
   * @brief Default constructor. This creates an invalid Query. Attempting to
   * perform any operations on this query will fail (and cause a crash) unless a
   * valid Query has been assigned to it.
   */
  Query();

  /**
   * @brief Copy constructor. It's totally okay (and efficient) to copy Query
   * instances.
   *
   * @param[in] query Query to copy from.
   */
  Query(const Query& query);

  /**
   * @brief Move constructor. Moving is an efficient operation for Query
   * instances.
   *
   * @param[in] query Query to move data from.
   */
  Query(Query&& query);

  virtual ~Query();

  /**
   * @brief Copy assignment operator. It's totally okay (and efficient) to copy
   * Query instances.
   *
   * @param[in] query Query to copy from.
   *
   * @returns Reference to the destination Query.
   */
  Query& operator=(const Query& query);

  /**
   * @brief Move assignment operator. Moving is an efficient operation for
   * Query instances.
   *
   * @param[in] query Query to move data from.
   *
   * @returns Reference to the destination Query.
   */
  Query& operator=(Query&& query);

  /**
   * @brief Returns the Firestore instance associated with this query.
   *
   * The pointer will remain valid indefinitely.
   *
   * @returns Firebase Firestore instance that this Query refers to.
   */
  virtual const Firestore* firestore() const;

  /**
   * @brief Returns the Firestore instance associated with this query.
   *
   * The pointer will remain valid indefinitely.
   *
   * @returns Firebase Firestore instance that this Query refers to.
   */
  virtual Firestore* firestore();

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field and the value should be equal to
   * the specified value.
   *
   * @param[in] field The name of the field to compare
   * @param[in] value The value for comparison
   *
   * @return The created Query.
   */
  virtual Query WhereEqualTo(const std::string& field, const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field and the value should be equal to
   * the specified value.
   *
   * @param[in] field The path of the field to compare
   * @param[in] value The value for comparison
   *
   * @return The created Query.
   */
  virtual Query WhereEqualTo(const FieldPath& field, const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field and the value should be less
   * than the specified value.
   *
   * @param[in] field The name of the field to compare
   * @param[in] value The value for comparison
   *
   * @return The created Query.
   */
  virtual Query WhereLessThan(const std::string& field,
                              const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field and the value should be less
   * than the specified value.
   *
   * @param[in] field The path of the field to compare
   * @param[in] value The value for comparison
   *
   * @return The created Query.
   */
  virtual Query WhereLessThan(const FieldPath& field, const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field and the value should be less
   * than or equal to the specified value.
   *
   * @param[in] field The name of the field to compare
   * @param[in] value The value for comparison
   *
   * @return The created Query.
   */
  virtual Query WhereLessThanOrEqualTo(const std::string& field,
                                       const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field and the value should be less
   * than or equal to the specified value.
   *
   * @param[in] field The path of the field to compare
   * @param[in] value The value for comparison
   *
   * @return The created Query.
   */
  virtual Query WhereLessThanOrEqualTo(const FieldPath& field,
                                       const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field and the value should be greater
   * than the specified value.
   *
   * @param[in] field The name of the field to compare
   * @param[in] value The value for comparison
   *
   * @return The created Query.
   */
  virtual Query WhereGreaterThan(const std::string& field,
                                 const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field and the value should be greater
   * than the specified value.
   *
   * @param[in] field The path of the field to compare
   * @param[in] value The value for comparison
   *
   * @return The created Query.
   */
  virtual Query WhereGreaterThan(const FieldPath& field,
                                 const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field and the value should be greater
   * than or equal to the specified value.
   *
   * @param[in] field The name of the field to compare
   * @param[in] value The value for comparison
   *
   * @return The created Query.
   */
  virtual Query WhereGreaterThanOrEqualTo(const std::string& field,
                                          const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field and the value should be greater
   * than or equal to the specified value.
   *
   * @param[in] field The path of the field to compare
   * @param[in] value The value for comparison
   *
   * @return The created Query.
   */
  virtual Query WhereGreaterThanOrEqualTo(const FieldPath& field,
                                          const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field, the value must be an array, and
   * that the array must contain the provided value.
   *
   * A Query can have only one whereArrayContains() filter.
   *
   * @param[in] field The name of the field containing an array to search
   * @param[in] value The value that must be contained in the array
   *
   * @return The created Query.
   */
  virtual Query WhereArrayContains(const std::string& field,
                                   const FieldValue& value);

  /**
   * @brief Creates and returns a new Query with the additional filter that
   * documents must contain the specified field, the value must be an array, and
   * that the array must contain the provided value.
   *
   * A Query can have only one whereArrayContains() filter.
   *
   * @param[in] field The path of the field containing an array to search
   * @param[in] value The value that must be contained in the array
   *
   * @return The created Query.
   */
  virtual Query WhereArrayContains(const FieldPath& field,
                                   const FieldValue& value);

  /**
   * @brief Creates and returns a new Query that's additionally sorted by the
   * specified field.
   *
   * @param[in] field The field to sort by.
   *
   * @return The created Query.
   */
  virtual Query OrderBy(const std::string& field);

  /**
   * @brief Creates and returns a new Query that's additionally sorted by the
   * specified field.
   *
   * @param[in] field The field to sort by.
   * @param[in] direction The direction to sort.
   *
   * @return The created Query.
   */
  virtual Query OrderBy(const std::string& field, Direction direction);

  /**
   * @brief Creates and returns a new Query that's additionally sorted by the
   * specified field.
   *
   * @param[in] field The field to sort by.
   *
   * @return The created Query.
   */
  virtual Query OrderBy(const FieldPath& field);

  /**
   * @brief Creates and returns a new Query that's additionally sorted by the
   * specified field.
   *
   * @param[in] field The field to sort by.
   * @param[in] direction The direction to sort.
   *
   * @return The created Query.
   */
  virtual Query OrderBy(const FieldPath& field, Direction direction);

  /**
   * @brief Creates and returns a new Query that's additionally limited to only
   * return up to the specified number of documents.
   *
   * @param[in] limit A non-negative integer to specify the maximum number of
   * items to return.
   *
   * @return The created Query.
   */
  virtual Query LimitTo(int32_t limit);

  /**
   * @brief Creates and returns a new Query that starts at the provided document
   * (inclusive). The starting position is relative to the order of the query.
   * The document must contain all of the fields provided in the orderBy of this
   * query.
   *
   * @param[in] snapshot The snapshot of the document to start at.
   *
   * @return The created Query.
   */
  virtual Query StartAt(const DocumentSnapshot& snapshot);

  /**
   * @brief Creates and returns a new Query that starts at the provided fields
   * relative to the order of the query. The order of the field values must
   * match the order of the order by clauses of the query.
   *
   * @param[in] values The field values to start this query at, in order of the
   * query's order by.
   *
   * @return The created Query.
   */
  virtual Query StartAt(const std::vector<FieldValue>& values);

  /**
   * @brief Creates and returns a new Query that starts after the provided
   * document (inclusive). The starting position is relative to the order of the
   * query. The document must contain all of the fields provided in the orderBy
   * of this query.
   *
   * @param[in] snapshot The snapshot of the document to start after.
   *
   * @return The created Query.
   */
  virtual Query StartAfter(const DocumentSnapshot& snapshot);

  /**
   * @brief Creates and returns a new Query that starts after the provided
   * fields relative to the order of the query. The order of the field values
   * must match the order of the order by clauses of the query.
   *
   * @param[in] values The field values to start this query after, in order of
   * the query's order by.
   *
   * @return The created Query.
   */
  virtual Query StartAfter(const std::vector<FieldValue>& values);

  /**
   * @brief Creates and returns a new Query that ends before the provided
   * document (inclusive). The end position is relative to the order of the
   * query. The document must contain all of the fields provided in the orderBy
   * of this query.
   *
   * @param[in] snapshot The snapshot of the document to end before.
   *
   * @return The created Query.
   */
  virtual Query EndBefore(const DocumentSnapshot& snapshot);

  /**
   * @brief Creates and returns a new Query that ends before the provided fields
   * relative to the order of the query. The order of the field values must
   * match the order of the order by clauses of the query.
   *
   * @param[in] values The field values to end this query before, in order of
   * the query's order by.
   *
   * @return The created Query.
   */
  virtual Query EndBefore(const std::vector<FieldValue>& values);

  /**
   * @brief Creates and returns a new Query that ends at the provided document
   * (inclusive). The end position is relative to the order of the query. The
   * document must contain all of the fields provided in the orderBy of this
   * query.
   *
   * @param[in] snapshot The snapshot of the document to end at.
   *
   * @return The created Query.
   */
  virtual Query EndAt(const DocumentSnapshot& snapshot);

  /**
   * @brief Creates and returns a new Query that ends at the provided fields
   * relative to the order of the query. The order of the field values must
   * match the order of the order by clauses of the query.
   *
   * @param[in] values The field values to end this query at, in order of the
   * query's order by.
   *
   * @return The created Query.
   */
  virtual Query EndAt(const std::vector<FieldValue>& values);

  /**
   * @brief Executes the query and returns the results as a QuerySnapshot.
   *
   * @return A Future that will be resolved with the results of the Query.
   */
  virtual Future<QuerySnapshot> Get() const;

  /**
   * @brief Executes the query and returns the results as a QuerySnapshot.
   *
   * By default, Get() attempts to provide up-to-date data when possible by
   * waiting for data from the server, but it may return cached data or fail if
   * you are offline and the server cannot be reached. This behavior can be
   * altered via the {@link Source} parameter.
   *
   * @param[in] source A value to configure the get behavior.
   *
   * @return A Future that will be resolved with the results of the Query.
   */
  virtual Future<QuerySnapshot> Get(Source source) const;

  /**
   * @brief Starts listening to the QuerySnapshot events referenced by this
   * query.
   *
   * @param[in] listener The event listener that will be called with the
   * snapshots, which must remain in memory until you remove the listener from
   * this Query. (Ownership is not transferred; you are responsible for making
   * sure that listener is valid as long as this Query is valid and the listener
   * is registered.)
   *
   * @return A registration object that can be used to remove the listener.
   */
  virtual ListenerRegistration AddSnapshotListener(
      EventListener<QuerySnapshot>* listener);

  /**
   * @brief Starts listening to the QuerySnapshot events referenced by this
   * query.
   *
   * @param[in] listener The event listener that will be called with the
   * snapshots, which must remain in memory until you remove the listener from
   * this Query. (Ownership is not transferred; you are responsible for making
   * sure that listener is valid as long as this Query is valid and the listener
   * is registered.)
   * @param[in] metadata_changes Indicates whether metadata-only changes (i.e.
   * only QuerySnapshot.getMetadata() changed) should trigger snapshot events.
   *
   * @return A registration object that can be used to remove the listener.
   */
  virtual ListenerRegistration AddSnapshotListener(
      EventListener<QuerySnapshot>* listener, MetadataChanges metadata_changes);

#if defined(FIREBASE_USE_STD_FUNCTION) || defined(DOXYGEN)
  /**
   * @brief Starts listening to the QuerySnapshot events referenced by this
   * query.
   *
   * @param[in] callback function or lambda to call. When this function is
   * called, exactly one of the parameters will be non-null.
   *
   * @return A registration object that can be used to remove the listener.
   *
   * @note This method is not available when using STLPort on Android, as
   * std::function is not supported on STLPort.
   */
  virtual ListenerRegistration AddSnapshotListener(
      std::function<void(const QuerySnapshot*, const Error*)> callback);

  /**
   * @brief Starts listening to the QuerySnapshot events referenced by this
   * query.
   *
   * @param[in] callback function or lambda to call. When this function is
   * called, exactly one of the parameters will be non-null.
   * @param[in] metadata_changes Indicates whether metadata-only changes (i.e.
   * only QuerySnapshot.getMetadata() changed) should trigger snapshot events.
   *
   * @return A registration object that can be used to remove the listener.
   *
   * @note This method is not available when using STLPort on Android, as
   * std::function is not supported on STLPort.
   */
  virtual ListenerRegistration AddSnapshotListener(
      std::function<void(const QuerySnapshot*, const Error*)> callback,
      MetadataChanges metadata_changes);
#endif  // defined(FIREBASE_USE_STD_FUNCTION) || defined(DOXYGEN)

 protected:
  explicit Query(QueryInternal* internal);

 private:
  friend class FirestoreInternal;
  friend class QueryInternal;

  QueryInternal* internal_ = nullptr;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_QUERY_H_
