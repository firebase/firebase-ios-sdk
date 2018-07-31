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

#include "Firestore/core/src/firebase/firestore/util/path.h"

#include "absl/strings/ascii.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

static constexpr absl::string_view::size_type npos = absl::string_view::npos;

/** Returns the given path with its leading drive letter removed. */
inline absl::string_view StripDriveLetter(absl::string_view path) {
#if defined(_WIN32)
  if (path.size() >= 2 && path[1] == ':' && absl::ascii_isalpha(path[0])) {
    return path.substr(2);
  }
  return path;

#else
  return path;
#endif  // defined(_WIN32)
}

/** Returns true if the given character is a pathname separator. */
inline bool IsSeparator(char c) {
#if defined(_WIN32)
  return c == '/' || c == '\\';
#else
  return c == '/';
#endif  // defined(_WIN32)
}

}  // namespace

absl::string_view Path::Basename(absl::string_view pathname) {
  size_t slash = pathname.find_last_of('/');

  if (slash == npos) {
    // No path separator found => the whole string.
    return pathname;
  }

  // Otherwise everything after the slash is the basename (even if empty string)
  return pathname.substr(slash + 1);
}

absl::string_view Path::Dirname(absl::string_view pathname) {
  size_t last_slash = pathname.find_last_of('/');

  if (last_slash == npos) {
    // No path separator found => empty string. Conformance with POSIX would
    // have us return "." here.
    return pathname.substr(0, 0);
  }

  // Collapse runs of slashes.
  size_t nonslash = pathname.find_last_not_of('/', last_slash);
  if (nonslash == npos) {
    // All characters preceding the last path separator are slashes
    return pathname.substr(0, 1);
  }

  last_slash = nonslash + 1;

  // Otherwise everything up to the slash is the parent directory
  return pathname.substr(0, last_slash);
}

bool Path::IsAbsolute(absl::string_view path) {
  path = StripDriveLetter(path);
  return !path.empty() && IsSeparator(path.front());
}

void Path::JoinAppend(std::string* base, absl::string_view path) {
  if (IsAbsolute(path)) {
    base->assign(path.data(), path.size());

  } else {
    size_t nonslash = base->find_last_not_of('/');
    if (nonslash != npos) {
      base->resize(nonslash + 1);
      base->push_back('/');
    }

    // If path started with a slash we'd treat it as absolute above
    base->append(path.data(), path.size());
  }
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
