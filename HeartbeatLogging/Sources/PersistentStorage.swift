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

protocol PersistentStorage {
  func read() throws -> Data
  func write(_ value: Data?) throws
}

// MARK: - FileStorage

class FileStorage {
  private let url: URL
  private let fileManager: FileManager

  init(
    url: URL,
    fileManager: FileManager = .default
  ) {
    self.url = url
    self.fileManager = fileManager
  }

  private func createDirectories(in url: URL) throws {
      do {
        try fileManager.createDirectory(
          at: url,
          withIntermediateDirectories: true,
          attributes: nil
        )
      } catch CocoaError.fileWriteFileExists {
        // Directory already exists.
      } catch { throw error }
  }
}

extension FileStorage: PersistentStorage {
  func read() throws -> Data {
    try Data(contentsOf: url)
  }

  // TODO: Consider API for clearing contents vs removing file.
  func write(_ value: Data?) throws {
    try createDirectories(in: url)
    // Case: Value is **not** nil → Write to file
    // Case: Value is nil         → Remove file contents
    let value = value ?? Data()
    try value.write(to: url, options: .atomic)
  }
}

// MARK: - UserDefaultsStorage

class UserDefaultsStorage {
  private let defaults: UserDefaults
  private let key: String

  init(
    defaults: UserDefaults? = nil,
    key: String
  ) {
    self.defaults = defaults ?? .standard
    self.key = key
  }
}

extension UserDefaultsStorage: PersistentStorage {
  func read() throws -> Data {
    if let data = defaults.data(forKey: key) {
      return data
    } else {
      throw CocoaError(.fileReadNoSuchFile) // TODO: Improve
    }
  }

  func write(_ value: Data?) throws {
    defaults.set(value, forKey: key)
  }
}

