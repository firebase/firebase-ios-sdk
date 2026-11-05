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

import Foundation

public extension FileManager {
  /// Returns a Boolean value indicating whether the file at the specified path exists and has a
  /// size of zero bytes.
  ///
  /// If the file does not exist or its attributes cannot be retrieved, this method returns `false`.
  ///
  /// - Parameter path: The file system path to inspect.
  /// - Returns: `true` if the file exists and is empty (0 bytes); otherwise, `false`.
  func fileIsEmpty(atPath path: String) -> Bool {
    guard let attributes = try? attributesOfItem(atPath: path) else {
      return false
    }

    return attributes[.size] as? UInt64 == 0
  }
}
