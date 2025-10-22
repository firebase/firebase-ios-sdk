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

#ifndef FIRESTORE_CORE_SRC_API_PIPELINE_RESULT_CHANGE_H_
#define FIRESTORE_CORE_SRC_API_PIPELINE_RESULT_CHANGE_H_

#include <memory>
#include <utility>

#include "Firestore/core/src/api/pipeline_result.h"

namespace firebase {
namespace firestore {
namespace api {

class PipelineResultChange {
 public:
  enum class Type { Added, Modified, Removed };

  PipelineResultChange() = default;
  PipelineResultChange(Type type,
                       PipelineResult result,
                       size_t old_index,
                       size_t new_index)
      : type_(type),
        result_(std::move(result)),
        old_index_(old_index),
        new_index_(new_index) {
  }

  size_t Hash() const;

  Type type() const {
    return type_;
  }

  PipelineResult result() const {
    return result_;
  }

  size_t old_index() const {
    return old_index_;
  }

  size_t new_index() const {
    return new_index_;
  }

  /**
   * A sentinel return value for old_index() and new_index() indicating that
   * there's no relevant index to return because the document was newly added
   * or removed respectively.
   */
  static constexpr size_t npos = static_cast<size_t>(-1);

 private:
  Type type_;
  PipelineResult result_;
  size_t old_index_;
  size_t new_index_;
};

bool operator==(const PipelineResultChange& lhs,
                const PipelineResultChange& rhs);

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_PIPELINE_RESULT_CHANGE_H_
