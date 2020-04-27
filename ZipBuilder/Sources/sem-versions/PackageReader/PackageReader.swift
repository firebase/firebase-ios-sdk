/*
 * Copyright 2020 Google LLC
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

protocol PackageReader {
  /// Returns package data in a specified directory with specified types.
  /// - Parameters:
  ///   - dirURL: A URL for directory in the local file system to scan for package definitions.
  /// - Returns: An array of package data objects.
  func packagesInDirectory(_ dirURL: URL) throws -> [PackageData]
}
