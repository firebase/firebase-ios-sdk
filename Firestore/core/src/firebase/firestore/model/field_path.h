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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_PATH_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_PATH_H_

#include <initializer_list>
#include <string>
#include <utility>

#include "Firestore/core/src/firebase/firestore/model/base_path.h"

namespace firebase {
namespace firestore {
namespace model {

class FieldPath : public impl::BasePath<FieldPath> {
 public:
  FieldPath() = default;
  template <typename IterT>
  FieldPath(const IterT begin, const IterT end) : BasePath{begin, end} {
  }
  FieldPath(std::initializer_list<std::string> list) : BasePath{list} {
  }
  static FieldPath ParseServerFormat(const std::string& path);

  std::string CanonicalString() const;

  // OBC: do we really need emptypath?
  // OBC: do we really need *shared* keypath?
 private:
  FieldPath(SegmentsT&& segments) : BasePath{std::move(segments)} {}
};

bool operator<(const FieldPath& lhs, const FieldPath& rhs);
bool operator==(const FieldPath& lhs, const FieldPath& rhs);

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_PATH_H_
