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

class SettingsFileManager {
  private static let directoryName: String = "com.firebase.sessions.data-v1/"
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
    do {
      try fileManager.createDirectory(at: directoryUrl, withIntermediateDirectories: true)
    } catch {
      Logger.logDebug("SettingsFileManager: \(error)")
    }
  }

  func data(contentsOf url: URL) -> Data? {
    do {
      return try Data(contentsOf: url)
    } catch {
      return nil
    }
  }

  func removeCacheFiles() {
    DispatchQueue.global(qos: .background).async { [weak self] in
      guard let strongSelf = self else {
        return
      }
      do {
        try strongSelf.fileManager.removeItem(at: strongSelf.settingsCacheKeyPath)
        try strongSelf.fileManager.removeItem(at: strongSelf.settingsCacheContentPath)
      } catch {
        Logger.logDebug("removeItem failed: \(error)")
      }
    }
  }
}

extension URL {
  func appendingCompatible(path: String) -> URL {
    #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(tvOS)
      if #available(iOS 16.0, tvOS 16.0, *) {
        return appending(path: path)
      }
    #endif
    return appendingPathComponent(path)
  }
}
