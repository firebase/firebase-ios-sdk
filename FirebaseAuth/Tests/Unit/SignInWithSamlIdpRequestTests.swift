// Copyright 2025 Google LLC
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

@testable import FirebaseAuth
import FirebaseCore
import XCTest

final class SignInWithSamlIdpRequestTests: XCTestCase {
  let kAPIKey = "TEST_API_KEY"
  let kAppID = "FAKE_APP_ID"
  let kRequestUri = "https://example.web.app/sp-acs-url"
  let kPostBody = "SAMLResponse=BASE64%2BSAFE&providerId=saml.provider"
  let kComplexUri = "https://host/acs;param?p1=v1&p2=v2#frag"
  let kRawPostBody =
    "SAMLResponse=someResponse&providerId=saml.provider"

  var configuration: AuthRequestConfiguration!

  override func setUp() {
    super.setUp()
    configuration = AuthRequestConfiguration(apiKey: kAPIKey, appID: kAppID)
  }

  override func tearDown() {
    configuration = nil
    super.tearDown()
  }

  func testRequestURLIsCorrectlyConstructed() {
    let request = SignInWithSamlIdpRequest(
      requestUri: kRequestUri,
      postBody: kPostBody,
      returnSecureToken: true,
      requestConfiguration: configuration
    )

    let url = request.requestURL()
    XCTAssertEqual(url.scheme, "https")
    XCTAssertEqual(url.host, "identitytoolkit.googleapis.com")
    XCTAssertEqual(url.path, "/v1/accounts:signInWithIdp")

    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    XCTAssertEqual(components?.queryItems?.count, 1)
    XCTAssertEqual(components?.queryItems?.first?.name, "key")
    XCTAssertEqual(components?.queryItems?.first?.value, kAPIKey)
  }

  func testRequestConfigurationIsPassedThrough() {
    let request = SignInWithSamlIdpRequest(
      requestUri: kRequestUri,
      postBody: kPostBody,
      returnSecureToken: false,
      requestConfiguration: configuration
    )

    let returned = request.requestConfiguration()
    XCTAssertEqual(returned.apiKey, kAPIKey)
    XCTAssertIdentical(returned.auth, configuration.auth)
  }

  func testUnencodedHTTPRequestBodyContainsExpectedKeysAndValues() {
    let request = SignInWithSamlIdpRequest(
      requestUri: kRequestUri,
      postBody: kPostBody,
      returnSecureToken: true,
      requestConfiguration: configuration
    )

    guard let body = request.unencodedHTTPRequestBody else {
      XCTFail("Body must not be nil")
      return
    }

    XCTAssertEqual(body.count, 3)
    XCTAssertEqual(body["requestUri"] as? String, kRequestUri)
    XCTAssertEqual(body["postBody"] as? String, kPostBody)
    XCTAssertEqual(body["returnSecureToken"] as? Bool, true)
  }

  func testUnencodedHTTPRequestBodyReflectsReturnSecureTokenFalse() {
    let request = SignInWithSamlIdpRequest(
      requestUri: kRequestUri,
      postBody: kPostBody,
      returnSecureToken: false,
      requestConfiguration: configuration
    )

    let body = request.unencodedHTTPRequestBody
    XCTAssertEqual(body?["returnSecureToken"] as? Bool, false)
  }

  func testUnencodedHTTPRequestBodyPreservesPostBodyVerbatim() {
    let request = SignInWithSamlIdpRequest(
      requestUri: kRequestUri,
      postBody: kRawPostBody,
      returnSecureToken: true,
      requestConfiguration: configuration
    )

    let body = request.unencodedHTTPRequestBody
    XCTAssertEqual(body?["postBody"] as? String, kRawPostBody)
  }

  func testUnencodedHTTPRequestBodyAllowsComplexRequestUri() {
    let request = SignInWithSamlIdpRequest(
      requestUri: kComplexUri,
      postBody: kPostBody,
      returnSecureToken: true,
      requestConfiguration: configuration
    )

    let body = request.unencodedHTTPRequestBody
    XCTAssertEqual(body?["requestUri"] as? String, kComplexUri)
  }

  func testRepeatedCallsDoNotMutateURLOrBody() {
    let request = SignInWithSamlIdpRequest(
      requestUri: kRequestUri,
      postBody: kPostBody,
      returnSecureToken: true,
      requestConfiguration: configuration
    )

    let url1 = request.requestURL()
    let body1 = request.unencodedHTTPRequestBody

    let url2 = request.requestURL()
    let body2 = request.unencodedHTTPRequestBody

    XCTAssertEqual(url1, url2)
    XCTAssertEqual(body1?["requestUri"] as? String, body2?["requestUri"] as? String)
    XCTAssertEqual(body1?["postBody"] as? String, body2?["postBody"] as? String)
    XCTAssertEqual(body1?["returnSecureToken"] as? Bool, body2?["returnSecureToken"] as? Bool)
  }
}
