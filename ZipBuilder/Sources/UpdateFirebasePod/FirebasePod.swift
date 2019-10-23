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

import ManifestReader

/// Updates the Firebase Pod with a release's version set.
struct FirebasePod {
  /// Relevant paths in the filesystem to build the release directory.
  struct FilesystemPaths {
    // MARK: - Required Paths

    /// A file URL to a textproto with the contents of a `FirebasePod_Release` object. Used to verify
    /// expected version numbers.
    let currentReleasePath: URL

    /// A file path to the path of the checked out git repo.
    let gitRootPath: String
  }

  /// Paths needed throughout the process of packaging the Zip file.
  private let paths: FilesystemPaths

  /// Default initializer. If allPodsPath and currentReleasePath are provided, it will also verify
  /// that the
  ///
  /// - Parameters:
  ///   - paths: Paths that are needed throughout the process of packaging the Zip file.
  init(paths: FilesystemPaths) {
    self.paths = paths
  }
}
