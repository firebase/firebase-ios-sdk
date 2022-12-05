// Copyright 2022 Google LLC
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

import XCTest
@testable import FirebaseAuthExchange

final class ModelTests: XCTestCase {
  let jsonEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = [.prettyPrinted,
                                // Ensure ordering is consistent for JSON string comparison
                                .sortedKeys]
    return encoder
  }()

  func testEncodeExchangeInstallationAuthTokenRequest() throws {
    let installationAuthToken = "test-installation-token"
    let request = ExchangeInstallationAuthTokenRequest(
      installationAuthToken: installationAuthToken
    )
    let expectedJSON = """
    {
      "installation_auth_token" : "\(installationAuthToken)"
    }
    """

    let json = try encodeAsJSON(request)

    XCTAssertEqual(expectedJSON, json)
  }

  func testEncodeExchangeCustomTokenRequest() throws {
    let customToken = "test-custom-jwt"
    let request = ExchangeCustomTokenRequest(
      customToken: customToken
    )
    let expectedJSON = """
    {
      "custom_token" : "\(customToken)"
    }
    """

    let json = try encodeAsJSON(request)

    XCTAssertEqual(expectedJSON, json)
  }

  func testEncodeExchangeOidcTokenRequestWithImplicitCredentials() throws {
    let providerID = "test-provider-id"
    let idToken = "test-id-token"
    let credentials = ExchangeOIDCTokenRequest.ImplicitCredentials(idToken: idToken)
    let request = ExchangeOIDCTokenRequest(providerID: providerID, implicitCredentials: credentials)
    let expectedJSON = """
    {
      "implicit_credentials" : {
        "id_token" : "\(idToken)"
      },
      "provider_id" : "\(providerID)"
    }
    """

    let json = try encodeAsJSON(request)

    XCTAssertEqual(expectedJSON, json)
  }

  func testEncodeExchangeOidcTokenRequestWithAuthCodeCredentials() throws {
    let providerID = "test-provider-id"
    let sessionID = "test-session-id"
    let credentialURI = "test-credential-uri"
    let credentials = ExchangeOIDCTokenRequest.AuthCodeCredentials(
      sessionID: sessionID,
      credentialURI: credentialURI
    )
    let request = ExchangeOIDCTokenRequest(providerID: providerID, authCodeCredentials: credentials)
    let expectedJSON = """
    {
      "auth_code_credentials" : {
        "credential_uri" : "\(credentialURI)",
        "session_id" : "\(sessionID)"
      },
      "provider_id" : "\(providerID)"
    }
    """

    let json = try encodeAsJSON(request)

    XCTAssertEqual(expectedJSON, json)
  }

  private func encodeAsJSON(_ entity: Encodable) throws -> String {
    let data = try jsonEncoder.encode(entity)
    return String(data: data, encoding: .utf8)!
  }
}
