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

/// Model info object with details about pending or downloaded model.
struct ModelInfo {
  /// Model name.
  let name: String

  // TODO: revisit UserDefaultsBacked
  /// Download URL for the model file, as returned by server.
  let downloadURL: URL

  /// Hash of the model, as returned by server.
  let modelHash: String

  /// Size of the model, as returned by server.
  let size: Int

  /// Local path of the model.
  var path: String?

  /// Initialize model info and create user default keys.
  init(name: String, downloadURL: URL, modelHash: String, size: Int) {
    self.name = name
    self.downloadURL = downloadURL
    self.modelHash = modelHash
    self.size = size
  }

  /// Get user defaults key prefix.
  private static func getUserDefaultsKeyPrefix(appName: String, modelName: String) -> String {
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    return "\(bundleID).\(appName).\(modelName)"
  }

  // TODO: Move reading and writing to user defaults to a new file.
  init?(fromDefaults defaults: UserDefaults, modelName: String, appName: String) {
    let defaultsPrefix = ModelInfo.getUserDefaultsKeyPrefix(appName: appName, modelName: modelName)
    guard let downloadURL = defaults
      .value(forKey: "\(defaultsPrefix).model-download-url") as? String,
      let url = URL(string: downloadURL),
      let modelHash = defaults.value(forKey: "\(defaultsPrefix).model-hash") as? String,
      let size = defaults.value(forKey: "\(defaultsPrefix).model-size") as? Int,
      let path = defaults.value(forKey: "\(defaultsPrefix).model-path") as? String else {
      return nil
    }
    name = modelName
    self.downloadURL = url
    self.modelHash = modelHash
    self.size = size
    self.path = path
  }

  func save(toDefaults defaults: UserDefaults, appName: String) throws {
    guard let modelPath = path else {
      throw DownloadedModelError
        .fileIOError(description: "Could not save model info to user defaults.")
    }
    let defaultsPrefix = ModelInfo.getUserDefaultsKeyPrefix(appName: appName, modelName: name)
    defaults.setValue(downloadURL.absoluteString, forKey: "\(defaultsPrefix).model-download-url")
    defaults.setValue(modelHash, forKey: "\(defaultsPrefix).model-hash")
    defaults.setValue(size, forKey: "\(defaultsPrefix).model-size")
    defaults.setValue(modelPath, forKey: "\(defaultsPrefix).model-path")
  }
}
