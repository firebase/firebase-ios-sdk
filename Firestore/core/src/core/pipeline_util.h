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

#ifndef FIRESTORE_CORE_SRC_CORE_PIPELINE_UTIL_H_
#define FIRESTORE_CORE_SRC_CORE_PIPELINE_UTIL_H_

#include <memory>
#include <string>
#include <utility>
#include <vector>
#include "absl/types/optional.h"
#include "absl/types/variant.h"

#include "Firestore/core/src/api/realtime_pipeline.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/nanopb/message.h"

namespace firebase {
namespace firestore {
namespace core {

std::vector<std::shared_ptr<api::EvaluableStage>> RewriteStages(
    const std::vector<std::shared_ptr<api::EvaluableStage>>&);

// A class that wraps a variant holding either a Target or a RealtimePipeline.
class TargetOrPipeline {
 public:
  // Default constructor (likely results in holding a default Target).
  TargetOrPipeline() = default;

  // Constructors from Target and RealtimePipeline.
  explicit TargetOrPipeline(const Target& target) : data_(target) {
  }  // NOLINT
  explicit TargetOrPipeline(Target&& target) : data_(std::move(target)) {
  }  // NOLINT
  explicit TargetOrPipeline(const api::RealtimePipeline& pipeline)  // NOLINT
      : data_(pipeline) {
  }
  explicit TargetOrPipeline(api::RealtimePipeline&& pipeline)  // NOLINT
      : data_(std::move(pipeline)) {
  }

  // Copy and move constructors/assignment operators are implicitly generated.

  // Accessors
  bool IsPipeline() const {
    return absl::holds_alternative<api::RealtimePipeline>(data_);
  }
  const Target& target() const {
    return absl::get<Target>(data_);
  }
  const api::RealtimePipeline& pipeline() const {
    return absl::get<api::RealtimePipeline>(data_);
  }

  // Member functions
  bool operator==(const TargetOrPipeline& other) const;
  size_t Hash() const;
  std::string CanonicalId() const;
  std::string ToString() const;  // Added for consistency

 private:
  absl::variant<Target, api::RealtimePipeline> data_;
};

// != operator for TargetOrPipeline
inline bool operator!=(const TargetOrPipeline& lhs,
                       const TargetOrPipeline& rhs) {
  return !(lhs == rhs);
}

// A class that wraps a variant holding either a Query or a RealtimePipeline.
// This allows defining member functions like operator== and Hash.
class QueryOrPipeline {
 public:
  // Default constructor (likely results in holding a default Query).
  QueryOrPipeline() = default;

  // Constructors from Query and RealtimePipeline.
  explicit QueryOrPipeline(const Query& query) : data_(query) {
  }  // NOLINT
  explicit QueryOrPipeline(Query&& query) : data_(std::move(query)) {
  }  // NOLINT
  explicit QueryOrPipeline(const api::RealtimePipeline& pipeline)  // NOLINT
      : data_(pipeline) {
  }
  explicit QueryOrPipeline(api::RealtimePipeline&& pipeline)  // NOLINT
      : data_(std::move(pipeline)) {
  }

  // Copy and move constructors/assignment operators are implicitly generated.

  // Accessors
  bool IsPipeline() const {
    return absl::holds_alternative<api::RealtimePipeline>(data_);
  }
  const Query& query() const {
    return absl::get<Query>(data_);
  }
  const api::RealtimePipeline& pipeline() const {
    return absl::get<api::RealtimePipeline>(data_);
  }
  TargetOrPipeline ToTargetOrPipeline() const;

  bool MatchesAllDocuments() const;
  bool has_limit() const;
  bool Matches(const model::Document& doc) const;
  model::DocumentComparator Comparator() const;

  // Member functions
  bool operator==(const QueryOrPipeline& other) const;
  size_t Hash() const;
  std::string CanonicalId() const;
  std::string ToString() const;

 private:
  absl::variant<Query, api::RealtimePipeline> data_;
};

// != operator for QueryOrPipeline
inline bool operator!=(const QueryOrPipeline& lhs, const QueryOrPipeline& rhs) {
  return !(lhs == rhs);
}

enum class PipelineFlavor {
  // The pipeline exactly represents the query.
  kExact,
  // The pipeline has additional fields projected (e.g., __key__,
  // __create_time__).
  kAugmented,
  // The pipeline has stages that remove document keys (e.g., aggregate,
  // distinct).
  kKeyless,
};

// Describes the source of a pipeline.
enum class PipelineSourceType {
  kCollection,
  kCollectionGroup,
  kDatabase,
  kDocuments,
  kUnknown,
};

// Determines the flavor of the given pipeline based on its stages.
PipelineFlavor GetPipelineFlavor(const api::RealtimePipeline& pipeline);

// Determines the source type of the given pipeline based on its first stage.
PipelineSourceType GetPipelineSourceType(const api::RealtimePipeline& pipeline);

// Retrieves the collection group ID if the pipeline's source is a collection
// group.
absl::optional<std::string> GetPipelineCollectionGroup(
    const api::RealtimePipeline& pipeline);

// Retrieves the collection path if the pipeline's source is a collection.
absl::optional<std::string> GetPipelineCollection(
    const api::RealtimePipeline& pipeline);

// Retrieves the document pathes if the pipeline's source is a document source.
absl::optional<std::vector<std::string>> GetPipelineDocuments(
    const api::RealtimePipeline& pipeline);

// Creates a new pipeline by replacing CollectionGroupSource stages with
// CollectionSource stages using the provided path.
api::RealtimePipeline AsCollectionPipelineAtPath(
    const api::RealtimePipeline& pipeline, const model::ResourcePath& path);

absl::optional<int64_t> GetLastEffectiveLimit(
    const api::RealtimePipeline& pipeline);

/**
 * Converts a core::Query into a sequence of pipeline stages.
 *
 * @param query The query to convert.
 * @return A vector of stages representing the query logic.
 */
std::vector<std::shared_ptr<api::EvaluableStage>> ToPipelineStages(
    const Query& query);

}  // namespace core
}  // namespace firestore
}  // namespace firebase

namespace std {

template <>
struct hash<firebase::firestore::core::QueryOrPipeline> {
  size_t operator()(
      const firebase::firestore::core::QueryOrPipeline& query) const {
    return query.Hash();
  }
};

template <>
struct hash<firebase::firestore::core::TargetOrPipeline> {
  size_t operator()(
      const firebase::firestore::core::TargetOrPipeline& target) const {
    return target.Hash();
  }
};

}  // namespace std

#endif  // FIRESTORE_CORE_SRC_CORE_PIPELINE_UTIL_H_
