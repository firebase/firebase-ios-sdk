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

public import FirebaseCore
private import FirebaseCoreExtension
#if canImport(Darwin)
  package import Foundation
#else
  import Foundation
#endif
#if canImport(FoundationNetworking)
  package import FoundationNetworking
#endif

/// **[Experimental]** A Firebase App Check provider that exchanges a debug token registered in the
/// Firebase console for a Firebase App Check token.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class AppCheckDebugProvider: AppCheckProvider, Sendable {
  private static let defaultBaseURL = "https://firebaseappcheck.googleapis.com/v1"
  private static let loggerService = "[FirebaseAppCheck]"

  private let projectID: String
  private let googleAppID: String
  private let apiKey: String
  private let baseURL: String
  private let session: URLSession
  private let environment: [String: String]
  private let generatedLocalDebugToken: String

  /// **[Experimental]** Creates an `AppCheckDebugProvider` for the specified `FirebaseApp`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter app: The `FirebaseApp` whose options are used for debug token exchange.
  public convenience init?(app: FirebaseApp) {
    let options = app.options
    var missingFields: [String] = []
    if options.apiKey == nil || options.apiKey?.isEmpty == true {
      missingFields.append("apiKey")
    }
    if options.projectID == nil || options.projectID?.isEmpty == true {
      missingFields.append("projectID")
    }
    if options.googleAppID.isEmpty {
      missingFields.append("googleAppID")
    }

    guard missingFields.isEmpty,
          let apiKey = options.apiKey,
          let projectID = options.projectID else {
      FirebaseLogger.log(
        level: .error,
        service: Self.loggerService,
        code: "I-FAA002001",
        message: "Cannot instantiate `AppCheckDebugProvider` for app: \(app.name). " +
          "The following `FirebaseOptions` fields are missing: " +
          "\(missingFields.joined(separator: ", "))"
      )
      return nil
    }

    self.init(
      projectID: projectID,
      googleAppID: options.googleAppID,
      apiKey: apiKey
    )
  }

  /// Creates an `AppCheckDebugProvider` with explicit configuration for testing.
  package init(projectID: String,
               googleAppID: String,
               apiKey: String,
               baseURL: String = AppCheckDebugProvider.defaultBaseURL,
               session: URLSession = .shared,
               environment: [String: String] = ProcessInfo.processInfo.environment,
               localDebugToken: String = UUID().uuidString) {
    self.projectID = projectID
    self.googleAppID = googleAppID
    self.apiKey = apiKey
    self.baseURL = baseURL
    self.session = session
    self.environment = environment
    generatedLocalDebugToken = localDebugToken
  }

  /// **[Experimental]** Returns the locally generated debug token.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: The locally generated UUID debug token string.
  public func localDebugToken() -> String {
    generatedLocalDebugToken
  }

  /// **[Experimental]** Returns the currently used App Check debug token.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// The debug token is resolved in the following priority order:
  /// 1. `AppCheckDebugToken` environment variable
  /// 2. `FIRAAppCheckDebugToken` environment variable
  /// 3. `APP_CHECK_DEBUG_TOKEN` environment variable
  /// 4. A locally generated UUID token (`localDebugToken()`)
  ///
  /// - Returns: The active debug token string.
  public func currentDebugToken() -> String {
    for key in ["AppCheckDebugToken", "FIRAAppCheckDebugToken", "APP_CHECK_DEBUG_TOKEN"] {
      if let value = environment[key], !value.isEmpty {
        return value
      }
    }
    return localDebugToken()
  }

  /// **[Experimental]** Exchanges the current debug token for a Firebase App Check token.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: A newly minted `AppCheckToken`.
  /// - Throws: An error in `AppCheckErrorDomain` if the token exchange fails.
  public func getToken() async throws -> AppCheckToken {
    try await exchangeDebugToken(limitedUse: false)
  }

  /// **[Experimental]** Exchanges the current debug token for a limited-use Firebase App Check
  /// token.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: A newly minted limited-use `AppCheckToken`.
  /// - Throws: An error in `AppCheckErrorDomain` if the token exchange fails.
  public func getLimitedUseToken() async throws -> AppCheckToken {
    try await exchangeDebugToken(limitedUse: true)
  }

  // MARK: - Private Helpers

  private func exchangeDebugToken(limitedUse: Bool) async throws -> AppCheckToken {
    let urlString = "\(baseURL)/projects/\(projectID)/apps/\(googleAppID):exchangeDebugToken"
    guard let endpointURL = URL(string: urlString) else {
      throw AppCheckErrorUtil.error(
        code: .invalidConfiguration,
        message: "Invalid App Check debug token exchange URL: \(urlString)"
      )
    }

    var request = URLRequest(url: endpointURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
    request.httpBody = try JSONEncoder().encode(
      ExchangeDebugTokenRequest(debugToken: currentDebugToken(), limitedUse: limitedUse)
    )

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw AppCheckErrorUtil.error(
        code: .serverUnreachable,
        message: "Failed to reach Firebase App Check server.",
        underlyingError: error
      )
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw AppCheckErrorUtil.error(
        code: .unknown,
        message: "Invalid non-HTTP response from Firebase App Check server."
      )
    }

    guard httpResponse.statusCode == 200 else {
      let bodyText = String(decoding: data, as: UTF8.self)
      throw AppCheckErrorUtil.error(
        code: .unknown,
        message: "Debug token exchange failed with HTTP status code " +
          "\(httpResponse.statusCode): \(bodyText)"
      )
    }

    let decoded: ExchangeDebugTokenResponse
    do {
      decoded = try JSONDecoder().decode(ExchangeDebugTokenResponse.self, from: data)
    } catch {
      throw AppCheckErrorUtil.error(
        code: .unknown,
        message: "Failed to decode Firebase App Check token response.",
        underlyingError: error
      )
    }

    let now = Date()
    let ttlSeconds = Self.parseTTLSeconds(decoded.ttl)
    return AppCheckToken(
      token: decoded.token,
      expirationDate: now.addingTimeInterval(ttlSeconds),
      receivedAtDate: now
    )
  }

  private static func parseTTLSeconds(_ ttl: String?) -> TimeInterval {
    guard let ttl else { return 3600 }
    let trimmed = ttl.trimmingCharacters(in: .whitespaces)
    if trimmed.hasSuffix("s") {
      let secondsString = trimmed.dropLast()
      if let value = TimeInterval(secondsString), value > 0 {
        return value
      }
      return 3600
    }
    if let value = TimeInterval(trimmed), value > 0 {
      return value
    }
    return 3600
  }
}

extension AppCheckDebugProvider {
  private struct ExchangeDebugTokenRequest: Encodable {
    let debugToken: String
    let limitedUse: Bool
  }

  private struct ExchangeDebugTokenResponse: Decodable {
    let token: String
    let ttl: String?
  }
}

/// **[Experimental]** An implementation of `AppCheckProviderFactory` that creates a new instance
/// of `AppCheckDebugProvider` when requested.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class AppCheckDebugProviderFactory: AppCheckProviderFactory, Sendable {
  /// **[Experimental]** Creates a new `AppCheckDebugProviderFactory`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public init() {}

  /// **[Experimental]** Creates an `AppCheckDebugProvider` for the specified `FirebaseApp`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter app: The `FirebaseApp` to create the debug provider for.
  /// - Returns: A new `AppCheckDebugProvider` instance, or `nil` if required options are missing.
  public func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
    AppCheckDebugProvider(app: app)
  }
}
