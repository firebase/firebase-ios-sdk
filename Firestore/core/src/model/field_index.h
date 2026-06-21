/*
 * Copyright 2022 Google LLC
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
#ifndef FIRESTORE_CORE_SRC_MODEL_FIELD_INDEX_H_
#define FIRESTORE_CORE_SRC_MODEL_FIELD_INDEX_H_

#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/util/comparison.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace model {

/** An index component consisting of field path and index type. */
class Segment : public util::Comparable<Segment> {
 public:
  /** The type of the index, e.g. for which type of query it can be used. */
  enum Kind {
    /**
     * Ordered index. Can be used for <, <=, ==, >=, >, !=, IN and NOT IN
     * queries.
     */
    kAscending,
    /**
     * Ordered index. Can be used for <, <=, ==, >=, >, !=, IN and NOT IN
     * queries.
     */
    kDescending,
    /** Contains index. Can be used for Contains and ArrayContainsAny */
    kContains,
  };

  Segment(FieldPath field_path, Kind kind)
      : field_path_(std::move(field_path)), kind_(kind) {
  }

  /** The field path of the component. */
  const FieldPath& field_path() const {
    return field_path_;
  }

  /** The indexes sorting order. */
  Kind kind() const {
    return kind_;
  }

  util::ComparisonResult CompareTo(const Segment& rhs) const;

 private:
  FieldPath field_path_;
  Kind kind_;
};

/**
 * Stores the latest read time and document that were processed for an index.
 */
class IndexOffset : public util::Comparable<IndexOffset> {
 public:
  /**
   * Creates an offset that matches all documents with a read time higher than
   * `read_time` or with a key higher than `key` for equal read times.
   */
  IndexOffset(SnapshotVersion read_time,
              DocumentKey key,
              model::BatchId largest_batch_id)
      : read_time_(std::move(read_time)),
        document_key_(std::move(key)),
        largest_batch_id_(largest_batch_id) {
  }

  /**
   * The initial mutation batch id for each index. Gets updated during index
   * backfill.
   */
  static constexpr model::BatchId InitialLargestBatchId() {
    return -1;
  }

  static IndexOffset None();

  /**
   * Creates an offset that matches all documents with a read time higher than
   * `read_time`.
   */
  static IndexOffset CreateSuccessor(SnapshotVersion read_time);

  /** Creates a new offset based on the provided document. */
  static IndexOffset FromDocument(const Document& document);

  static util::ComparisonResult DocumentCompare(const Document& lhs,
                                                const Document& rhs);

  /**
   * Returns the latest read time version that has been indexed by Firestore for
   * this field index.
   */
  const SnapshotVersion& read_time() const {
    return read_time_;
  }

  /**
   * Returns the key of the last document that was indexed for this query.
   * Returns `DocumentKey::Empty()` if no document has been indexed.
   */
  const DocumentKey& document_key() const {
    return document_key_;
  }

  /**
   * Returns the largest mutation batch id that's been processed by index
   * backfilling.
   */
  model::BatchId largest_batch_id() const {
    return largest_batch_id_;
  }

  /** Creates a pretty-printed description of the IndexOffset for debugging. */
  std::string ToString() const {
    return absl::StrCat(
        "Index Offset: {read time: ", read_time_.ToString(),
        ", document key: ", document_key_.ToString(),
        ", largest batch id: ", std::to_string(largest_batch_id_), "}");
  }

  util::ComparisonResult CompareTo(const IndexOffset& rhs) const;

 private:
  SnapshotVersion read_time_;
  DocumentKey document_key_;
  model::BatchId largest_batch_id_;
};

/**
 * Stores the "high water mark" that indicates how updated the Index is for
 * the current user.
 */
class IndexState {
 public:
  /**
   * The initial sequence number for each index. Gets updated during index
   * backfill.
   */
  constexpr static ListenSequenceNumber InitialSequenceNumber() {
    return 0;
  }

  IndexState()
      : sequence_number_(InitialSequenceNumber()),
        index_offset_(IndexOffset::None()) {
  }

  IndexState(ListenSequenceNumber sequence_number, IndexOffset offset)
      : sequence_number_(sequence_number), index_offset_(std::move(offset)) {
  }
  IndexState(ListenSequenceNumber sequence_number,
             SnapshotVersion read_time,
             DocumentKey key,
             model::BatchId largest_batch_id)
      : sequence_number_(sequence_number),
        index_offset_(std::move(read_time), std::move(key), largest_batch_id) {
  }

  /**
   * Returns a number that indicates when the index was last updated (relative
   * to other indexes).
   */
  ListenSequenceNumber sequence_number() const {
    return sequence_number_;
  }

  /** Returns the latest indexed read time and document. */
  const IndexOffset& index_offset() const {
    return index_offset_;
  }

 private:
  friend bool operator==(const IndexState& lhs, const IndexState& rhs);
  friend bool operator!=(const IndexState& lhs, const IndexState& rhs);

  ListenSequenceNumber sequence_number_;
  IndexOffset index_offset_;
};

inline bool operator==(const IndexState& lhs, const IndexState& rhs) {
  return lhs.sequence_number_ == rhs.sequence_number_ &&
         lhs.index_offset_ == rhs.index_offset_;
}

inline bool operator!=(const IndexState& lhs, const IndexState& rhs) {
  return !(lhs == rhs);
}

/**
 * An index definition for field indices in Firestore.
 *
 * Every index is associated with a collection. The definition contains a list
 * of fields and their index kind (which can be `Segment::Kind::kAscending`,
 * `Segment::Kind::kDescending` or `Segment::Kind::kContains` for
 * ArrayContains/ArrayContainsAny queries.
 *
 * Unlike the backend, the SDK does not differentiate between collection or
 * collection group-scoped indices. Every index can be used for both single
 * collection and collection group queries.
 */
class FieldIndex {
 public:
  /** An ID for an index that has not yet been added to persistence. */
  constexpr static int32_t UnknownId() {
    return -1;
  }

  /** The state of an index that has not yet been backfilled. */
  static IndexState InitialState() {
    static const IndexState kNone(IndexState::InitialSequenceNumber(),
                                  IndexOffset::None());
    return kNone;
  }

  /**
   * Compares indexes by collection group and segments. Ignores update time
   * and index ID.
   */
  static util::ComparisonResult SemanticCompare(const FieldIndex& left,
                                                const FieldIndex& right);

  FieldIndex()
      : index_id_(UnknownId()),
        unique_id_(ref_count_.fetch_add(1, std::memory_order_acq_rel)) {
  }

  FieldIndex(int32_t index_id,
             std::string collection_group,
             std::vector<Segment> segments,
             IndexState state)
      : index_id_(index_id),
        collection_group_(std::move(collection_group)),
        segments_(std::move(segments)),
        state_(std::move(state)),
        unique_id_(ref_count_.fetch_add(1, std::memory_order_acq_rel)) {
  }

  // Copy constructor
  FieldIndex(const FieldIndex& other)
      : index_id_(other.index_id_),
        collection_group_(other.collection_group_),
        segments_(other.segments_),
        state_(other.state_),
        unique_id_(ref_count_.fetch_add(1, std::memory_order_acq_rel)) {
  }

  // Copy assignment operator
  FieldIndex& operator=(const FieldIndex& other) {
    if (this != &other) {
      index_id_ = other.index_id_;
      collection_group_ = other.collection_group_;
      segments_ = other.segments_;
      state_ = other.state_;
      unique_id_ = ref_count_.fetch_add(1, std::memory_order_acq_rel);
    }
    return *this;
  }

  // Move constructor
  FieldIndex(FieldIndex&& other) noexcept
      : index_id_(other.index_id_),
        collection_group_(std::move(other.collection_group_)),
        segments_(std::move(other.segments_)),
        state_(std::move(other.state_)),
        unique_id_(ref_count_.fetch_add(1, std::memory_order_acq_rel)) {
  }

  // Move assignment operator
  FieldIndex& operator=(FieldIndex&& other) noexcept {
    if (this != &other) {
      index_id_ = other.index_id_;
      collection_group_ = std::move(other.collection_group_);
      segments_ = std::move(other.segments_);
      state_ = std::move(other.state_);
      unique_id_ = ref_count_.fetch_add(1, std::memory_order_acq_rel);
    }
    return *this;
  }

  /**
   * The index ID. Returns -1 if the index ID is not available (e.g. the index
   * has not yet been persisted).
   */
  int32_t index_id() const {
    return index_id_;
  }

  /** The collection ID this index applies to. */
  const std::string& collection_group() const {
    return collection_group_;
  }

  /** Returns all field segments for this index. */
  const std::vector<Segment>& segments() const {
    return segments_;
  }

  /** Returns how up-to-date the index is for the current user. */
  const IndexState& index_state() const {
    return state_;
  }

  /** Returns all directional (ascending/descending) segments for this index. */
  std::vector<Segment> GetDirectionalSegments() const;

  /** Returns the ArrayContains/ArrayContainsAny segment for this index. */
  absl::optional<Segment> GetArraySegment() const;

  /**
   * Returns the unique identifier for this object, ensuring a strict ordering
   * in the priority queue's comparison function.
   */
  int unique_id() const {
    return unique_id_;
  }

  /**
   * A type that can be used as the "Compare" template parameter of ordered
   * collections to have the elements ordered using
   * `FieldIndex::SemanticCompare()`.
   *
   * Example:
   * std::set<FieldIndex, FieldIndex::SemanticLess> result;
   */
  struct SemanticLess {
    bool operator()(const FieldIndex& left, const FieldIndex& right) const {
      return FieldIndex::SemanticCompare(left, right) ==
             util::ComparisonResult::Ascending;
    }
  };

 private:
  friend bool operator==(const FieldIndex& lhs, const FieldIndex& rhs);
  friend bool operator!=(const FieldIndex& lhs, const FieldIndex& rhs);

  int32_t index_id_ = UnknownId();
  std::string collection_group_;
  std::vector<Segment> segments_;
  IndexState state_;
  int unique_id_;

  // TODO(C++17): Replace with inline static std::atomic<int> ref_count_ = 0;
  static std::atomic<int> ref_count_;
};

inline bool operator==(const FieldIndex& lhs, const FieldIndex& rhs) {
  return lhs.index_id_ == rhs.index_id_ &&
         lhs.collection_group_ == rhs.collection_group_ &&
         lhs.segments_ == rhs.segments_ && lhs.state_ == rhs.state_;
}

inline bool operator!=(const FieldIndex& lhs, const FieldIndex& rhs) {
  return !(lhs == rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_FIELD_INDEX_H_
