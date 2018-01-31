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

namespace firebase {
namespace firestore {
namespace model {

namespace {

bool IsValidIdentifier(const std::string& segment) {
  if (segment.empty()) {
    return false;
  }
  if (segment.front() != '_' && !std::isalpha(segment.front())) {
    return false;
  }
  if (std::any_of(segment.begin(), segment.end(), [](const unsigned char c) {
        return c != '_' && !std::isalnum(c);
      })) {
    return false;
  }

  return true;
}

std::string EscapedSegment(const std::string& segment) {
  // OBC dot
  auto escaped = absl::StrReplaceAll(segment, {{"\\", "\\\\"}, {"`", "\\`"}});
  const bool needs_escaping = !IsValidIdentifier(escaped);
  if (needs_escaping) {
    escaped.push_front('`');
    escaped.push_back('`');
  }
  return escaped;
}

}  // namespace

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

class FieldPath : public BasePath {
 public:
  FieldPath() = default;
  template <typename IterT>
  FieldPath(const IterT begin, const IterT end) : BasePath{begin, end} {
  }
  FieldPath(std::initializer_list<std::string> list) : BasePath{list} {
  }

  static FieldPath ParseServerFormat(const std::string& path) {
    // TODO(b/37244157): Once we move to v1beta1, we should make this more
    // strict. Right now, it allows non-identifier path components, even if they
    // aren't escaped. Technically, this will mangle paths with backticks in
    // them used in v1alpha1, but that's fine.

    SegmentsT segments;
    std::string segment;
    segment.reserve(path.size());

    const auto finish_segment = [&segments, &segment] {
      FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
          !segment.empty(),
          "Invalid field path (%s). Paths must not be empty, begin with "
          "'.', end with '.', or contain '..'",
          path.c_str());
      // Move operation will clear segment, but capacity will remain the same
      // (not strictly speaking required by the standard, but true in practice).
      segments.push_back(std::move(segment));
    };

    // Inside backticks, dots are treated literally.
    bool insideBackticks = false;
    // Whether to treat '\' literally or as an escape character.
    bool escapedCharacter = false;

    for (const char c : path) {
      if (c == '\0') {
        break;
      }
      if (escapedCharacter) {
        escapedCharacter = false;
        segment += c;
        continue;
      }

      switch (c) {
        case '.':
          if (!insideBackticks) {
            finish_segment();
          } else {
            segment += c;
          }
          break;

        case '`':
          insideBackticks = !insideBackticks;
          break;

        case '\\':
          escapedCharacter = true;
          break;

        default:
          segment += c;
          break;
      }
    }

    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
        !insideBackticks, "Unterminated ` in path %s", path.c_str());
    // TODO(b/37244157): Make this a user-facing exception once we
    // finalize field escaping.
    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
        !escapedCharacter, "Trailing escape characters not allowed in %s",
        path.c_str());

    return FieldPath{std::move(segments)};
  }

  std::string CanonicalString() const {
    return absl::StrJoin(begin(), end(), '.',
                         [](std::string* out, const std::string& segment) {
                           out->append(EscapedSegment(segment));
                         });
  }

  // OBC: do we really need emptypath?
  // OBC: do we really need *shared* keypath?
};

bool operator<(const FieldPath& lhs, const FieldPath& rhs) {
  return std::lexicographical_compare(lhs.begin(), lhs.end(), rhs.begin(),
                                      rhs.end());
}

bool operator==(const FieldPath& lhs, const FieldPath& rhs) {
  return std::lexicographical_compare(lhs.begin(), lhs.end(), rhs.begin(),
                                      rhs.end());
}

class ResourcePath : public BasePath {
 public:
  ResourcePath() = default;
  template <typename IterT>
  ResourcePath(const IterT begin, const IterT end) : BasePath{begin, end} {
  }
  ResourcePath(std::initializer_list<std::string> list) : BasePath{list} {
  }

  static ResourcePath Parse(const std::string& path) {
    // NOTE: The client is ignorant of any path segments containing escape
    // sequences (e.g. __id123__) and just passes them through raw (they exist
    // for legacy reasons and should not be used frequently).

    FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
        path.find("//") == std::string::npos,
        "Invalid path (%s). Paths must not contain // in them.", path.c_str());

    // SkipEmpty because we may still have an empty segment at the beginning or
    // end if they had a leading or trailing slash (which we allow).
    auto segments = absl::StrSplit(path, '/', absl::SkipEmpty());
    return ResourcePath{std::move(segments)};
  }

  std::string CanonicalString() const {
    // NOTE: The client is ignorant of any path segments containing escape
    // sequences (e.g. __id123__) and just passes them through raw (they exist
    // for legacy reasons and should not be used frequently).

    return absl::StrJoin(begin(), end(), '/');
  }

 private:
  ResourcePath(SegmentsT&& segments) : BasePath{segments} {
  }
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase
