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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_BASE_PATH_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_BASE_PATH_H_

#include <algorithm>
#include <cctype>
#include <initializer_list>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

#include "absl/strings/str_join.h"
#include "absl/strings/str_replace.h"
#include "absl/strings/str_split.h"

namespace firebase {
namespace firestore {
namespace model {
namespace impl {

template <typename T>
class BasePath {
 protected:
  using SegmentsT = std::vector<std::string>;

 public:
  using const_iterator = SegmentsT::const_iterator;

  const std::string& operator[](const size_t i) const {
    return at(i);
  }

  const std::string& at(const size_t i) const {
    FIREBASE_ASSERT_MESSAGE(i < segments_.size(), "index %u out of range", i);
    return segments_[i];
  }

  const std::string& front() const {
    FIREBASE_ASSERT_MESSAGE(!empty(), "Cannot call front on empty path");
    return at(0);
  }
  const std::string& back() const {
    FIREBASE_ASSERT_MESSAGE(!empty(), "Cannot call back on empty path");
    return at(size() - 1);
  }

  size_t size() const {
    return segments_.size();
  }

  bool empty() const {
    return segments_.empty();
  }

  const_iterator begin() const {
    return segments_.begin();
  }
  const_iterator end() const {
    return segments_.end();
  }

  T Concatenated(const std::string& segment) const {
    auto concatenated = segments_;
    concatenated.push_back(segment);
    return T{std::move(concatenated)};
  }

  T Concatenated(const T& path) const {
    auto concatenated = segments_;
    concatenated.insert(concatenated.end(), path.begin(), path.end());
    return T{std::move(concatenated)};
  }

  T WithoutFirstElement() const {
    return WithoutFirstElements(1);
  }

  T WithoutFirstElements(const size_t count) const {
    FIREBASE_ASSERT_MESSAGE(
        count <= size(),
        "Cannot call WithoutFirstElements(%u) on path of length %u", count,
        size());
    return T{segments_.begin() + count, segments_.end()};
  }

  T WithoutLastElement() const {
    FIREBASE_ASSERT_MESSAGE(!empty(),
                            "Cannot call WithoutLastElement() on empty path");
    return T{segments_.begin(), segments_.end() - 1};
  }

  bool IsPrefixOf(const T& rhs) const {
    return size() < rhs.size() &&
           std::equal(begin(), end(), rhs.begin(), rhs.begin() + size());
  }

  bool operator==(const BasePath& rhs) const {
    return segments_ == rhs.segments_;
  }

  // std::hash
  // to_string

 protected:
  BasePath() = default;
  template <typename IterT>
  BasePath(const IterT begin, const IterT end) : segments_{begin, end} {
  }
  BasePath(std::initializer_list<std::string> list) : segments_{list} {
  }
  BasePath(SegmentsT&& segments) : segments_{std::move(segments)} {
  }
  ~BasePath() = default;

 private:
  SegmentsT segments_;
};

}  // namespace impl
}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_BASE_PATH_H_
