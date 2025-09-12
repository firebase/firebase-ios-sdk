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

import FirebaseCoreInternal
import Foundation

private let kFiveMinutes = 5 * 60.0

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
actor SecureTokenServiceInternal {
  /// Fetch a fresh ephemeral access token for the ID associated with this instance. The token
  ///   received in the callback should be considered short lived and not cached.
  ///
  ///    Invoked asynchronously on the auth global work queue in the future.
  /// - Parameter forceRefresh: Forces the token to be refreshed.
  /// - Returns : A tuple with the token and flag of whether it was updated.
  func fetchAccessToken(forcingRefresh forceRefresh: Bool,
                        service: SecureTokenService,
                        backend: AuthBackend) async throws -> (String?, Bool) {
    if !forceRefresh, hasValidAccessToken(service: service) {
      return (service.accessToken, false)
    } else {
      AuthLog.logDebug(code: "I-AUT000017", message: "Fetching new token from backend.")
      return try await requestAccessToken(retryIfExpired: true, service: service, backend: backend)
    }
  }

  /// Makes a request to STS for an access token.
  ///
  /// This handles both the case that the token has not been granted yet and that it just needs
  /// needs to be refreshed.
  ///
  /// - Returns: Token and Bool indicating if update occurred.
  private func requestAccessToken(retryIfExpired: Bool,
                                  service: SecureTokenService,
                                  backend: AuthBackend) async throws -> (String?, Bool) {
    // TODO: This was a crash in ObjC SDK, should it callback with an error?
    guard let refreshToken = service.refreshToken,
          let requestConfiguration = service.requestConfiguration else {
      fatalError("refreshToken and requestConfiguration should not be nil")
    }

    let request = SecureTokenRequest.refreshRequest(refreshToken: refreshToken,
                                                    requestConfiguration: requestConfiguration)
    let response = try await backend.call(with: request)
    var tokenUpdated = false
    if let newAccessToken = response.accessToken,
       newAccessToken.count > 0,
       newAccessToken != service.accessToken {
      if let tokenResult = try? AuthTokenResult.tokenResult(token: newAccessToken) {
        // There is an edge case where the request for a new access token may be made right
        // before the app goes inactive, resulting in the callback being invoked much later
        // with an expired access token. This does not fully solve the issue, as if the
        // callback is invoked less than an hour after the request is made, a token is not
        // re-requested here but the approximateExpirationDate will still be off since that
        // is computed at the time the token is received.
        if retryIfExpired {
          let expirationDate = tokenResult.expirationDate
          if expirationDate.timeIntervalSinceNow <= kFiveMinutes {
            // We only retry once, to avoid an infinite loop in the case that an end-user has
            // their local time skewed by over an hour.
            return try await requestAccessToken(
              retryIfExpired: false,
              service: service,
              backend: backend
            )
          }
        }
      }
      service.accessToken = newAccessToken
      service.accessTokenExpirationDate = response.approximateExpirationDate
      tokenUpdated = true
      AuthLog.logDebug(
        code: "I-AUT000017",
        message: "Updated access token. Estimated expiration date: " +
          "\(String(describing: service.accessTokenExpirationDate)), current date: \(Date())"
      )
    }
    if let newRefreshToken = response.refreshToken,
       newRefreshToken != service.refreshToken {
      service.refreshToken = newRefreshToken
      tokenUpdated = true
    }
    return (response.accessToken, tokenUpdated)
  }

  private func hasValidAccessToken(service: SecureTokenService) -> Bool {
    if let accessTokenExpirationDate = service.accessTokenExpirationDate,
       accessTokenExpirationDate.timeIntervalSinceNow > kFiveMinutes {
      AuthLog.logDebug(code: "I-AUT000017",
                       message: "Has valid access token. Estimated expiration date:" +
                         "\(accessTokenExpirationDate), current date: \(Date())")
      return true
    }
    AuthLog.logDebug(
      code: "I-AUT000017",
      message: "Does not have valid access token. Estimated expiration date:" +
        "\(String(describing: service.accessTokenExpirationDate)), current date: \(Date())"
    )
    return false
  }
}

/// A class represents a credential that proves the identity of the app.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRSecureTokenService) // objc Needed for decoding old versions
final class SecureTokenService: NSObject, NSSecureCoding, Sendable {
  /// Internal actor to enforce serialization
  private let internalService: SecureTokenServiceInternal

  /// The configuration for making requests to server.
  var requestConfiguration: AuthRequestConfiguration? {
    get { _requestConfiguration.withLock { $0 } }
    set { _requestConfiguration.withLock { $0 = newValue } }
  }

  let _requestConfiguration: UnfairLock<AuthRequestConfiguration?>

  /// The cached access token.
  ///
  /// This method is specifically for providing the access token to internal clients during
  /// deserialization and sign-in events, and should not be used to retrieve the access token by
  /// anyone else.
  ///
  /// - Note: The atomic wrapper can be removed when the SDK is fully
  /// synchronized with structured concurrency.
  var accessToken: String {
    get { _accessToken.withLock { $0 } }
    set { _accessToken.withLock { $0 = newValue } }
  }

  private let _accessToken: UnfairLock<String>

  /// The refresh token for the user, or `nil` if the user has yet completed sign-in flow.
  ///
  /// This property needs to be set manually after the instance is decoded from archive.
  var refreshToken: String? {
    get { _refreshToken.withLock { $0 } }
    set { _refreshToken.withLock { $0 = newValue } }
  }

  private let _refreshToken: UnfairLock<String?>

  /// The expiration date of the cached access token.
  var accessTokenExpirationDate: Date? {
    get { _accessTokenExpirationDate.withLock { $0 } }
    set { _accessTokenExpirationDate.withLock { $0 = newValue } }
  }

  private let _accessTokenExpirationDate: UnfairLock<Date?>

  /// Creates a `SecureTokenService` with access and refresh tokens.
  /// - Parameter requestConfiguration: The configuration for making requests to server.
  /// - Parameter accessToken: The STS access token.
  /// - Parameter accessTokenExpirationDate: The approximate expiration date of the access token.
  /// - Parameter refreshToken: The STS refresh token.
  init(withRequestConfiguration requestConfiguration: AuthRequestConfiguration?,
       accessToken: String,
       accessTokenExpirationDate: Date?,
       refreshToken: String) {
    internalService = SecureTokenServiceInternal()
    _requestConfiguration = UnfairLock(requestConfiguration)
    _accessToken = UnfairLock(accessToken)
    _accessTokenExpirationDate = UnfairLock(accessTokenExpirationDate)
    _refreshToken = UnfairLock(refreshToken)
  }

  /// Fetch a fresh ephemeral access token for the ID associated with this instance. The token
  ///   received in the callback should be considered short lived and not cached.
  ///
  ///    Invoked asynchronously on the auth global work queue in the future.
  /// - Parameter forceRefresh: Forces the token to be refreshed.
  /// - Returns : A tuple with the token and flag of whether it was updated.
  func fetchAccessToken(forcingRefresh forceRefresh: Bool,
                        backend: AuthBackend) async throws -> (String?, Bool) {
    return try await internalService
      .fetchAccessToken(forcingRefresh: forceRefresh, service: self, backend: backend)
  }

  // MARK: NSSecureCoding

  // Secure coding keys
  private let kAPIKeyCodingKey = "APIKey"
  private static let kRefreshTokenKey = "refreshToken"
  private static let kAccessTokenKey = "accessToken"
  private static let kAccessTokenExpirationDateKey = "accessTokenExpirationDate"

  static let supportsSecureCoding = true

  required convenience init?(coder: NSCoder) {
    guard let refreshToken = coder.decodeObject(of: [NSString.self],
                                                forKey: Self.kRefreshTokenKey) as? String,
      let accessToken = coder.decodeObject(of: [NSString.self],
                                           forKey: Self.kAccessTokenKey) as? String else {
      return nil
    }
    let accessTokenExpirationDate = coder.decodeObject(
      of: [NSDate.self], forKey: Self.kAccessTokenExpirationDateKey
    ) as? Date
    // requestConfiguration is filled in after User is set by Auth.protectedDataInitialization.
    self.init(withRequestConfiguration: nil,
              accessToken: accessToken,
              accessTokenExpirationDate: accessTokenExpirationDate,
              refreshToken: refreshToken)
  }

  func encode(with coder: NSCoder) {
    // The API key is encoded even it is not used in decoding to be compatible with previous
    // versions of the library.
    coder.encode(requestConfiguration?.apiKey, forKey: kAPIKeyCodingKey)
    // Authorization code is not encoded because it is not long-lived.
    coder.encode(refreshToken, forKey: SecureTokenService.kRefreshTokenKey)
    coder.encode(accessToken, forKey: SecureTokenService.kAccessTokenKey)
    coder.encode(
      accessTokenExpirationDate,
      forKey: SecureTokenService.kAccessTokenExpirationDateKey
    )
  }
}
