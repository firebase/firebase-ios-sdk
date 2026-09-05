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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import Foundation

extension FirebaseInfo {
  /// Constructs the standard HTTP headers for Firebase AI API requests.
  ///
  /// - Parameters:
  ///   - errorDomain: Suffix appended to `Constants.baseErrorDomain` if token fetching throws.
  ///     Defaults to the base type name extracted from the caller's `#fileID`.
  ///   - additionalClientTags: Additional client tags to append to the `x-goog-api-client` header.
  /// - Returns: A dictionary of HTTP header field names and values.
  /// - Throws: An error if App Check or Firebase Auth token retrieval fails.
  func requestHeaders(errorDomain: String = defaultErrorDomain(for: #fileID),
                      additionalClientTags: [String] = []) async throws -> [String: String] {
    var headers: [String: String] = [
      "Content-Type": "application/json",
    ]

    #if DEBUG
      let accessToken = ProcessInfo.processInfo.environment[Constants.gCloudAccessTokenEnvVarKey]
    #else
      let accessToken: String? = nil
    #endif // DEBUG

    if let accessToken {
      headers["Authorization"] = "Bearer \(accessToken)"
    } else {
      headers["x-goog-api-key"] = apiKey
    }

    if let bundleID = Bundle.main.bundleIdentifier {
      headers["x-ios-bundle-identifier"] = bundleID
    }

    let clientTags = [
      Constants.languageTag,
      Constants.firebaseVersionTag,
    ] + additionalClientTags
    headers["x-goog-api-client"] = clientTags.joined(separator: " ")

    if let appCheck {
      let tokenResult = try await appCheck.fetchAppCheckToken(
        limitedUse: useLimitedUseAppCheckTokens,
        domain: errorDomain
      )
      headers["X-Firebase-AppCheck"] = tokenResult.token
      if let error = tokenResult.error {
        AILog.error(
          code: .appCheckTokenFetchFailed,
          "Failed to fetch AppCheck token. Error: \(error)"
        )
      }
    }

    if accessToken == nil, let auth,
       let authToken = try await auth.getToken(forcingRefresh: false) {
      headers["Authorization"] = "Firebase \(authToken)"
    }

    if app.isDataCollectionDefaultEnabled {
      headers["X-Firebase-AppId"] = firebaseAppID
      if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        headers["X-Firebase-AppVersion"] = appVersion
      }
    }

    return headers
  }

  /// Applies the standard Firebase AI HTTP headers to a `URLRequest`.
  ///
  /// - Parameters:
  ///   - request: The `URLRequest` to mutate.
  ///   - errorDomain: Suffix appended to `Constants.baseErrorDomain` if token fetching throws.
  ///     Defaults to the base type name extracted from the caller's `#fileID`.
  ///   - additionalClientTags: Additional client tags to append to the `x-goog-api-client` header.
  /// - Throws: An error if App Check or Firebase Auth token retrieval fails.
  func applyHeaders(to request: inout URLRequest,
                    errorDomain: String = defaultErrorDomain(for: #fileID),
                    additionalClientTags: [String] = []) async throws {
    let headers = try await requestHeaders(
      errorDomain: errorDomain,
      additionalClientTags: additionalClientTags
    )
    for (field, value) in headers {
      request.setValue(value, forHTTPHeaderField: field)
    }
  }

  // MARK: - Internal Helpers

  /// Resolves a default error domain suffix from a file identifier (such as `#fileID`).
  ///
  /// Extracts the base filename without path or file extension, and strips any category suffix
  /// (e.g. `GeminiLanguageModel+Firebase.swift` becomes `GeminiLanguageModel`).
  ///
  /// - Parameter fileID: The file identifier string, typically from `#fileID`.
  /// - Returns: The extracted domain string.
  static func defaultErrorDomain(for fileID: String) -> String {
    let fileName = fileID.split(separator: "/").last.map(String.init) ?? fileID
    let baseName = fileName.split(separator: ".").first.map(String.init) ?? fileName
    let typeName = baseName.split(separator: "+").first.map(String.init) ?? baseName
    return typeName.isEmpty ? "FirebaseAI" : typeName
  }
}
