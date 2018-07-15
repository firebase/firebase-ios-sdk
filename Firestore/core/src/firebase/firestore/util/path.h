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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_PATH_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_PATH_H_

#include <string>
#include <utility>

#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace util {

/**
 * An immutable native pathname string. Paths can be absolute or relative.
 *
 * Paths internally maintain their filesystem-native encoding.
 */
class Path {
 public:
#if defined(_WIN32)
  using char_type = wchar_t;
  using string_type = std::wstring;

  static constexpr char_type kPreferredSeparator = L'\\';
#else
  using char_type = char;
  using string_type = std::string;

  static constexpr char_type kPreferredSeparator = '/';
#endif  // defined(_WIN32)

  static constexpr size_t npos = static_cast<size_t>(-1);

  /**
   * Creates a new Path from a UTF-8-encoded pathname.
   */
  static Path FromUtf8(absl::string_view utf8_pathname);

#if defined(_WIN32)
  /**
   * Creates a new Path from a UTF-16-encoded pathname.
   */
  // absl::wstring_view does not exist :-(.
  static Path FromUtf16(wchar_t* begin, size_t size);
#endif

  Path() {
  }

  const string_type& native_value() const {
    return pathname_;
  }

  const char_type* c_str() const {
    return pathname_.c_str();
  }

  size_t size() const {
    return pathname_.size();
  }

#if defined(_WIN32)
  std::string ToString() const;
#else
  const std::string& ToString() const;
#endif  // defined(_WIN32)

  /**
   * Returns the unqualified trailing part of the pathname, e.g. "c" for
   * "/a/b/c".
   */
  Path Basename() const;

  /**
   * Returns the parent directory name, e.g. "/a/b" for "/a/b/c".
   *
   * Note:
   *   * Trailing slashes are treated as a separator between an empty path
   *     segment and the dirname, so Dirname("/a/b/c/") is "/a/b/c".
   *   * Runs of more than one slash are treated as a single separator, so
   *     Dirname("/a/b//c") is "/a/b".
   *   * Paths are not canonicalized, so Dirname("/a//b//c") is "/a//b".
   *   * Presently only UNIX style paths are supported (but compilation
   *     intentionally fails on Windows to prompt implementation there).
   */
  Path Dirname() const;

  /**
   * Returns true if the given `pathname` is an absolute path.
   */
  bool IsAbsolute() const;

  /**
   * Returns the paths separated by path separators.
   *
   * @param base If base is of type std::string&& the result is moved from this
   *     value. Otherwise the first argument is copied.
   * @param paths The rest of the path segments.
   */
  template <typename... P>
  Path Append(const P&... paths) const {
    return Join(*this, paths...);
  }

  /**
   * Returns a Path consisting of `*this` followed by a separator followed by
   * the path segment in the given `path` buffer.
   */
  Path AppendUtf8(absl::string_view path) const;
  Path AppendUtf8(const char* path, size_t size) const {
    return AppendUtf8(absl::string_view{path, size});
  }

  /**
   * Returns the paths separated by path separators.
   *
   * @param base If base is of type std::string&& the result is moved from this
   *     value. Otherwise the first argument is copied.
   * @param paths The rest of the path segments.
   */
  template <typename P1, typename... PA>
  static Path Join(P1&& base, const PA&... paths) {
    Path result{std::forward<P1>(base)};
    result.MutableAppend(paths...);
    return result;
  }

  friend bool operator==(const Path& lhs, const Path& rhs) {
    return lhs.pathname_ == rhs.pathname_;
  }
  friend bool operator!=(const Path& lhs, const Path& rhs) {
    return !(lhs == rhs);
  }

 private:
  explicit Path(string_type&& native_pathname)
      : pathname_{std::move(native_pathname)} {
  }

  /**
   * Joins the given base path with a UTF-8 encoded suffix. If `path` is
   * relative, appends it to the given base path. If `path` is absolute,
   * replaces `base`.
   */
  void MutableAppend(const Path& path);

  template <typename... P>
  void MutableAppend(const Path& path, const P&... rest) {
    MutableAppend(path);
    MutableAppend(rest...);
  }

  static void MutableAppend() {
    // Recursive base case; nothing to do.
  }

  void MutableAppend(const char_type* path, size_t size);

  string_type pathname_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_PATH_H_
