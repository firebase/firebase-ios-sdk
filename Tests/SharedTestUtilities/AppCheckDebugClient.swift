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

package import Foundation

#if canImport(FoundationNetworking)
  package import FoundationNetworking
#endif

/// Lightweight actor client for exchanging and caching an App Check Debug Token in integration
/// tests.
package actor AppCheckDebugClient {
  private let projectID: String
  private let appID: String
  private let apiKey: String
  private let debugToken: String

  private var cachedToken: String?
  private var inFlightExchangeTask: Task<String, any Error>?
  private static let baseURL = URL(string: "https://firebaseappcheck.googleapis.com")!

  /// Initializes the client with the required project, app, and authentication parameters.
  ///
  /// - Parameters:
  ///   - projectID: The Firebase project ID.
  ///   - appID: The Firebase app ID.
  ///   - apiKey: The Firebase API key.
  ///   - debugToken: The App Check debug token.
  package init(
    projectID: String,
    appID: String,
    apiKey: String,
    debugToken: String
  ) {
    assert(!projectID.isEmpty, "projectID must not be empty.")
    assert(!appID.isEmpty, "appID must not be empty.")
    assert(!apiKey.isEmpty, "apiKey must not be empty.")
    assert(!debugToken.isEmpty, "debugToken must not be empty.")
    self.projectID = projectID
    self.appID = appID
    self.apiKey = apiKey
    self.debugToken = debugToken
  }

  /// Exchanges the debug token for an App Check token, caching the result in-memory.
  ///
  /// - Parameters:
  ///   - session: The `URLSession` to use. Defaults to `.shared`.
  ///   - forceRefresh: Whether to bypass the cached token and fetch a new one.
  /// - Returns: The exchanged App Check token string.
  /// - Throws: An error if the request fails or the response cannot be parsed.
  package func exchangeDebugToken(
    session: URLSession = .shared,
    forceRefresh: Bool = false
  ) async throws -> String {
    if !forceRefresh, let cachedToken {
      return cachedToken
    }
    if !forceRefresh, let inFlightExchangeTask {
      return try await inFlightExchangeTask.value
    }

    let projectID = self.projectID
    let appID = self.appID
    let apiKey = self.apiKey
    let debugToken = self.debugToken

    let exchangeTask = Task<String, any Error> {
      let endpointURL = Self.baseURL
        .appendingPathComponent("v1")
        .appendingPathComponent("projects")
        .appendingPathComponent(projectID)
        .appendingPathComponent("apps")
        .appendingPathComponent("\(appID):exchangeDebugToken")

      var request = URLRequest(url: endpointURL)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
      request.httpBody = try JSONEncoder().encode(RequestBody(debugToken: debugToken))

      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        let errorBody = String(decoding: data, as: UTF8.self)
        throw URLError(.badServerResponse, userInfo: ["body": errorBody])
      }

      let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
      return decoded.token
    }

    self.inFlightExchangeTask = exchangeTask
    do {
      let token = try await exchangeTask.value
      self.cachedToken = token
      self.inFlightExchangeTask = nil
      return token
    } catch {
      self.inFlightExchangeTask = nil
      throw error
    }
  }
}

// MARK: - Private Payload Types

extension AppCheckDebugClient {
  fileprivate struct RequestBody: Encodable {
    let debugToken: String
  }

  fileprivate struct ResponseBody: Decodable {
    let token: String
    let ttl: String?
  }
}
