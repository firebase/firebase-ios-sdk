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

#include "Firestore/core/src/firebase/firestore/util/string_win.h"
#include "absl/strings/ascii.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace util {

constexpr size_t Path::npos;
constexpr Path::char_type Path::kPreferredSeparator;

namespace {

/**
 * Returns the offset within the given path that skips the leading drive letter.
 * If there is no drive letter, returns zero.
 */
size_t StripDriveLetter(const Path::char_type* path, size_t size) {
#if defined(_WIN32)
  if (size >= 2 && path[1] == L':' && absl::ascii_isalpha(path[0])) {
    return 2;
  }
  return 0;

#else
  (void)path;
  (void)size;
  return 0;
#endif  // defined(_WIN32)
}

/** Returns true if the given character is a pathname separator. */
inline bool IsSeparator(Path::char_type c) {
#if defined(_WIN32)
  return c == L'/' || c == L'\\';
#else
  return c == '/';
#endif  // defined(_WIN32)
}

bool IsAbsolute(const Path::char_type* path, size_t size) {
  size_t offset = StripDriveLetter(path, size);
  return size >= offset && IsSeparator(path[offset]);
}

size_t LastNonSeparator(const Path::char_type* path, size_t size) {
  if (size == 0) return Path::npos;

  size_t i = size;
  for (; i-- > 0;) {
    if (!IsSeparator(path[i])) {
      return i;
    }
  }
  return Path::npos;
}

size_t LastSeparator(const Path::char_type* path, size_t size) {
  if (size == 0) return Path::npos;

  size_t i = size;
  for (; i-- > 0;) {
    if (IsSeparator(path[i])) {
      return i;
    }
  }
  return Path::npos;
}

}  // namespace

Path Path::FromUtf8(absl::string_view utf8_pathname) {
#if defined(_WIN32)
  return Path{Utf8ToNative(utf8_pathname)};

#else
  return Path{std::string{utf8_pathname}};
#endif  // defined(_WIN32)
}

#if defined(_WIN32)
std::string Path::ToString() const {
  return NativeToUtf8(pathname_);
}
#else
const std::string& Path::ToString() const {
  return pathname_;
}
#endif  // defined(_WIN32)

Path Path::Basename() const {
  size_t slash = LastSeparator(c_str(), size());
  if (slash == npos) {
    // No path separator found => the whole string.
    return *this;
  }

  // Otherwise everything after the slash is the basename (even if empty string)
  size_t start = slash + 1;
  return Path{pathname_.substr(start)};
}

Path Path::Dirname() const {
  size_t last_slash = LastSeparator(c_str(), size());
  if (last_slash == npos) {
    // No path separator found => empty string. Conformance with POSIX would
    // have us return "." here.
    return Path{string_type{}};
  }

  // Collapse runs of slashes.
  size_t non_slash = LastNonSeparator(c_str(), last_slash);
  if (non_slash == npos) {
    // All characters preceding the last path separator are slashes
    return Path{pathname_.substr(0, 1)};
  }

  // Otherwise everything up to the slash is the parent directory
  last_slash = non_slash + 1;
  return Path{pathname_.substr(0, last_slash)};
}

bool Path::IsAbsolute() const {
  return util::IsAbsolute(c_str(), size());
}

Path Path::AppendUtf8(absl::string_view path) const {
#if defined(_WIN32)
  return Append(Path::FromUtf8(path));

#else
  Path result{*this};
  result.MutableAppend(path.data(), path.size());
  return result;
#endif  // _WIN32
}

void Path::MutableAppend(const Path& path) {
  MutableAppend(path.c_str(), path.size());
}

void Path::MutableAppend(const char_type* path, size_t size) {
  if (util::IsAbsolute(path, size)) {
    pathname_.assign(path, size);

  } else {
    size_t non_slash = LastNonSeparator(pathname_.c_str(), pathname_.size());
    if (non_slash != npos) {
      pathname_.resize(non_slash + 1);
      pathname_.push_back(kPreferredSeparator);
    }

    // If path started with a slash we'd treat it as absolute above
    pathname_.append(path, size);
  }
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
