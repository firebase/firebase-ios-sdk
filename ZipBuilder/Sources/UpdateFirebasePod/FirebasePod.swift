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

/// Misc. constants used in the build tool.
public struct Constants {
  /// Constants related to the Xcode project template.
  public struct ProjectPath {
    // Required for building.

    // Make the struct un-initializable.
    @available(*, unavailable)
    init() { fatalError() }
  }

  // Make the struct un-initializable.
  @available(*, unavailable)
  init() { fatalError() }
}

/// A zip file builder. The zip file can be built with the `buildAndAssembleReleaseDir()` function.
struct FirebasePod {

  /// Relevant paths in the filesystem to build the release directory.
  struct FilesystemPaths {
    // MARK: - Required Paths

    /// A file URL to a textproto with the contents of a `FirebasePod_Release` object. Used to verify
    /// expected version numbers.
    var currentReleasePath: URL?

    // MARK: - Optional Paths

    /// A file URL to a textproto with the contents of a `FirebasePod_FirebasePods` object. Used to
    /// verify expected version numbers.
    var allPodsPath: URL?

    /// A file path to the path of the checked out git repo.
    var gitRootPath: String?
  }

  /// Paths needed throughout the process of packaging the Zip file.
  private let paths: FilesystemPaths

  /// Default initializer. If allPodsPath and currentReleasePath are provided, it will also verify
  /// that the
  ///
  /// - Parameters:
  ///   - paths: Paths that are needed throughout the process of packaging the Zip file.
  ///   - customSpecRepo: A custom spec repo to be used for fetching CocoaPods from.
  init(paths: FilesystemPaths, customSpecRepos: [URL]? = nil) {
    self.paths = paths
  }

}
