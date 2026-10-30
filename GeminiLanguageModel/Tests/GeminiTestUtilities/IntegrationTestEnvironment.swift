// Copyright 2026 Google LLC
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

/// Encapsulates environment variables and credentials used for integration testing.
package struct IntegrationTestEnvironment: Sendable {
  /// The underlying environment variables dictionary.
  package var variables: [String: String] {
    didSet {
      // Automatically refresh the parsed plist when environment variables are modified.
      googleServiceInfo = Self.parseGoogleServiceInfo(from: variables)
    }
  }

  private var googleServiceInfo: GoogleServiceInfo?

  /// An instance backed by the current process environment
  /// (`ProcessInfo.processInfo.environment`).
  package static let process =
    IntegrationTestEnvironment(variables: ProcessInfo.processInfo.environment)

  /// Creates an environment instance with the specified variables.
  ///
  /// - Parameter variables: The environment dictionary to use. Defaults to the current process
  ///   environment.
  package init(variables: [String: String] = ProcessInfo.processInfo.environment) {
    self.variables = variables
    self.googleServiceInfo = Self.parseGoogleServiceInfo(from: variables)
  }

  private static func parseGoogleServiceInfo(
    from variables: [String: String]
  ) -> GoogleServiceInfo? {
    guard let path = variables["FIREBASE_PLIST_PATH"], !path.isEmpty else { return nil }
    return GoogleServiceInfo(contentsOfFile: path)
  }

  // MARK: - Gemini Credentials

  /// Resolves the Gemini API key from `GOOGLE_API_KEY` or `GEMINI_API_KEY`.
  package var geminiAPIKey: String? {
    if let googleKey = variables["GOOGLE_API_KEY"], !googleKey.isEmpty {
      return googleKey
    }
    if let geminiKey = variables["GEMINI_API_KEY"], !geminiKey.isEmpty {
      return geminiKey
    }
    return nil
  }

  /// Indicates whether a Gemini API key is available in this environment.
  package var hasGeminiAPIKey: Bool {
    geminiAPIKey != nil
  }

  // MARK: - Firebase AI Logic Credentials

  /// Resolves the Firebase Project ID from `FIREBASE_PLIST_PATH` (if set) or
  /// `FIREBASE_PROJECT_ID`.
  package var firebaseProjectID: String? {
    if let info = googleServiceInfo {
      return info.projectID
    }
    if let projectID = variables["FIREBASE_PROJECT_ID"], !projectID.isEmpty {
      return projectID
    }
    return nil
  }

  /// Resolves the Firebase App ID from `FIREBASE_PLIST_PATH` (if set) or `FIREBASE_APP_ID`.
  package var firebaseAppID: String? {
    if let info = googleServiceInfo {
      return info.appID
    }
    if let appID = variables["FIREBASE_APP_ID"], !appID.isEmpty {
      return appID
    }
    return nil
  }

  /// Resolves the Firebase API key from `FIREBASE_PLIST_PATH` (if set) or `FIREBASE_API_KEY`.
  package var firebaseAPIKey: String? {
    if let info = googleServiceInfo {
      return info.apiKey
    }
    if let apiKey = variables["FIREBASE_API_KEY"], !apiKey.isEmpty {
      return apiKey
    }
    return nil
  }

  /// Resolves the Firebase App Check debug token from standard environment variables:
  /// `AppCheckDebugToken` with fallback to `FIRAAppCheckDebugToken`.
  package var appCheckDebugToken: String? {
    if let token = variables["AppCheckDebugToken"], !token.isEmpty {
      return token
    }
    if let legacyToken = variables["FIRAAppCheckDebugToken"], !legacyToken.isEmpty {
      return legacyToken
    }
    return nil
  }

  /// Indicates whether all required Firebase AI Logic credentials and debug token are available.
  package var hasFirebaseAILogicCredentials: Bool {
    firebaseProjectID != nil && firebaseAppID != nil && firebaseAPIKey != nil
      && appCheckDebugToken != nil
  }
}

// MARK: - Helper Types

/// Parsed representation of credentials from a `GoogleService-Info.plist` file.
private struct GoogleServiceInfo: Sendable {
  let projectID: String?
  let appID: String?
  let apiKey: String?

  init?(contentsOfFile path: String) {
    guard !path.isEmpty,
      FileManager.default.fileExists(atPath: path),
      let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
      let plist = try? PropertyListSerialization.propertyList(
        from: data,
        options: [],
        format: nil
      ) as? [String: Any]
    else {
      return nil
    }

    projectID = (plist["PROJECT_ID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    appID = (plist["GOOGLE_APP_ID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    apiKey = (plist["API_KEY"] as? String).flatMap { $0.isEmpty ? nil : $0 }
  }
}
