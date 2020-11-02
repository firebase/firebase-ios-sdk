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

/// Status of model download to device.
enum ModelDownloadStatus {
  case pending
  case downloaded
  case unknown
}

/// Model info object with details about pending or downloaded model.
struct ModelInfo {
  var name : String
  var downloadURL : URL?
  var hash : String?
  var size : Int?
  var path : String?
  var status : ModelDownloadStatus
}

/// Model info retriever for a model from local user defaults or server.
class ModelInfoRetriever : NSObject {
  /// Current Firebase app
  var app : FirebaseApp
  /// Model info associated with model.
  var modelInfo : ModelInfo
  /// Firebase installations.
  var installations : Installations
  /// User defaults associated with model.
  var defaults : UserDefaults

  /// Associate model info retriever with current Firebase app and model name.
  init(app : FirebaseApp, modelName : String) {
    self.app = app
    modelInfo = ModelInfo(name: modelName, status: .unknown)
    installations = Installations.installations(app: app)
    defaults = UserDefaults.standard
  }

  /// Construct model fetch base URL.
  var modelInfoFetchBaseURL : URL? {
    get {
      var components = URLComponents()
      components.scheme = "https"
      components.host = "firebaseml.googleapis.com"
      components.path = "/Model"
      return components.url
    }
  }

  /// Construct model fetch URL request.
  var modelInfoFetchURLRequest : URLRequest {
    var request = URLRequest(url: modelInfoFetchBaseURL!)
    if modelInfo.status == .downloaded {
      request.setValue(modelInfo.hash, forHTTPHeaderField: "If-None-Match")
    }

    let fisToken : String =  authTokenForApp(app: self.app)!
    request.setValue(fisToken, forHTTPHeaderField: "FIS-Auth-Token")
    return request
  }

  /// Get FIS token for Firebase App
  func authTokenForApp(app : FirebaseApp) -> String? {
    var token : String?
    installations.authToken { (tokenResult, error) in
      if let result = tokenResult {
        token = result.authToken
      }
    }
    return token
  }

}

extension ModelInfoRetriever {

  var userDefaultsKeyPrefix : String {
    get {
      let bundleID = Bundle.main.bundleIdentifier!
      return "com.google.firebase.ml.cloud.\(bundleID).\(app.name).\(modelInfo.name)."
    }
  }

  static let userDefaultsModelPathName : String = "model_path"
  static let userDefaultsModelHashName : String = "model_hash"
  static let userDefaultsModelSizeName : String = "model_size"
  static let userDefaultsModelDownloadStatusName : String = "model_download_status"

  /// Retrieve model info from local storage, if available, or retrieve from server.
  func retrieveModelInfo() {
    modelInfo.hash = defaults.string(forKey: userDefaultsKeyPrefix + ModelInfoRetriever.userDefaultsModelHashName)
    modelInfo.size = defaults.integer(forKey: userDefaultsKeyPrefix + ModelInfoRetriever.userDefaultsModelSizeName)
    modelInfo.status = defaults.object(forKey: userDefaultsKeyPrefix + ModelInfoRetriever.userDefaultsModelDownloadStatusName) as? ModelDownloadStatus ?? .unknown
    modelInfo.path = defaults.string(forKey: userDefaultsKeyPrefix + ModelInfoRetriever.userDefaultsModelPathName)
  }

  /// Model info from server.
  func retrieveModelInfo(request : URLRequest) {
    /// TODO: Get model info from server and save to user defaults

  }

  /// Save model info to user defaults.
  func saveModelInfo() {
    defaults.setValue(modelInfo.hash, forKey: userDefaultsKeyPrefix + ModelInfoRetriever.userDefaultsModelHashName)
    defaults.setValue(modelInfo.size, forKey: userDefaultsKeyPrefix + ModelInfoRetriever.userDefaultsModelSizeName)
    defaults.setValue(modelInfo.status, forKey: userDefaultsKeyPrefix + ModelInfoRetriever.userDefaultsModelDownloadStatusName)
    defaults.setValue(modelInfo.path, forKey: userDefaultsKeyPrefix + ModelInfoRetriever.userDefaultsModelPathName)
  }

  /// Build custom model object from model info.
  func buildModel() -> CustomModel? {
    if modelInfo.status == .downloaded {
      retrieveModelInfo()
    } else {
      retrieveModelInfo(request: modelInfoFetchURLRequest)
    }

    if modelInfo.status == .downloaded {
      let model = CustomModel(name: modelInfo.name, size: modelInfo.size!, path: modelInfo.path!, hash: modelInfo.hash!)
      return model
    }
    return nil
  }
}
