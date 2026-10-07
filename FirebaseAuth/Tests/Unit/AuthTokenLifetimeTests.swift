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
import XCTest

@testable import FirebaseAuth

/// The responses that carry an `expiresIn` token lifetime: sign-in, link, and update responses.
private protocol ExpiresInResponse: AuthRPCResponse {
  var approximateExpirationDate: Date? { get }
}

extension VerifyPasswordResponse: ExpiresInResponse {}
extension SignUpNewUserResponse: ExpiresInResponse {}
extension VerifyAssertionResponse: ExpiresInResponse {}
extension VerifyCustomTokenResponse: ExpiresInResponse {}
extension EmailLinkSignInResponse: ExpiresInResponse {}
extension VerifyPhoneNumberResponse: ExpiresInResponse {}
extension SignInWithGameCenterResponse: ExpiresInResponse {}
extension SetAccountInfoResponse: ExpiresInResponse {}

/// Tests the bounds on the token lifetimes from the backend, and on saved access token expiration
/// dates.
///
/// A huge or infinite lifetime used to be saved to the keychain with the user, and then crash the
/// automatic token refresh at every launch. These tests use the response and coding entry points,
/// so they show the failures without the bounds too.
class AuthTokenLifetimeTests: XCTestCase {
  private let kAccessToken = "ACCESS_TOKEN"
  private let kRefreshToken = "REFRESH_TOKEN"

  /// Token lifetimes from the backend, and the lifetimes that the responses should use.
  private let lifetimes: [(expiresIn: String, expected: TimeInterval)] = [
    // Lifetimes in (0, 24 h] are used, parsed as before.
    ("3600", 3600),
    ("3599.5", 3599.5),
    (" 3600", 3600),
    ("+3600", 3600),
    ("300", 300),
    ("120", 120),
    ("86400", 86400),
    // Other lifetimes fall back to the standard one-hour lifetime.
    ("1e400", 3600), // Parses as infinity.
    ("1e19", 3600), // Too large to convert to `Int` when the refresh is scheduled.
    ("86401", 3600), // More than 24 hours.
    ("86400.5", 3600),
    ("0", 3600),
    ("-5", 3600),
    ("nan", 3600), // `NSString.doubleValue` parses this and the following strings as 0.
    ("inf", 3600),
    ("abc", 3600),
    ("", 3600),
  ]

  private let expiresInResponseTypes: [any ExpiresInResponse.Type] = [
    VerifyPasswordResponse.self,
    SignUpNewUserResponse.self,
    VerifyAssertionResponse.self,
    VerifyCustomTokenResponse.self,
    EmailLinkSignInResponse.self,
    VerifyPhoneNumberResponse.self,
    SignInWithGameCenterResponse.self,
    SetAccountInfoResponse.self,
  ]

  func testSecureTokenResponseBoundsLifetime() throws {
    for (expiresIn, expected) in lifetimes {
      let response = try SecureTokenResponse(dictionary: ["access_token": kAccessToken,
                                                          "expires_in": expiresIn])
      let expirationDate = try XCTUnwrap(response.approximateExpirationDate, expiresIn)
      XCTAssertEqual(expirationDate.timeIntervalSinceNow, expected, accuracy: 1, expiresIn)
    }
  }

  func testSecureTokenResponseWithoutLifetime() throws {
    let response = try SecureTokenResponse(dictionary: ["access_token": kAccessToken])
    XCTAssertNil(response.approximateExpirationDate)
  }

  func testExpiresInResponsesBoundLifetime() throws {
    for responseType in expiresInResponseTypes {
      for (expiresIn, expected) in lifetimes {
        let message = "\(responseType), expiresIn: \(expiresIn)"
        let response = try responseType.init(dictionary: ["expiresIn": expiresIn])
        let expirationDate = try XCTUnwrap(response.approximateExpirationDate, message)
        XCTAssertEqual(expirationDate.timeIntervalSinceNow, expected, accuracy: 1, message)
      }
    }
  }

  func testExpiresInResponsesWithoutLifetime() throws {
    for responseType in expiresInResponseTypes {
      let response = try responseType.init(dictionary: [:])
      XCTAssertNil(response.approximateExpirationDate, "\(responseType)")
    }
  }

  func testDecodingDropsOutOfRangeExpirationDates() throws {
    let expirationDates = [
      Date(timeIntervalSinceNow: .infinity),
      // Defense in depth: no lifetime from the backend parses as NaN.
      Date(timeIntervalSinceReferenceDate: .nan),
      Date(timeIntervalSinceNow: 1e19),
      Date(timeIntervalSinceNow: 2 * 24 * 60 * 60),
    ]
    for expirationDate in expirationDates {
      let message = "Expires in: \(expirationDate.timeIntervalSinceNow)"
      let tokenService = try archiveAndUnarchive(makeTokenService(expirationDate: expirationDate))
      XCTAssertNil(tokenService.accessTokenExpirationDate, message)
      XCTAssertEqual(tokenService.accessToken, kAccessToken, message)
      XCTAssertEqual(tokenService.refreshToken, kRefreshToken, message)
    }
  }

  func testDecodingKeepsInRangeExpirationDates() throws {
    // A date in the past is kept: the token has expired.
    for lifetime: TimeInterval in [30 * 60, 23 * 60 * 60, -60] {
      let expirationDate = Date(timeIntervalSinceNow: lifetime)
      let tokenService = try archiveAndUnarchive(makeTokenService(expirationDate: expirationDate))
      let decodedDate = try XCTUnwrap(tokenService.accessTokenExpirationDate, "\(lifetime)")
      XCTAssertEqual(decodedDate.timeIntervalSinceNow, lifetime, accuracy: 1, "\(lifetime)")
    }
  }

  private func makeTokenService(expirationDate: Date) -> SecureTokenService {
    return SecureTokenService(withRequestConfiguration: nil,
                              accessToken: kAccessToken,
                              accessTokenExpirationDate: expirationDate,
                              refreshToken: kRefreshToken)
  }

  /// Archives and unarchives a token service with secure coding, as `Auth` does when it saves the
  /// user to the keychain and loads it at launch.
  private func archiveAndUnarchive(_ tokenService: SecureTokenService) throws
    -> SecureTokenService {
    let archiver = NSKeyedArchiver(requiringSecureCoding: true)
    archiver.encode(tokenService, forKey: "tokenService")
    archiver.finishEncoding()
    let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
    return try XCTUnwrap(unarchiver.decodeObject(of: SecureTokenService.self,
                                                 forKey: "tokenService"))
  }
}
