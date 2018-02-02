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

namespace firebase {
namespace firestore {
namespace model {
namespace impl {

/**
 * BasePath represents a path sequence in the Firestore database. It is composed
 * of an ordered sequence of string segments.
 *
 * BasePath is immutable. All mutating operations return new independent
 * instances.
 *
 * ## Subclassing Notes
 *
 * BasePath is strictly meant as a base class for concrete implementations. It
 * doesn't contain a single virtual method, can't be instantiated, and should
 * never be used in any polymorphic way. BasePath is templated to allow static
 * factory methods to return objects of the derived class (the expected
 * inheritance involves CRTP: struct Derived : BasePath<Derived>).
 */
template <typename T>
class BasePath {
 protected:
  using SegmentsT = std::vector<std::string>;

 public:
  using const_iterator = SegmentsT::const_iterator;

  /** Returns i-th segment of the path. */
  const std::string& operator[](const size_t i) const {
    return at(i);
  }
  const std::string& at(const size_t i) const {
    FIREBASE_ASSERT_MESSAGE(i < segments_.size(), "index %u out of range", i);
    return segments_[i];
  }

  /** Returns first segment of the path. */
  const std::string& front() const {
    FIREBASE_ASSERT_MESSAGE(!empty(), "Cannot call front on empty path");
    return at(0);
  }
  /** Returns last segment of the path. */
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

  /**
   * Returns a new path which is the result of concatenating this path with an
   * additional segment.
   */
  T Concat(const std::string& segment) const {
    auto concatenated = segments_;
    concatenated.push_back(segment);
    return T{std::move(concatenated)};
  }

  /**
   * Returns a new path which is the result of concatenating this path with an
   * another path.
   */
  T Concat(const T& path) const {
    auto concatenated = segments_;
    concatenated.insert(concatenated.end(), path.begin(), path.end());
    return T{std::move(concatenated)};
  }

  /**
   * Returns a new path which is the result of dropping the first n segments of
   * this path.
   */
  T DropFirst(const size_t n = 1) const {
    FIREBASE_ASSERT_MESSAGE(n <= size(),
                            "Cannot call DropFirst(%u) on path of length %u", n,
                            size());
    return T{begin() + n, end()};
  }

  /**
   * Returns a new path which is the result of dropping the last segment of
   * this path.
   */
  T DropLast() const {
    FIREBASE_ASSERT_MESSAGE(!empty(), "Cannot call DropLast() on empty path");
    return T{begin(), end() - 1};
  }

  /**
   * Returns true if this path is a prefix of the given path.
   *
   * Empty path is prefix of any path. Any path is prefix of itself.
   */
  bool IsPrefixOf(const T& rhs) const {
    return size() <= rhs.size() && std::equal(begin(), end(), rhs.begin());
  }

  bool operator==(const BasePath& rhs) const {
    return segments_ == rhs.segments_;
  }
  bool operator!=(const BasePath& rhs) const {
    return segments_ != rhs.segments_;
  }
  bool operator<(const BasePath& rhs) const {
    return segments_ < rhs.segments_;
  }
  bool operator>(const BasePath& rhs) const {
    return segments_ > rhs.segments_;
  }
  bool operator<=(const BasePath& rhs) const {
    return segments_ <= rhs.segments_;
  }
  bool operator>=(const BasePath& rhs) const {
    return segments_ >= rhs.segments_;
  }

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
  const SegmentsT segments_;
};

}  // namespace impl
}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_BASE_PATH_H_
