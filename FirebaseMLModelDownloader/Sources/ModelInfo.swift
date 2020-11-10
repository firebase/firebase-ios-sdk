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
  var name: String

  /// User defaults associated with model.
  var defaults: UserDefaults

  /// Download URL for the model file, as returned by server.
  @UserDefaultsBacked var downloadURL: String

  /// Hash of the model, as returned by server.
  @UserDefaultsBacked var hash: String

  /// Size of the model, as returned by server.
  @UserDefaultsBacked var size: Int

  /// Local path of the model.
  @UserDefaultsBacked var path: String?

  /// Initialize model info and create user default keys.
  init(app: FirebaseApp, name: String, defaults: UserDefaults = .firebaseMLDefaults) {
    self.name = name
    self.defaults = defaults
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    let defaultsPrefix = "\(bundleID).\(app.name).\(name)"
    _downloadURL = UserDefaultsBacked(
      key: "\(defaultsPrefix).model-download-url",
      storage: defaults
    )
    _hash = UserDefaultsBacked(key: "\(defaultsPrefix).model-hash", storage: defaults)
    _size = UserDefaultsBacked(key: "\(defaultsPrefix).model-size", storage: defaults)
    _path = UserDefaultsBacked(key: "\(defaultsPrefix).model-path", storage: defaults)
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
