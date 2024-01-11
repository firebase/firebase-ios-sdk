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

/** @class FIRAuthTokenResult
    @brief A data class containing the ID token JWT string and other properties associated with the
    token including the decoded payload claims.
 */
@objc(FIRAuthTokenResult) open class AuthTokenResult: NSObject {
  /** @property token
      @brief Stores the JWT string of the ID token.
   */
  @objc open var token: String

  /** @property expirationDate
      @brief Stores the ID token's expiration date.
   */
  @objc open var expirationDate: Date

  /** @property authDate
      @brief Stores the ID token's authentication date.
      @remarks This is the date the user was signed in and NOT the date the token was refreshed.
   */
  @objc open var authDate: Date

  /** @property issuedAtDate
      @brief Stores the date that the ID token was issued.
      @remarks This is the date last refreshed and NOT the last authentication date.
   */
  @objc open var issuedAtDate: Date

  /** @property signInProvider
      @brief Stores sign-in provider through which the token was obtained.
      @remarks This does not necessarily map to provider IDs.
   */
  @objc open var signInProvider: String

  /** @property signInSecondFactor
      @brief Stores sign-in second factor through which the token was obtained.
   */
  @objc open var signInSecondFactor: String

  /** @property claims
      @brief Stores the entire payload of claims found on the ID token. This includes the standard
          reserved claims as well as custom claims set by the developer via the Admin SDK.
   */
  @objc open var claims: [String: Any]

  /** @fn tokenResultWithToken:
       @brief Parse a token string to a structured token.
       @param token The token string to parse.
       @return A structured token result.
   */
  @objc open class func tokenResult(token: String) -> AuthTokenResult? {
    let tokenStringArray = token.components(separatedBy: ".")

    // The JWT should have three parts, though we only use the second in this method.
    if tokenStringArray.count != 3 {
      return nil
    }

    // The token payload is always the second index of the array.
    let IDToken = tokenStringArray[1]

    // Convert the base64URL encoded string to a base64 encoded string.
    // Replace "_" with "/"
    // Replace "-" with "+"
    var tokenPayload = IDToken.replacingOccurrences(of: "_", with: "/")
      .replacingOccurrences(of: "-", with: "+")

    // Pad the token payload with "=" signs if the payload's length is not a multiple of 4.
    if tokenPayload.count % 4 != 0 {
      let length = tokenPayload.count + (4 - tokenPayload.count % 4)
      tokenPayload = tokenPayload.padding(toLength: length, withPad: "=", startingAt: 0)
    }

    guard let decodedTokenPayloadData = Data(
      base64Encoded: tokenPayload,
      options: [.ignoreUnknownCharacters]
    ) else {
      return nil
    }
    guard let tokenPayloadDictionary = try? JSONSerialization.jsonObject(
      with: decodedTokenPayloadData,
      options: [.mutableContainers, .allowFragments]
    ) as? [String: Any] else {
      return nil
    }
    // These are dates since 00:00:00 January 1 1970, as described by the Terminology section in
    // the JWT spec. https://tools.ietf.org/html/rfc7519
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    guard let jwt = try? decoder.decode(JWT.self, from: decodedTokenPayloadData) else {
      return nil
    }

    let tokenResult = AuthTokenResult(token: token,
                                      expirationDate: jwt.exp,
                                      authDate: jwt.authTime,
                                      issuedAtDate: jwt.iat,
                                      signInProvider: jwt.firebase.signInProvider,
                                      signInSecondFactor: jwt.firebase.signInSecondFactor,
                                      claims: tokenPayloadDictionary)
    return tokenResult
  }

  init(token: String,
       expirationDate: Date,
       authDate: Date,
       issuedAtDate: Date,
       signInProvider: String,
       signInSecondFactor: String?,
       claims: [String: Any]) {
    self.token = token
    self.expirationDate = expirationDate
    self.authDate = authDate
    self.issuedAtDate = issuedAtDate
    self.signInProvider = signInProvider
    self.signInSecondFactor = signInSecondFactor ?? ""
    self.claims = claims
  }
}

struct JWT: Decodable {
  struct FirebasePayload: Decodable {
    let signInProvider: String
    let signInSecondFactor: String?
  }

  let exp: Date
  let authTime: Date
  let iat: Date
  let firebase: FirebasePayload
}
