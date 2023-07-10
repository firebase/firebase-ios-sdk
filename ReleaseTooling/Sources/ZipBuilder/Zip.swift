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
import Utils

/// Convenience
struct Zip {
  /// Compresses the contents of the directory into a Zip file that resides beside the directory
  /// being compressed and has the same name as the directory with a `.zip` suffix.
  ///
  /// - Parameter directory: The directory to compress.
  /// - Parameter name: The name of the Zip file.
  /// - Returns: A URL to the Zip file created.
  static func zipContents(ofDir directory: URL, name: String) -> URL {
    // Ensure the directory being compressed exists.
    guard FileManager.default.directoryExists(at: directory) else {
      fatalError("Attempted to compress contents of \(directory) but the directory does not exist.")
    }

    // This `zip` command needs to be run in the parent directory.
    let parentDir = directory.deletingLastPathComponent()
    let zip = parentDir.appendingPathComponent(name)

    // If it exists already, try to remove it.
    if FileManager.default.fileExists(atPath: zip.path) {
      try? FileManager.default.removeItem(at: zip)
    }

    // Run the `zip` command. This could be replaced with a proper Zip library in the future.
    let command = "zip --symlinks -q -r -dg \(zip.lastPathComponent) \(directory.lastPathComponent)"
    let result = Shell.executeCommandFromScript(command, workingDir: parentDir)
    switch result {
    case .success:
      print("Successfully built Zip file.")
      return zip
    case let .error(code, output):
      fatalError("Error \(code) building zip file: \(output)")
    }
  }

  // Mark initialization as unavailable.
  @available(*, unavailable)
  init() { fatalError() }
}
