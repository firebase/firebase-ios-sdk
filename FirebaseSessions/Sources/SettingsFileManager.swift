//
// Copyright 2022 Google LLC
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

extension URL {
  func appendingCompatible(path: String) -> URL {
    if #available(iOS 16.0, *) {
      return self.appending(path: path)
    } else {
      return appendingPathComponent(path)
    }
  }
}

class SettingsFileManager {
  private static let directoryName: String = "com.firebase.sessions.data-v1"
  private let fileManager: FileManager
  private let directoryUrl: URL

  var settingsCacheContentPath: URL {
    return directoryUrl.appendingCompatible(path: "settings.json")
  }

  var settingsCacheKeyPath: URL { return directoryUrl.appendingCompatible(path: "cache-key.json") }

  init(fileManager: FileManager = FileManager.default) {
    self.fileManager = fileManager
    guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
    else {
      directoryUrl = URL(fileURLWithPath: "/")
      return
    }
    directoryUrl = cachesDirectory.appendingCompatible(path: SettingsFileManager.directoryName)
  }

  func data(contentsOf url: URL) -> Data? {
    do {
      return try Data(contentsOf: url)
    } catch {
      return nil
    }
  }
}
