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
 * BasePath is reassignable and movable. Apart from those, all other mutating
 * operations return new independent instances.
 *
 * ## Subclassing Notes
 *
 * BasePath is strictly meant as a base class for concrete implementations. It
 * doesn't contain a single virtual method, can't be instantiated, and should
 * never be used in any polymorphic way. BasePath is templated to allow static
 * factory methods to return objects of the derived class (the expected
 * inheritance would use CRTP: struct Derived : BasePath<Derived>).
 */
template <typename T>
class BasePath {
 protected:
  using SegmentsT = std::vector<std::string>;

 public:
  using const_iterator = SegmentsT::const_iterator;

  /** Returns i-th segment of the path. */
  const std::string& operator[](const size_t i) const {
    FIREBASE_ASSERT_MESSAGE(i < segments_.size(), "index %u out of range", i);
    return segments_[i];
  }

  /** Returns the first segment of the path. */
  const std::string& first_segment() const {
    FIREBASE_ASSERT_MESSAGE(!empty(),
                            "Cannot call first_segment on empty path");
    return segments_[0];
  }
  /** Returns the last segment of the path. */
  const std::string& last_segment() const {
    FIREBASE_ASSERT_MESSAGE(!empty(), "Cannot call last_segment on empty path");
    return segments_[size() - 1];
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
  T Append(const std::string& segment) const {
    auto appended = segments_;
    appended.push_back(segment);
    return T{std::move(appended)};
  }
  T Append(std::string&& segment) const {
    auto appended = segments_;
    appended.push_back(std::move(segment));
    return T{std::move(appended)};
  }

  /**
   * Returns a new path which is the result of concatenating this path with an
   * another path.
   */
  T Append(const T& path) const {
    auto appended = segments_;
    appended.insert(appended.end(), path.begin(), path.end());
    return T{std::move(appended)};
  }

  /**
   * Returns a new path which is the result of omitting the first n segments of
   * this path.
   */
  T PopFirst(const size_t n = 1) const {
    FIREBASE_ASSERT_MESSAGE(n <= size(),
                            "Cannot call PopFirst(%u) on path of length %u", n,
                            size());
    return T{begin() + n, end()};
  }

  /**
   * Returns a new path which is the result of omitting the last segment of
   * this path.
   */
  T PopLast() const {
    FIREBASE_ASSERT_MESSAGE(!empty(), "Cannot call PopLast() on empty path");
    return T{begin(), end() - 1};
  }

  /**
   * Returns true if this path is a prefix of the given path.
   *
   * Empty path is a prefix of any path. Any path is a prefix of itself.
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

#if defined(__OBJC__)
  // For Objective-C++ hash; to be removed after migration.
  // Do NOT use in C++ code.
  NSUInteger Hash() const {
    std::hash<std::string> hash_fn;
    NSUInteger hash_result = 0;
    for (const std::string& segment : segments_) {
      hash_result = hash_result * 31u + hash_fn(segment);
    }
    return hash_result;
  }
#endif  // defined(__OBJC__)

 protected:
  BasePath() = default;
  template <typename IterT>
  BasePath(const IterT begin, const IterT end) : segments_{begin, end} {
  }
  BasePath(std::initializer_list<std::string> list) : segments_{list} {
  }
  explicit BasePath(SegmentsT&& segments) : segments_{std::move(segments)} {
  }

 private:
  SegmentsT segments_;
};

}  // namespace impl
}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_BASE_PATH_H_
