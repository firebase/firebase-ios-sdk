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

namespace firebase {
namespace firestore {
namespace util {

absl::string_view Path::Basename(absl::string_view pathname) {
  size_t slash = pathname.find_last_of('/');

  if (slash == absl::string_view::npos) {
    // No path separator found => the whole string.
    return pathname;
  }

  // Otherwise everything after the slash is the basename (even if empty string)
  return pathname.substr(slash + 1);
}

absl::string_view Path::Dirname(absl::string_view pathname) {
  size_t last_slash = pathname.find_last_of('/');

  if (last_slash == absl::string_view::npos) {
    // No path separator found => empty string. Conformance with POSIX would
    // have us return "." here.
    return pathname.substr(0, 0);
  }

  // Collapse runs of slashes.
  size_t nonslash = pathname.find_last_not_of('/', last_slash);
  if (nonslash == absl::string_view::npos) {
    // All characters preceding the last path separator are slashes
    return pathname.substr(0, 1);
  }

  last_slash = nonslash + 1;

  // Otherwise everything up to the slash is the parent directory
  return pathname.substr(0, last_slash);
}

bool Path::IsAbsolute(absl::string_view path) {
#if defined(_WIN32)
#error "Handle drive letters"

#else
  return !path.empty() && path.front() == '/';
#endif
}

void Path::JoinAppend(std::string* base, absl::string_view path) {
  if (IsAbsolute(path)) {
    base->assign(path.data(), path.size());

  } else {
    size_t nonslash = base->find_last_not_of('/');
    if (nonslash != std::string::npos) {
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
