/*
 * Copyright 2019 Google
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

import Foundation

/// Utilities to simplify URL manipulation.
public extension URL {
  /// Appends each item in the array as a component to the existing URL.
  func appendingPathComponents(_ components: [String]) -> URL {
    // Append multiple path components in a single call to prevent long lines of multiple calls.
    var result = self
    components.filter {
      // Filter out any empty strings.
      !$0.isEmpty
    }.forEach {
      // Add the non-empty strings.
      result.appendPathComponent($0)
    }
    return result
  }
}
