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

#include "Firestore/core/src/firebase/firestore/model/base_path.h"

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

#include <algorithm>
#include <cctype>
#include <initializer_list>
#include <string>
#include <utility>
#include <vector>

#include "absl/strings/str_join.h"
#include "absl/strings/str_replace.h"
#include "absl/strings/str_split.h"

template <typename T>
class BasePath {
 protected:
  using SegmentsT = std::vector<std::string>;

 public:
  using const_iterator = SegmentsT::const_iterator;

  const std::string& operator[](const size_t index) const {
    return at(index);
  }

  const std::string& at(const size_t index) const {
    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(index < segments_.size(),
                                            "index %u out of range", index);
    return segments_[i];
  }

  const std::string& front() const {
    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(!empty(),
                                            "Cannot call front on empty path");
    return at(0);
  }
  const std::string& back() const {
    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(!empty(),
                                            "Cannot call back on empty path");
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

  FieldPath Append(const std::string& segment) const {
    auto appended = segments_;
    appended.push_back(segment);
    return FieldPath{std::move(appended)};
  }

  FieldPath Append(const FieldPath& path) const {
    auto appended = segments_;
    appended.insert(appended.end(), path.begin(), path.end());
    return FieldPath{std::move(appended)};
  }

  FieldPath PopFront(const size_t count = 1) const {
    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
        count <= size(), "Cannot call PopFront(%u) on path of length %u", count,
        size());
    return FieldPath{segments_.begin() + count, segments_.end()};
  }

  FieldPath PopBack() const {
    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
        !empty(), "Cannot call PopBack() on empty path);
    return FieldPath{segments_.begin(), segments_.end() - 1};
  }

  bool IsPrefixOf(const FieldPath& rhs) const {
    // OBC empty range
    return size() < rhs.size() &&
           std::equal(begin(), end(), rhs.begin(), rhs.begin() + size());
  }

  // std::hash
  // to_string

 protected:
  BasePath() = default;
  template <typename IterT>
  BasePath(const IterT begin, const IterT end) : segments_{begin, end} {
  }
  BasePath(std::initializer_list<std::string> list)
      : segments_{list.begin(), list.end()} {
  }
  FieldPath(SegmentsT&& segments) : segments_{std::move(segments)} {
  }
  ~BasePath() = default;

 private:
  SegmentsT segments_;
};
