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

#include "absl/strings/str_replace.h"

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
}  // namespace

class FieldPath {
  using SegmentsT = std::vector<std::string>;

 public:
  using const_iterator = SegmentsT::const_iterator;

  FieldPath() = default;

  template <typename IterT>
  FieldPath(const IterT begin, const IterT end) : segments_{begin, end} {
  }

  FieldPath(std::initializer_list<std::string> list)
      : segments_{list.begin(), list.end()} {
  }

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
    // OBC ASSERT
    return FieldPath{segments_.begin() + count, segments_.end()};
  }

  FieldPath PopBack() const {
    // OBC ASSERT
    return FieldPath{segments_.begin(), segments_.end() - 1};
  }

  bool IsPrefixOf(const FieldPath& rhs) const {
    // OBC empty range
    return size() < rhs.size() &&
           std::equal(begin(), end(), rhs.begin(), rhs.begin() + size());
  }

  // std::hash
  // to_string

  //////////////////////////////////////////////////////////////////////////////

  static FieldPath FromServerFormat(const std::string& path) {
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

  // OBC: do we really need emptypath? shared keypath?

  std::string CanonicalString() const {
    std::string result;
    bool is_first_segment = true;

    for (const auto& segment : segments) {
      if (!is_first_segment) {
        is_first_segment = false;
      } else {
        result += '.';
      }

      // OBC dot
      const auto escaped =
          absl::StrReplaceAll(segment, {{"\\", "\\\\"}, {"`", "\\`"}});
      const bool is_valid_id = IsValidIdentifier(escaped);
      if (!is_valid_id) {
        result += '`';
      }
      result += escaped;
      if (!is_valid_id) {
        result += '`';
      }
    }

    return result;
  }

 private:
  FieldPath(SegmentsT&& segments) : segments_{std::move(segments)} {
  }
  SegmentsT segments_;
};

bool operator<(const FieldPath& lhs, const FieldPath& rhs) {
  return std::lexicographical_compare(lhs.begin(), lhs.end(), rhs.begin(),
                                      rhs.end());
}

bool operator==(const FieldPath& lhs, const FieldPath& rhs) {
  return std::lexicographical_compare(lhs.begin(), lhs.end(), rhs.begin(),
                                      rhs.end());
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
