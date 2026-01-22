// Copyright 2025 Google LLC
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

private enum Constants {
  static let heartbeatFileStorageDirectoryPath = "google-heartbeat-storage"
  static let heartbeatUserDefaultsSuiteName = "com.google.heartbeat.storage"
}

protocol StorageFactory {
  static func makeStorage(id: String) -> Storage
}

// MARK: - FileStorage + StorageFactory

extension FileStorage: StorageFactory {
  static func makeStorage(id: String) -> Storage {
    // Use temporary directory for better compatibility in restricted environments (CI/Linux)
    let rootDirectory = FileManager.default.temporaryDirectory
    let heartbeatDirectoryPath = Constants.heartbeatFileStorageDirectoryPath
    let sanitizedID = id.replacingOccurrences(of: ":", with: "_")
    let heartbeatFilePath = "heartbeats-\(sanitizedID)"

    let storageURL = rootDirectory
      .appendingPathComponent(heartbeatDirectoryPath, isDirectory: true)
      .appendingPathComponent(heartbeatFilePath, isDirectory: false)

    return FileStorage(url: storageURL)
  }
}

extension FileManager {
  var applicationSupportDirectory: URL {
    // If .applicationSupportDirectory fails on Linux, fallback to .documentDirectory or similar?
    // But it should be fine.
    let urls = urls(for: .applicationSupportDirectory, in: .userDomainMask)
    if let url = urls.first {
        return url
    }
    // Fallback logic for Linux if needed (e.g. ~/.local/share)
    return URL(fileURLWithPath: ".")
  }
}

// MARK: - UserDefaultsStorage + StorageFactory

extension UserDefaultsStorage: StorageFactory {
  static func makeStorage(id: String) -> Storage {
    let suiteName = Constants.heartbeatUserDefaultsSuiteName
    let key = "heartbeats-\(id)"
    return UserDefaultsStorage(suiteName: suiteName, key: key)
  }
}
