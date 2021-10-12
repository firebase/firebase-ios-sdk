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

/// A factory type for `PersistentStorage`.
protocol PersistentStorageFactory {
  static func makeStorage(id: String) -> PersistentStorage
}

/// A `PersistentStorage` factory.
enum StorageFactory: PersistentStorageFactory {
  /// Makes a `PersistentStorage` instance using a given `String` identifier.
  ///
  /// The created persistent storage object is platform dependent. For tvOS, user defaults
  /// is used as the underlying storage container due to system storage limits. For all other platforms,
  /// the file system is used.
  ///
  /// - Parameter id: A `String` identifier used to create the `PersistentStorage`.
  /// - Returns: A `PersistentStorage` instance.
  static func makeStorage(id: String) -> PersistentStorage {
    #if os(tvOS)
      UserDefaultsStorage.makeStorage(id: id)
    #else
      FileStorage.makeStorage(id: id)
    #endif // os(tvOS)
  }
}

// MARK: - FileStorage + PersistentStorageFactory

extension FileStorage: PersistentStorageFactory {
  static func makeStorage(id: String) -> PersistentStorage {
    let rootDirectory = FileManager.default.applicationSupportDirectory
    let storagePath = "google-heartbeat-storage/heartbeats-\(id)"
    let storageURL = rootDirectory
      .appendingPathComponent(storagePath, isDirectory: false)

    return FileStorage(url: storageURL)
  }
}

// MARK: - UserDefaultsStorage + PersistentStorageFactory

extension UserDefaultsStorage: PersistentStorageFactory {
  static func makeStorage(id: String) -> PersistentStorage {
    let suiteName = "com.google.heartbeat.storage"
    let defaults = UserDefaults(suiteName: suiteName)
    return UserDefaultsStorage(defaults: defaults, key: "heartbeats-\(id)")
  }
}

// MARK: - FileManager + Extension

private extension FileManager {
  var applicationSupportDirectory: URL {
    // TODO: The below bang! should be safe but re-evaluate.
    urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
  }
}
