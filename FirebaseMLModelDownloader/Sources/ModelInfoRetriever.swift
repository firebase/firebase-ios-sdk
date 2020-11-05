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
import FirebaseInstallations

/// Model info object with details about pending or downloaded model.
struct ModelInfo {
  /// Model name.
  var name: String

  /// Download URL for the model file, as returned by server.
  @UserDefaultsBacked
  var downloadURL: String

  /// Hash of the model, as returned by server.
  @UserDefaultsBacked
  var hash: String

  /// Size of the model, as returned by server.
  @UserDefaultsBacked
  var size: Int

  /// Local path of the model.
  @UserDefaultsBacked
  var path: String?

  /// Initialize model info and create user default keys.
  init(app: FirebaseApp, name: String) {
    self.name = name
    let bundleID = Bundle.main.bundleIdentifier!
    let defaultsPrefix = "\(bundleID).\(app.name).\(name)"
    _downloadURL = UserDefaultsBacked(key: "\(defaultsPrefix).model-download-url")
    _hash = UserDefaultsBacked(key: "\(defaultsPrefix).model-hash")
    _size = UserDefaultsBacked(key: "\(defaultsPrefix).model-size")
    _path = UserDefaultsBacked(key: "\(defaultsPrefix).model-path")
  }
}

/// Model info retriever for a model from local user defaults or server.
class ModelInfoRetriever: NSObject {
  /// Current Firebase app.
  var app: FirebaseApp
  /// Model info associated with model.
  var modelInfo: ModelInfo?
  /// Model name.
  var modelName: String
  /// Firebase installations.
  var installations: Installations
  /// User defaults associated with model.
  var defaults: UserDefaults

  /// Associate model info retriever with current Firebase app and model name.
  init(app: FirebaseApp, modelName: String, defaults: UserDefaults = .firebaseMLDefaults) {
    self.app = app
    self.modelName = modelName
    self.defaults = defaults
    installations = Installations.installations(app: app)
  }

  /// Construct model fetch base URL.
  var modelInfoFetchBaseURL: URL {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "firebaseml.googleapis.com"
    components.path = "/Model"
    return components.url!
  }

  /// Build custom model object from model info.
  func buildModel() -> CustomModel? {
    /// Build custom model only if model info is filled out, and model file is already on device.
    guard let info = modelInfo, let path = info.path else { return nil }
    let model = CustomModel(
      name: info.name,
      size: info.size,
      path: path,
      hash: info.hash
    )
    return model
  }
}

/// Extension to handle reading and writing model info to user defaults.
extension ModelInfoRetriever {
  /// Model info from server.
  func retrieveModelInfo(request: URLRequest) {
    // TODO: Get model info from server and save to user defaults
  }

  /// FIS token for Firebase app.
  func authTokenForApp(app: FirebaseApp) {
    // TODO: Get FIS auth token
  }
}

/// Named user defaults for FirebaseML.
extension UserDefaults {
  static var firebaseMLDefaults: UserDefaults {
    let suiteName = "com.google.firebase.ml"
    return UserDefaults(suiteName: suiteName)!
  }

  /// For testing: returns a new cleared instance of user defaults.
  static func getTestInstance() -> UserDefaults {
    let suiteName = "com.google.firebase.ml.test"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}

/// Property initializer for user defaults. Value is always read from or written to a named user defaults store.
@propertyWrapper struct UserDefaultsBacked<Value> {
  let key: String
  let defaultValue: Value
  let storage: UserDefaults = .firebaseMLDefaults

  var wrappedValue: Value {
    get {
      let value = storage.value(forKey: key) as? Value
      return value ?? defaultValue
    }
    set {
      guard let optional = newValue as Optional?, optional != nil else {
        storage.removeObject(forKey: key)
        return
      }
      storage.setValue(newValue, forKey: key)
    }
  }
}

/// Initialize and set default value for user default backed properties that can be optional (model path).
extension UserDefaultsBacked where Value: ExpressibleByNilLiteral {
  init(key: String) {
    self.init(key: key, defaultValue: nil)
  }
}

/// Initialize and set default value for user default backed properties that are strings (model download url, model hash).
extension UserDefaultsBacked where Value: ExpressibleByStringLiteral {
  init(key: String) {
    self.init(key: key, defaultValue: "")
  }
}

/// Initialize and set default value for user default backed properties that are int (model size).
extension UserDefaultsBacked where Value: ExpressibleByIntegerLiteral {
  init(key: String) {
    self.init(key: key, defaultValue: 0)
  }
}
