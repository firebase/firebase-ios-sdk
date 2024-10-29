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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
extension AuthTokenResult: NSSecureCoding {}

/// A data class containing the ID token JWT string and other properties associated with the
/// token including the decoded payload claims.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRAuthTokenResult) open class AuthTokenResult: NSObject {
  /// Stores the JWT string of the ID token.
  @objc open var token: String

  /// Stores the ID token's expiration date.
  @objc open var expirationDate: Date

  /// Stores the ID token's authentication date.
  ///
  /// This is the date the user was signed in and NOT the date the token was refreshed.
  @objc open var authDate: Date

  /// Stores the date that the ID token was issued.
  ///
  /// This is the date last refreshed and NOT the last authentication date.
  @objc open var issuedAtDate: Date

  /// Stores sign-in provider through which the token was obtained.
  @objc open var signInProvider: String

  /// Stores sign-in second factor through which the token was obtained.
  @objc open var signInSecondFactor: String

  /// Stores the entire payload of claims found on the ID token.
  ///
  /// This includes the standard
  /// reserved claims as well as custom claims set by the developer via the Admin SDK.
  @objc open var claims: [String: Any]

  private class func getTokenPayloadData(_ token: String) throws -> Data {
    let tokenStringArray = token.components(separatedBy: ".")

    // The JWT should have three parts, though we only use the second in this method.
    if tokenStringArray.count != 3 {
      throw AuthErrorUtils.malformedJWTError(token: token, underlyingError: nil)
    }

    /// The token payload is always the second index of the array.
    let IDToken = tokenStringArray[1]

    /// Convert the base64URL encoded string to a base64 encoded string.
    /// * Replace "_" with "/"
    /// * Replace "-" with "+"
    var tokenPayload = IDToken.replacingOccurrences(of: "_", with: "/")
      .replacingOccurrences(of: "-", with: "+")

    // Pad the token payload with "=" signs if the payload's length is not a multiple of 4.
    if tokenPayload.count % 4 != 0 {
      let length = tokenPayload.count + (4 - tokenPayload.count % 4)
      tokenPayload = tokenPayload.padding(toLength: length, withPad: "=", startingAt: 0)
    }
    guard let data = Data(base64Encoded: tokenPayload, options: [.ignoreUnknownCharacters]) else {
      throw AuthErrorUtils.malformedJWTError(token: token, underlyingError: nil)
    }
    return data
  }

  private class func getTokenPayloadDictionary(_ token: String,
                                               _ payloadData: Data) throws -> [String: Any] {
    do {
      if let dictionary = try JSONSerialization.jsonObject(
        with: payloadData,
        options: [.mutableContainers, .allowFragments]
      ) as? [String: Any] {
        return dictionary
      } else {
        return [:]
      }
    } catch {
      throw AuthErrorUtils.malformedJWTError(token: token, underlyingError: error)
    }
  }

  private class func getJWT(_ token: String, _ payloadData: Data) throws -> JWT {
    // These are dates since 00:00:00 January 1 1970, as described by the Terminology section in
    // the JWT spec. https://tools.ietf.org/html/rfc7519
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    guard let jwt = try? decoder.decode(JWT.self, from: payloadData) else {
      throw AuthErrorUtils.malformedJWTError(token: token, underlyingError: nil)
    }
    return jwt
  }

  /// Parse a token string to a structured token.
  /// - Parameter token: The token string to parse.
  /// - Returns: A structured token result.
  class func tokenResult(token: String) throws -> AuthTokenResult {
    let payloadData = try getTokenPayloadData(token)
    let claims = try getTokenPayloadDictionary(token, payloadData)
    let jwt = try getJWT(token, payloadData)
    return AuthTokenResult(token: token, jwt: jwt, claims: claims)
  }

  private init(token: String, jwt: JWT, claims: [String: Any]) {
    self.token = token
    expirationDate = jwt.exp
    authDate = jwt.authTime
    issuedAtDate = jwt.iat
    signInProvider = jwt.firebase.signInProvider
    signInSecondFactor = jwt.firebase.signInSecondFactor ?? ""
    self.claims = claims
  }

  // MARK: Secure Coding

  private static let kTokenKey = "token"

  public static let supportsSecureCoding = true

  public func encode(with coder: NSCoder) {
    coder.encode(token, forKey: AuthTokenResult.kTokenKey)
  }

  public required convenience init?(coder: NSCoder) {
    guard let token = coder.decodeObject(
      of: [NSString.self],
      forKey: AuthTokenResult.kTokenKey
    ) as? String else {
      return nil
    }
    guard let payloadData = try? AuthTokenResult.getTokenPayloadData(token),
          let claims = try? AuthTokenResult.getTokenPayloadDictionary(token, payloadData),
          let jwt = try? AuthTokenResult.getJWT(token, payloadData) else {
      return nil
    }
    self.init(token: token, jwt: jwt, claims: claims)
  }
}

private struct JWT: Decodable {
  struct FirebasePayload: Decodable {
    let signInProvider: String
    let signInSecondFactor: String?
  }

  let exp: Date
  let authTime: Date
  let iat: Date
  let firebase: FirebasePayload
}
