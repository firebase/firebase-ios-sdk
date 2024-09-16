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

import Foundation
import XCTest

/// A private wrapper for `APIKey`, hiding it from test files.
private enum APIKeyCodeSnippet {
  // The implementation of `APIKey` for use in documentation code snippets; shown in
  // https://ai.google.dev/gemini-api/docs/quickstart?lang=swift
  // [START setup_api_key]
  enum APIKey {
    // Fetch the API key from `GenerativeAI-Info.plist`
    static var `default`: String {
      guard let filePath = Bundle.main.path(forResource: "GenerativeAI-Info", ofType: "plist")
      else {
        fatalError("Couldn't find file 'GenerativeAI-Info.plist'.")
      }
      let plist = NSDictionary(contentsOfFile: filePath)
      guard let value = plist?.object(forKey: "API_KEY") as? String else {
        fatalError("Couldn't find key 'API_KEY' in 'GenerativeAI-Info.plist'.")
      }
      if value.starts(with: "_") {
        fatalError(
          "Follow the instructions at https://ai.google.dev/tutorials/setup to get an API key."
        )
      }
      return value
    }
  }
  // [END setup_api_key]
}

/// Protocol to ensure that the `APIKey` APIs do not diverge.
protocol APIKeyProtocol {
  static var `default`: String { get }
}

extension APIKeyCodeSnippet.APIKey: APIKeyProtocol {}

/// An implementation of `APIKey` for use in code snippet tests only.
enum APIKey: APIKeyProtocol {
  static let apiKeyEnvVar = "API_KEY"

  static var `default`: String {
    guard let apiKey = ProcessInfo.processInfo.environment[apiKeyEnvVar] else {
      return ""
    }
    return apiKey
  }
}
