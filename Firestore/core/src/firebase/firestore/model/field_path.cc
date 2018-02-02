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

// TODO(varconst): move to C++ equivalent of FSTDocumentKey.{h,cc}
const char* const kDocumentKeyPath = "__name__";

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
  auto escaped = absl::StrReplaceAll(segment, {{"\\", "\\\\"}, {"`", "\\`"}});
  const bool needs_escaping = !IsValidIdentifier(escaped);
  if (needs_escaping) {
    escaped.insert(escaped.begin(), '`');
    escaped.push_back('`');
  }
  return escaped;
}

}  // namespace

FieldPath FieldPath::ParseServerFormat(const absl::string_view path) {
  // TODO(b/37244157): Once we move to v1beta1, we should make this more
  // strict. Right now, it allows non-identifier path components, even if they
  // aren't escaped. Technically, this will mangle paths with backticks in
  // them used in v1alpha1, but that's fine.

  SegmentsT segments;
  std::string segment;
  segment.reserve(path.size());

  const auto to_string = [](const absl::string_view view) {
    return std::string{view.data(), view.data() + view.size()};
  };
  const auto finish_segment = [&segments, &segment, &path, &to_string] {
    FIREBASE_ASSERT_MESSAGE(
        !segment.empty(),
        "Invalid field path (%s). Paths must not be empty, begin with "
        "'.', end with '.', or contain '..'",
        to_string(path).c_str());
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
  finish_segment();

  FIREBASE_ASSERT_MESSAGE(!insideBackticks, "Unterminated ` in path %s",
                          to_string(path).c_str());
  // TODO(b/37244157): Make this a user-facing exception once we
  // finalize field escaping.
  FIREBASE_ASSERT_MESSAGE(!escapedCharacter,
                          "Trailing escape characters not allowed in %s",
                          to_string(path).c_str());

  return FieldPath{std::move(segments)};
}

FieldPath FieldPath::KeyFieldPath() {
  return FieldPath{kDocumentKeyPath};
}

bool FieldPath::IsKeyFieldPath() const {
  return size() == 1 && front() == kDocumentKeyPath;
}

std::string FieldPath::CanonicalString() const {
  return absl::StrJoin(begin(), end(), ".",
                       [](std::string* out, const std::string& segment) {
                         out->append(EscapedSegment(segment));
                       });
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
