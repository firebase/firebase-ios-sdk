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

import FirebaseCore
import VertexAITestApp

@testable import struct FirebaseVertexAI.APIConfig
@testable import class FirebaseVertexAI.VertexAI

struct InstanceConfig {
  let appName: String?
  let location: String?
  let apiConfig: APIConfig

  init(appName: String? = nil, location: String? = nil, apiConfig: APIConfig) {
    self.appName = appName
    self.location = location
    self.apiConfig = apiConfig
  }

  var app: FirebaseApp? {
    return appName.map { FirebaseApp.app(name: $0) } ?? FirebaseApp.app()
  }
}

extension VertexAI {
  static func componentInstance(_ instanceConfig: InstanceConfig) -> VertexAI {
    switch instanceConfig.apiConfig.service {
    case .vertexAI:
      let location = instanceConfig.location ?? "us-central1"
      return VertexAI.vertexAI(
        app: instanceConfig.app,
        location: location,
        apiConfig: instanceConfig.apiConfig
      )
    case .developer:
      assert(
        instanceConfig.location == nil,
        "The Developer API is global and does not support `location`."
      )
      return VertexAI.vertexAI(
        app: instanceConfig.app,
        location: nil,
        apiConfig: instanceConfig.apiConfig
      )
    }
  }
}
