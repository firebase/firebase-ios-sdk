/*
 * Copyright 2026 Google LLC
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

public extension String {
  /// Returns the substring following the first occurrence of the given string, or `nil` if not
  /// found.
  ///
  /// ```swift
  /// "path/to/Headers/MyHeader.h".substringAfter("Headers/") // -> "MyHeader.h"
  /// "simple_string".substringAfter("missing")               // -> nil
  /// ```
  ///
  /// - Parameter prefix: The substring to search for.
  /// - Returns: A slice of the string beginning immediately after `prefix`, or `nil` if `prefix`
  /// does not occur in this string.
  func substringAfter(_ prefix: String) -> String.SubSequence? {
    guard let index = firstRange(of: prefix) else {
      return nil
    }

    return self[index.upperBound...]
  }

  /// Returns `true` if this path or file name has a standard C/C++/Objective-C header extension
  /// (`.h` or `.hpp`).
  var isHeaderFile: Bool {
    hasSuffix(".h") || hasSuffix(".hpp")
  }

  /// Matches this string against a simple wildcard glob pattern (supporting `*` prefix, suffix,
  /// contains, and exact match).
  ///
  /// This can be used in place of basic regex when performance is a concern.
  func matchesWildcard(_ pattern: String) -> Bool {
    if pattern == self || pattern == "*" {
      return true
    }
    if pattern.hasPrefix("*") && pattern.hasSuffix("*") && pattern.count > 2 {
      let inner = pattern.dropFirst().dropLast()
      return contains(inner)
    }
    if pattern.hasPrefix("*") {
      return hasSuffix(pattern.dropFirst())
    }
    if pattern.hasSuffix("*") {
      return hasPrefix(pattern.dropLast())
    }
    return self == pattern
  }
}
