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

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

// There are several potential sources of inspiration for what is correct
// behavior for these functions.
//
// Python: test with
//
//   python -c 'import os.path; print(os.path.basename("a/b/c//"))'
//
// POSIX shell: test with
//
//   dirname "a/b/c//"
//
// libc++: std::filesystem does not yet ship with Xcode (as of 9.4). Test with a
// new (non-default installed) llvm, e.g. llvm-6.0:
//
//   brew install llvm
//   llvm=$(brew --prefix)/opt/llvm
//   $llvm/bin/clang++ -I$llvm/include -I$llvm/include/c++/v1 -L$llvm/lib
//       -Wl,-rpath,$llvm/lib test.cc -lc++experimental && ./a.out
//
//   test.cc contains something like:
//     #include <experimental/filesystem>
//     #include <iostream>
//     namespace fs = std::experimental::filesystem;
//     int main() {
//       std::cout << fs::path("/a/b/c//").parent_path() << std::endl;
//     }
//
// cppreference: look up example output in functions declared here:
//   https://en.cppreference.com/w/cpp/filesystem/path
//
// This implementation mostly follows python's example:
//
//   * It's pretty simple to implement
//   * POSIX is more complicated than we need
//   * std::filesystem is still too experimental (as of 2018-06-05)

#define EXPECT_BASENAME_EQ(expected, source)                  \
  do {                                                        \
    EXPECT_EQ(std::string{expected}, Path::Basename(source)); \
  } while (0)

TEST(Path, Basename_NoSeparator) {
  // POSIX would require all of these to be ".".
  // python and libc++ agree this is "".
  EXPECT_BASENAME_EQ("", "");
  EXPECT_BASENAME_EQ("a", "a");
  EXPECT_BASENAME_EQ("foo", "foo");
  EXPECT_BASENAME_EQ(".", ".");
  EXPECT_BASENAME_EQ("..", "..");
}

TEST(Path, Basename_LeadingSlash) {
  EXPECT_BASENAME_EQ("", "/");
  EXPECT_BASENAME_EQ("", "///");
  EXPECT_BASENAME_EQ("a", "/a");
  EXPECT_BASENAME_EQ("a", "//a");

  EXPECT_BASENAME_EQ(".", "/.");
  EXPECT_BASENAME_EQ("..", "/..");
  EXPECT_BASENAME_EQ("..", "//..");
}

TEST(Path, Basename_IntermediateSlash) {
  EXPECT_BASENAME_EQ("b", "/a/b");
  EXPECT_BASENAME_EQ("b", "/a//b");
  EXPECT_BASENAME_EQ("b", "//a/b");
  EXPECT_BASENAME_EQ("b", "//a//b");

  EXPECT_BASENAME_EQ("b", "//..//b");
  EXPECT_BASENAME_EQ("b", "//a/./b");
  EXPECT_BASENAME_EQ("b", "//a/.//b");
}

TEST(Path, Basename_TrailingSlash) {
  // python: "a/b//" => ""
  // POSIX: "a/b//" => "b"
  // libc++ path::filename(): "a/b//" => "." (cppreference suggests "")
  EXPECT_BASENAME_EQ("", "/a/");
  EXPECT_BASENAME_EQ("", "/a///");

  EXPECT_BASENAME_EQ("", "/a/b/");
  EXPECT_BASENAME_EQ("", "/a/b//");
  EXPECT_BASENAME_EQ("", "/a//b//");
  EXPECT_BASENAME_EQ("", "//a//b//");
}

TEST(Path, Basename_RelativePath) {
  EXPECT_BASENAME_EQ("b", "a/b");
  EXPECT_BASENAME_EQ("b", "a//b");

  EXPECT_BASENAME_EQ("b", "..//b");
  EXPECT_BASENAME_EQ("b", "a/./b");
  EXPECT_BASENAME_EQ("b", "a/.//b");
  EXPECT_BASENAME_EQ("b", "a//.//b");
}

#define EXPECT_DIRNAME_EQ(expected, source)                  \
  do {                                                       \
    EXPECT_EQ(std::string{expected}, Path::Dirname(source)); \
  } while (0)

TEST(Path, Dirname_NoSeparator) {
  // POSIX would require all of these to be ".".
  // python and libc++ agree this is "".
  EXPECT_DIRNAME_EQ("", "");
  EXPECT_DIRNAME_EQ("", "a");
  EXPECT_DIRNAME_EQ("", "foo");
  EXPECT_DIRNAME_EQ("", ".");
  EXPECT_DIRNAME_EQ("", "..");
}

TEST(Path, Dirname_LeadingSlash) {
  // POSIX says all "/".
  // python starts with "/" but does not strip trailing slashes.
  // libc++ path::parent_path() considers all of these be "", though
  // cppreference.com indicates this should be "/" in example output so this is
  // likely a bug.
  EXPECT_DIRNAME_EQ("/", "/");
  EXPECT_DIRNAME_EQ("/", "///");
  EXPECT_DIRNAME_EQ("/", "/a");
  EXPECT_DIRNAME_EQ("/", "//a");

  EXPECT_DIRNAME_EQ("/", "/.");
  EXPECT_DIRNAME_EQ("/", "/..");
  EXPECT_DIRNAME_EQ("/", "//..");
}

TEST(Path, Dirname_IntermediateSlash) {
  EXPECT_DIRNAME_EQ("/a", "/a/b");
  EXPECT_DIRNAME_EQ("/a", "/a//b");
  EXPECT_DIRNAME_EQ("//a", "//a/b");
  EXPECT_DIRNAME_EQ("//a", "//a//b");

  EXPECT_DIRNAME_EQ("//..", "//..//b");
  EXPECT_DIRNAME_EQ("//a/.", "//a/./b");
  EXPECT_DIRNAME_EQ("//a/.", "//a/.//b");
}

TEST(Path, Dirname_TrailingSlash) {
  // POSIX demands stripping trailing slashes before computing dirname, while
  // python and libc++ effectively seem to consider the path to contain an empty
  // path segment there.
  EXPECT_DIRNAME_EQ("/a", "/a/");
  EXPECT_DIRNAME_EQ("/a", "/a///");

  EXPECT_DIRNAME_EQ("/a/b", "/a/b/");
  EXPECT_DIRNAME_EQ("/a/b", "/a/b//");
  EXPECT_DIRNAME_EQ("/a//b", "/a//b//");
  EXPECT_DIRNAME_EQ("//a//b", "//a//b//");
}

TEST(Path, Dirname_RelativePath) {
  EXPECT_DIRNAME_EQ("a", "a/b");
  EXPECT_DIRNAME_EQ("a", "a//b");

  EXPECT_DIRNAME_EQ("..", "..//b");
  EXPECT_DIRNAME_EQ("a/.", "a/./b");
  EXPECT_DIRNAME_EQ("a/.", "a/.//b");
  EXPECT_DIRNAME_EQ("a//.", "a//.//b");
}

TEST(Path, IsAbsolute) {
  EXPECT_FALSE(Path::IsAbsolute(""));
  EXPECT_TRUE(Path::IsAbsolute("/"));
  EXPECT_TRUE(Path::IsAbsolute("//"));
  EXPECT_TRUE(Path::IsAbsolute("/foo"));
  EXPECT_FALSE(Path::IsAbsolute("foo"));
  EXPECT_FALSE(Path::IsAbsolute("foo/bar"));
}

TEST(Path, Join_Absolute) {
  EXPECT_EQ("/", Path::Join("/"));

  EXPECT_EQ("/", Path::Join("", "/"));
  EXPECT_EQ("/", Path::Join("a", "/"));
  EXPECT_EQ("/b", Path::Join("a", "/b"));

  // Alternate root names should be preserved.
  EXPECT_EQ("//", Path::Join("a", "//"));
  EXPECT_EQ("//b", Path::Join("a", "//b"));
  EXPECT_EQ("///b///", Path::Join("a", "///b///"));

  EXPECT_EQ("/", Path::Join("/", "/"));
  EXPECT_EQ("/b", Path::Join("/", "/b"));
  EXPECT_EQ("//b", Path::Join("//host/a", "//b"));
  EXPECT_EQ("//b", Path::Join("//host/a/", "//b"));

  EXPECT_EQ("/", Path::Join("/", ""));
  EXPECT_EQ("/a", Path::Join("/", "a"));
  EXPECT_EQ("/a/b/c", Path::Join("/", "a", "b", "c"));
  EXPECT_EQ("/a/", Path::Join("/", "a/"));
  EXPECT_EQ("/.", Path::Join("/", "."));
  EXPECT_EQ("/..", Path::Join("/", ".."));
}

TEST(Path, Join_Relative) {
  EXPECT_EQ("", Path::Join(""));

  EXPECT_EQ("", Path::Join("", "", "", ""));
  EXPECT_EQ("a/b/c", Path::Join("a/b", "c"));
  EXPECT_EQ("/c/d", Path::Join("a/b", "/c", "d"));
  EXPECT_EQ("/c/d", Path::Join("a/b/", "/c", "d"));
}

TEST(Path, Join_Types) {
  EXPECT_EQ("a/b", Path::Join(absl::string_view{"a"}, "b"));
  EXPECT_EQ("a/b", Path::Join(std::string{"a"}, "b"));

  std::string a_string{"a"};
  EXPECT_EQ("a/b", Path::Join(a_string, "b"));
  EXPECT_EQ("a", a_string);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
