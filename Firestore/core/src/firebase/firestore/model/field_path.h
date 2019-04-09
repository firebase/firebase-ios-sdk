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
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace model {

/**
 * A dot-separated path for navigating sub-objects within a document.
 *
 * Immutable; all instances are fully independent.
 */
class FieldPath : public impl::BasePath<FieldPath> {
 public:
  /** The field path string that represents the document's key. */
  static constexpr const char* kDocumentKeyPath = "__name__";

  // Note: Xcode 8.2 requires explicit specification of the constructor.
  FieldPath() : impl::BasePath<FieldPath>() {
  }

  /** Constructs the path from segments. */
  template <typename IterT>
  FieldPath(const IterT begin, const IterT end) : BasePath{begin, end} {
  }
  FieldPath(std::initializer_list<std::string> list) : BasePath{list} {
  }
  explicit FieldPath(SegmentsT&& segments) : BasePath{std::move(segments)} {
  }

  /**
   * Creates and returns a new path from the server formatted field-path string,
   * where path segments are separated by a dot "." and optionally encoded using
   * backticks.
   */
  static FieldPath FromServerFormat(absl::string_view path);
  /** Returns a field path that represents an empty path. */
  static const FieldPath& EmptyPath();
  /** Returns a field path that represents a document key. */
  static const FieldPath& KeyFieldPath();

  /** Returns a standardized string representation of this path. */
  std::string CanonicalString() const;
  /** True if this FieldPath represents a document key. */
  bool IsKeyFieldPath() const;

  bool operator==(const FieldPath& rhs) const {
    return BasePath::operator==(rhs);
  }
  bool operator!=(const FieldPath& rhs) const {
    return BasePath::operator!=(rhs);
  }
  bool operator<(const FieldPath& rhs) const {
    return BasePath::operator<(rhs);
  }
  bool operator>(const FieldPath& rhs) const {
    return BasePath::operator>(rhs);
  }
  bool operator<=(const FieldPath& rhs) const {
    return BasePath::operator<=(rhs);
  }
  bool operator>=(const FieldPath& rhs) const {
    return BasePath::operator>=(rhs);
  }
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_PATH_H_
