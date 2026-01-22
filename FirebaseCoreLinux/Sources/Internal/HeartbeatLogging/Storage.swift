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

/// A type that reads from and writes to an underlying storage container.
protocol Storage: Sendable {
  func read() throws -> Data
  func write(_ data: Data?) throws
}

enum StorageError: Error {
  case readError
  case writeError
}

// MARK: - FileStorage

final class FileStorage: Storage {
  private let url: URL

  init(url: URL) {
    self.url = url
  }

  func read() throws -> Data {
    do {
      return try Data(contentsOf: url)
    } catch {
      throw StorageError.readError
    }
  }

  func write(_ data: Data?) throws {
    do {
      try createDirectories(in: url.deletingLastPathComponent())
      if let data {
        try data.write(to: url, options: .atomic)
      } else {
        let emptyData = Data()
        try emptyData.write(to: url, options: .atomic)
      }
    } catch {
      throw StorageError.writeError
    }
  }

  private func createDirectories(in url: URL) throws {
    do {
      try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true
      )
    } catch {
        // Ignore if exists? Swift Linux might throw even if exists?
        // Checking error might be needed.
    }
  }
}

// MARK: - UserDefaultsStorage

final class UserDefaultsStorage: Storage {
  private let suiteName: String
  private let key: String

  private var defaults: UserDefaults {
    UserDefaults(suiteName: suiteName)!
  }

  init(suiteName: String, key: String) {
    self.suiteName = suiteName
    self.key = key
  }

  func read() throws -> Data {
    if let data = defaults.data(forKey: key) {
      return data
    } else {
      throw StorageError.readError
    }
  }

  func write(_ data: Data?) throws {
    if let data {
      defaults.set(data, forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
  }
}
