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

#include "Firestore/core/src/firebase/firestore/model/field_path.h"

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

#include <algorithm>
#include <cctype>
#include <utility>

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

FieldPath FieldPath::ParseServerFormat(const std::string& path) {
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

std::string FieldPath::CanonicalString() const {
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

}  // namespace model
}  // namespace firestore
}  // namespace firebase
