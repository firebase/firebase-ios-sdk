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

struct Path {
  /**
   * Returns the unqualified trailing part of the pathname, e.g. "c" for
   * "/a/b/c".
   */
  static absl::string_view Basename(absl::string_view pathname);

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
  static absl::string_view Dirname(absl::string_view pathname);

  /**
   * Returns true if the given `pathname` is an absolute path.
   */
  static bool IsAbsolute(absl::string_view pathname);

  /**
   * Returns the paths separated by path separators.
   *
   * @param base If base is of type std::string&& the result is moved from this
   *     value. Otherwise the first argument is copied.
   * @param paths The rest of the path segments.
   */
  template <typename S1, typename... SA>
  static std::string Join(S1&& base, const SA&... paths) {
    std::string result{std::forward<S1>(base)};
    JoinAppend(&result, paths...);
    return result;
  }

  /**
   * Returns the paths separated by path separators.
   */
  static std::string Join() {
    return {};
  }

 private:
  /**
   * Joins the given base path with a suffix. If `path` is relative, appends it
   * to the given base path. If `path` is absolute, replaces `base`.
   */
  static void JoinAppend(std::string* base, absl::string_view path);

  template <typename... S>
  static void JoinAppend(std::string* base,
                         absl::string_view path,
                         const S&... rest) {
    JoinAppend(base, path);
    JoinAppend(base, rest...);
  }

  static void JoinAppend(std::string* base) {
    // Recursive base case; nothing to do.
    (void)base;
  }
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_PATH_H_
