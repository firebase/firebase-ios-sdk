// Copyright 2021 Google LLC
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

/// A factory type for `Storage`.
protocol StorageFactory {
  static func makeStorage(id: String) -> Storage
}

// MARK: - FileStorage + StorageFactory

/// <#Description#>
let kHeartbeatFileStorageDirectoryPath = "google-heartbeat-storage"

extension FileStorage: StorageFactory {
  static func makeStorage(id: String) -> Storage {
    let rootDirectory = FileManager.default.applicationSupportDirectory
    let heartbeatDirectoryPath = kHeartbeatFileStorageDirectoryPath
    let heartbeatFilePath = "heartbeats-\(id)"

    let storageURL = rootDirectory
      .appendingPathComponent(heartbeatDirectoryPath, isDirectory: true)
      .appendingPathComponent(heartbeatFilePath, isDirectory: false)

    return FileStorage(url: storageURL)
  }
}

extension FileManager {
  var applicationSupportDirectory: URL {
    // TODO: The below bang! should be safe but re-evaluate.
    urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
  }
}

// MARK: - UserDefaultsStorage + StorageFactory

/// <#Description#>
let kHeartbeatUserDefaultsSuiteName = "com.google.heartbeat.storage"

extension UserDefaultsStorage: StorageFactory {
  static func makeStorage(id: String) -> Storage {
    let suiteName = kHeartbeatUserDefaultsSuiteName
    let defaults = UserDefaults(suiteName: suiteName)
    return UserDefaultsStorage(defaults: defaults, key: "heartbeats-\(id)")
  }
}
