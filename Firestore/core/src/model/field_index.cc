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

#include "Firestore/core/src/model/field_index.h"

namespace firebase {
namespace firestore {
namespace model {

std::atomic<int> FieldIndex::ref_count_{0};

util::ComparisonResult Segment::CompareTo(const Segment& rhs) const {
  auto result = field_path().CompareTo(rhs.field_path());
  if (result != util::ComparisonResult::Same) {
    return result;
  }

  if (kind_ > rhs.kind_) {
    return util::ComparisonResult::Descending;
  } else if (kind() < rhs.kind()) {
    return util::ComparisonResult::Ascending;
  }

  return util::ComparisonResult::Same;
}

IndexOffset IndexOffset::None() {
  static const IndexOffset kNone(SnapshotVersion::None(), DocumentKey::Empty(),
                                 InitialLargestBatchId());
  return kNone;
}

IndexOffset IndexOffset::CreateSuccessor(SnapshotVersion read_time) {
  // We want to create an offset that matches all documents with a read time
  // greater than the provided read time. To do so, we technically need to
  // create an offset for `(readTime, MAX_DOCUMENT_KEY)`. While we could use
  // Unicode codepoints to generate MAX_DOCUMENT_KEY, it is much easier to use
  // `(readTime + 1, DocumentKey::Empty())` since `> DocumentKey::Empty()`
  // matches all valid document IDs.
  int64_t successor_seconds = read_time.timestamp().seconds();
  int32_t successor_nanos = read_time.timestamp().nanoseconds() + 1;
  Timestamp successor = successor_nanos == 1e9
                            ? Timestamp{successor_seconds + 1, 0}
                            : Timestamp{successor_seconds, successor_nanos};
  return {SnapshotVersion(std::move(successor)), DocumentKey::Empty(),
          InitialLargestBatchId()};
}

IndexOffset IndexOffset::FromDocument(const Document& document) {
  return {document.read_time(), document->key(), InitialLargestBatchId()};
}

util::ComparisonResult IndexOffset::CompareTo(const IndexOffset& rhs) const {
  auto result = read_time_.CompareTo(rhs.read_time());
  if (result != util::ComparisonResult::Same) {
    return result;
  }

  return document_key_.CompareTo(rhs.document_key());
}

util::ComparisonResult IndexOffset::DocumentCompare(const Document& lhs,
                                                    const Document& rhs) {
  IndexOffset lhs_offset = IndexOffset::FromDocument(lhs);
  IndexOffset rhs_offset = IndexOffset::FromDocument(rhs);
  return lhs_offset.CompareTo(rhs_offset);
}

std::vector<Segment> FieldIndex::GetDirectionalSegments() const {
  std::vector<Segment> filtered_segments;
  for (const auto& segment : segments_) {
    if (segment.kind() != Segment::kContains) {
      filtered_segments.push_back(segment);
    }
  }
  return filtered_segments;
}

util::ComparisonResult FieldIndex::SemanticCompare(const FieldIndex& left,
                                                   const FieldIndex& right) {
  util::Comparator<std::string> collection_group_comparator;
  auto result = collection_group_comparator.Compare(left.collection_group(),
                                                    right.collection_group());
  if (result != util::ComparisonResult::Same) {
    return result;
  }

  auto left_it = left.segments().begin();
  auto right_it = right.segments().begin();
  while (left_it != left.segments().end() &&
         right_it != right.segments().end()) {
    result = left_it->CompareTo(*right_it);
    if (result != util::ComparisonResult::Same) {
      return result;
    }
    left_it++, right_it++;
  }

  if (left.segments().size() != right.segments().size()) {
    return left.segments().size() < right.segments().size()
               ? util::ComparisonResult::Ascending
               : util::ComparisonResult::Descending;
  }

  return util::ComparisonResult::Same;
}

absl::optional<Segment> FieldIndex::GetArraySegment() const {
  for (const auto& segment : segments_) {
    if (segment.kind() == Segment::kContains) {
      // Firestore queries can only have a single ArrayContains/ArrayContainsAny
      // statements.
      return segment;
    }
  }
  return absl::nullopt;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
