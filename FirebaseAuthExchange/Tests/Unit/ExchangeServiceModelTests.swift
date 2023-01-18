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

  let jsonDecoder = JSONDecoder()

  // MARK: - Request Model Encoding Tests

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

    XCTAssertEqual(json, expectedJSON)
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

    XCTAssertEqual(json, expectedJSON)
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

    XCTAssertEqual(json, expectedJSON)
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

    XCTAssertEqual(json, expectedJSON)
  }

  private func encodeAsJSON(_ entity: Encodable) throws -> String {
    let data = try jsonEncoder.encode(entity)
    return String(data: data, encoding: .utf8)!
  }

  // MARK: - Response Model Decoding Tests

  func testDecodeExchangeTokenResponse() throws {
    let accessToken = "test-access-token"
    let timeToLiveSeconds: Int64 = 3
    let timeToLiveNanos: Int32 = 141_592_653
    let timeToLive = "\(timeToLiveSeconds).\(timeToLiveNanos)s"
    let responseJSON = """
    {
      "token": {
        "accessToken": "\(accessToken)",
        "ttl": "\(timeToLive)"
      }
    }
    """
    let expectedResponse = ExchangeTokenResponse(token: ExchangeTokenResponse.AuthExchangeToken(
      accessToken: accessToken,
      timeToLive: try ProtobufDuration(json: timeToLive)
    ))

    let response = try jsonDecoder.decode(ExchangeTokenResponse.self, from: responseJSON)

    XCTAssertEqual(response.token.timeToLive.seconds, timeToLiveSeconds)
    XCTAssertEqual(response.token.timeToLive.nanoseconds, timeToLiveNanos)
    XCTAssertEqual(response, expectedResponse)
  }
}

private extension JSONDecoder {
  func decode<T>(_ type: T.Type, from string: String) throws -> T where T: Decodable {
    let data: Data = string.data(using: .utf8)!
    return try decode(T.self, from: data)
  }
}
