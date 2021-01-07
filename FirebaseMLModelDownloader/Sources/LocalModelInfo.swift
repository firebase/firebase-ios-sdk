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
import FirebaseCore

/// Model info object with details about downloaded and locally available model.
// TODO: Can this be backed by user defaults property wrappers?
class LocalModelInfo {
  /// Model name.
  let name: String

  /// Download URL for the model file, as returned by server.
  let downloadURL: URL

  /// Hash of the model, as returned by server.
  let modelHash: String

  /// Size of the model, as returned by server.
  let size: Int

  /// Local path of the model.
  let path: String

  /// Get user defaults key prefix.
  private static func getUserDefaultsKeyPrefix(appName: String, modelName: String) -> String {
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    return "\(bundleID).\(appName).\(modelName)"
  }

  init(name: String, downloadURL: URL, modelHash: String, size: Int, path: String) {
    self.name = name
    self.downloadURL = downloadURL
    self.modelHash = modelHash
    self.size = size
    self.path = path
  }

  /// Convenience init to create local model info from remotely downloaded model info and a local model path.
  convenience init(from remoteModelInfo: RemoteModelInfo, path: String) {
    self.init(
      name: remoteModelInfo.name,
      downloadURL: remoteModelInfo.downloadURL,
      modelHash: remoteModelInfo.modelHash,
      size: remoteModelInfo.size,
      path: path
    )
  }

  /// Convenience init to create local model info from stored info in user defaults.
  convenience init?(fromDefaults defaults: UserDefaults, name: String, appName: String) {
    let defaultsPrefix = LocalModelInfo.getUserDefaultsKeyPrefix(appName: appName, modelName: name)
    guard let downloadURL = defaults
      .value(forKey: "\(defaultsPrefix).model-download-url") as? String,
      let url = URL(string: downloadURL),
      let modelHash = defaults.value(forKey: "\(defaultsPrefix).model-hash") as? String,
      let size = defaults.value(forKey: "\(defaultsPrefix).model-size") as? Int,
      let path = defaults.value(forKey: "\(defaultsPrefix).model-path") as? String else {
      return nil
    }
    self.init(name: name, downloadURL: url, modelHash: modelHash, size: size, path: path)
  }
}

/// Extension to write local model info to user defaults.
extension LocalModelInfo: DownloaderUserDefaults {
  func writeToDefaults(_ defaults: UserDefaults, appName: String) {
    let defaultsPrefix = LocalModelInfo.getUserDefaultsKeyPrefix(appName: appName, modelName: name)
    defaults.setValue(downloadURL.absoluteString, forKey: "\(defaultsPrefix).model-download-url")
    defaults.setValue(modelHash, forKey: "\(defaultsPrefix).model-hash")
    defaults.setValue(size, forKey: "\(defaultsPrefix).model-size")
    defaults.setValue(path, forKey: "\(defaultsPrefix).model-path")
  }
}

/// Named user defaults for FirebaseML.
extension UserDefaults {
  static var firebaseMLDefaults: UserDefaults {
    let suiteName = "com.google.firebase.ml"
    // TODO: reconsider force unwrapping
    let defaults = UserDefaults(suiteName: suiteName)!
    return defaults
  }
}
