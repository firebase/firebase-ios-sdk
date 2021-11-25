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

protocol Storage {
  func read() throws -> Data
  func write(_ value: Data?) throws
}

enum StorageError: Error {
  case readError
  case writeError
}

// MARK: - FileStorage

final class FileStorage: Storage {
  private let url: URL
  private let fileManager: FileManager

  init(url: URL,
       fileManager: FileManager = .default) {
    self.url = url
    self.fileManager = fileManager
  }

  func read() throws -> Data {
    do {
      return try Data(contentsOf: url)
    } catch {
      throw StorageError.readError
    }
  }

  func write(_ value: Data?) throws {
    do {
      try createDirectories(in: url.deletingLastPathComponent())
      if let value = value {
        try value.write(to: url, options: .atomic)
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

// MARK: - UserDefaultsStorage

final class UserDefaultsStorage: Storage {
  private let defaults: UserDefaults
  private let key: String

  init(defaults: UserDefaults? = nil,
       key: String) {
    self.defaults = defaults ?? .standard
    self.key = key
  }

  func read() throws -> Data {
    if let data = defaults.data(forKey: key) {
      return data
    } else {
      throw StorageError.readError
    }
  }

  func write(_ value: Data?) throws {
    if let value = value {
      defaults.set(value, forKey: key)
    } else {
      let emptyData = Data()
      defaults.set(emptyData, forKey: key)
    }
  }
}
