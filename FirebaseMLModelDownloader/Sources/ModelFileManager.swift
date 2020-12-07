// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Manager for common file operations.
enum ModelFileManager {
  /// Root directory of model file storage on device.
  static var modelsDirectory: URL {
    // TODO: Reconsider force unwrapping.
    #if os(tvOS)
      return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    #else
      return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    #endif
  }

  /// Check if file is available at URL.
  static func isFileReachable(at fileURL: URL) -> Bool {
    do {
      let isReachable = try fileURL.checkResourceIsReachable()
      return isReachable
    } catch {
      print(error.localizedDescription)
      /// File unreachable.
      return false
    }
  }

  /// Move file at a location to another location.
  static func moveFile(at sourceURL: URL, to destinationURL: URL) throws {
    if isFileReachable(at: destinationURL) {
      do {
        try FileManager.default.removeItem(at: destinationURL)
      } catch {
        throw DownloadedModelError
          .fileIOError(description: "Could not replace existing model file.")
      }
    }
    do {
      try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    } catch {
      throw DownloadedModelError.fileIOError(description: "Unable to save model file.")
    }
  }
}
