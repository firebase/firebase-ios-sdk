// Copyright 2024 Google LLC
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
import Foundation
import XCTest

extension FirebaseApp {
  static let projectIDEnvVar = "PROJECT_ID"
  static let appIDEnvVar = "APP_ID"
  static let apiKeyEnvVar = "API_KEY"

  static func configureForSnippets() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let projectID = environment[projectIDEnvVar] else {
      throw XCTSkip("No Firebase Project ID specified in environment variable \(projectIDEnvVar).")
    }
    guard let appID = environment[appIDEnvVar] else {
      throw XCTSkip("No Google App ID specified in environment variable \(appIDEnvVar).")
    }
    guard let apiKey = environment[apiKeyEnvVar] else {
      throw XCTSkip("No API key specified in environment variable \(apiKeyEnvVar).")
    }

    let options = FirebaseOptions(googleAppID: appID, gcmSenderID: "")
    options.projectID = projectID
    options.apiKey = apiKey

    FirebaseApp.configure(options: options)
    guard FirebaseApp.isDefaultAppConfigured() else {
      XCTFail("Default Firebase app not configured.")
      return
    }
  }
}
