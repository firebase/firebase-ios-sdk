/*
 * Copyright 2017 Google
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

#ifndef IPHONE_FIRESTORE_SOURCE_LOCAL_STRING_VIEW_H_
#define IPHONE_FIRESTORE_SOURCE_LOCAL_STRING_VIEW_H_

#import <Foundation/Foundation.h>

#include <string>

#include "absl/strings/string_view.h"
#include "leveldb/slice.h"

namespace Firestore {

// A simple wrapper for the character data of any string-like type to which
// we'd like to temporarily refer as an argument.
//
// This is superficially similar to StringPiece and leveldb::Slice except
// that it also supports implicit conversion from NSString *, which is useful
// when writing Objective-C++ methods that accept any string-like type.
//
// Note that much like any other view-type class in C++, the caller is
// responsible for ensuring that the lifetime of the string-like data is longer
// than the lifetime of the StringView.
//
// Functions that take a StringView argument promise that they won't keep the
// pointer beyond the immediate scope of their own stack frame.
class StringView {
 public:
  // Creates a StringView from an NSString. When StringView is an argument type
  // into which an NSString* is passed, the caller should ensure that the
  // NSString is retained.
  StringView(NSString *str)  // NOLINT(runtime/explicit)
      : data_([str UTF8String]), size_([str lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
  }

  // Creates a StringView from the given char* pointer with an explicit size.
  // The character data can contain NUL bytes as a result.
  StringView(const char *data, size_t size) : data_(data), size_(size) {
  }

  // Creates a StringView from the given char* pointer but computes the size
  // with strlen. This is really only suitable for passing C string literals.
  StringView(const char *data)  // NOLINT(runtime/explicit)
      : data_(data), size_(strlen(data)) {
  }

  // Creates a StringView from the given slice.
  StringView(leveldb::Slice slice)  // NOLINT(runtime/explicit)
      : data_(slice.data()), size_(slice.size()) {
  }

  // Creates a StringView from the absl::string_view.
  StringView(absl::string_view s)  // NOLINT(runtime/explicit)
      : data_(s.data()), size_(s.size()) {
  }

  // Creates a StringView from the given std::string. The string must be an
  // lvalue for the lifetime requirements to be satisfied.
  StringView(const std::string &str)  // NOLINT(runtime/explicit)
      : data_(str.data()), size_(str.size()) {
  }

  // Converts this StringView to a Slice, which is an equivalent (and more
  // functional) type. The returned slice has the same lifetime as this
  // StringView.
  operator leveldb::Slice() {
    return leveldb::Slice(data_, size_);
  }

  // Converts this StringView to a absl::string_view, which is an equivalent (and more
  // functional) type. The returned string_view has the same lifetime as this
  // StringView.
  operator absl::string_view() {
    return absl::string_view(data_, size_);
  }

 private:
  const char *data_;
  const size_t size_;
};

}  // namespace Firestore

#endif  // IPHONE_FIRESTORE_SOURCE_LOCAL_STRING_VIEW_H_
