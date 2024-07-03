// Copyright 2023 Google LLC
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

class GetProjectConfigResponse: AuthRPCResponse {
  required init() {}

  var projectID: String?

  var authorizedDomains: [String]?

  func setFields(dictionary: [String: AnyHashable]) throws {
    projectID = dictionary["projectId"] as? String
    if let authorizedDomains = dictionary["authorizedDomains"] as? String,
       let data = authorizedDomains.data(using: .utf8) {
      if let decoded = try? JSONSerialization.jsonObject(
        with: data,
        options: [.mutableLeaves]
      ), let array = decoded as? [String] {
        self.authorizedDomains = array
      }
    } else if let authorizedDomains = dictionary["authorizedDomains"] as? [String] {
      self.authorizedDomains = authorizedDomains
    }
  }
}
