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

class ModelInfoRetriever : NSObject {
  var app : FirebaseApp
  var model : CustomModel

  init(app : FirebaseApp, model : CustomModel) {
    self.app = app
    self.model = model
  }

  var modelInfoFetchBaseURL : URL? {
    get {
      var components = URLComponents()
      components.scheme = "https"
      components.host = "firebaseml.googleapis.com"
      components.path = "/Model"
      return components.url
    }
  }

  var modelInfoFetchURLRequest : URLRequest {
    var request = URLRequest(url: modelInfoFetchBaseURL!)
    request.setValue(model.hash, forHTTPHeaderField: "If-None-Match")
    let fisToken : String = getTokenForApp(app: self.app)
    request.setValue(fisToken, forHTTPHeaderField: "FIS-Auth-Token")
    return request
  }

  /// Get FIS token for Firebase App
  func getTokenForApp(app : FirebaseApp) -> String {
    let installations = FirebaseCore.installations(app)
    let fisToken : String = installations.authToken(completion: nil)
    return fisToken
  }
}
