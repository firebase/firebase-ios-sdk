// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License")
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

import FirebaseCore
@testable import FirebaseAuth

#if os(iOS)

class OAuthProviderTests: RPCBaseTests {
  private let kFakeAuthorizedDomain = "test.firebaseapp.com"
  private let kFakeBundleID = "com.firebaseapp.example"
  private let kFakeAccessToken = "fakeAccessToken"
  private let kFakeIDToken = "fakeIDToken"
  private let kFakeProviderID = "fakeProviderID"
  private let kFakeAPIKey = "asdfghjkl"
  private let kFakeEmulatorHost = "emulatorhost"
  private let kFakeEmulatorPort = "12345"
  private let kFakeClientID = "123456.apps.googleusercontent.com"
  private let kFakeReverseClientID = "com.googleusercontent.apps.123456"
  private let kFakeFirebaseAppID = "1:123456789:ios:123abc456def"
  private let kFakeEncodedFirebaseAppID = "app-1-123456789-ios-123abc456def"
  private let kFakeTenantID = "tenantID"
  private let kFakeOAuthResponseURL = "fakeOAuthResponseURL"
//  private let kFakeRedirectURLResponseURL
//  private let kFakeRedirectURLBaseErrorString
//  private let kNetworkRequestFailedErrorString
//  private let kInvalidClientIDString
//  private let kInternalErrorString
//  private let kUnknownErrorString

  static let kFakeAPIKey = "FAKE_API_KEY"
  static var auth: Auth?

  override class func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.apiKey = kFakeAPIKey
    options.projectID = "myProjectID"
    FirebaseApp.configure(name: "test-AuthTests", options: options)
    auth = Auth.auth(app: FirebaseApp.app(name: "test-AuthTests")!)
  }

  /** @fn testObtainingOAuthCredentialNoIDToken
      @brief Tests the correct creation of an OAuthCredential without an IDToken.
   */
  func testObtainingOAuthCredentialNoIDToken() throws {
    let credential = OAuthProvider.credential(withProviderID: kFakeProviderID,
                                              accessToken: kFakeAccessToken)
    XCTAssertEqual(credential.accessToken, kFakeAccessToken)
    XCTAssertEqual(credential.provider, kFakeProviderID)
    XCTAssertNil(credential.IDToken)
  }

  /** @fn testObtainingOAuthCredentialWithIDToken
      @brief Tests the correct creation of an OAuthCredential with an IDToken
   */
  func testObtainingOAuthCredentialWithIDToken() throws {
    let credential = OAuthProvider.credential(withProviderID: kFakeProviderID,
                                              idToken: kFakeIDToken,
                                              accessToken: kFakeAccessToken)
    XCTAssertEqual(credential.accessToken, kFakeAccessToken)
    XCTAssertEqual(credential.provider, kFakeProviderID)
    XCTAssertEqual(credential.IDToken, kFakeIDToken)
  }

  /** @fn testObtainingOAuthProvider
      @brief Tests the correct creation of an FIROAuthProvider instance.
   */
  func testObtainingOAuthProvider() throws {
    let provider = OAuthProvider(providerID: kFakeProviderID, auth: OAuthProviderTests.auth!)
    XCTAssertEqual(provider.providerID, kFakeProviderID)
  }

  private class FakeUIDelegate: NSObject, AuthUIDelegate {
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
     // completion?()
      viewControllerToPresent.dismiss(animated: flag, completion: completion)
      //self.dismiss(animated: flag, completion: completion)
      viewControllerToPresent.
    }
    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
      XCTFail("got to dismiss")
    }
  }

  /** @fn testGetCredentialWithUIDelegateWithClientID
      @brief Tests a successful invocation of @c getCredentialWithUIDelegate
   */
  func testGetCredentialWithUIDelegateWithClientID() throws {
    let expectation = self.expectation(description: #function)
    let provider = OAuthProvider(providerID: kFakeProviderID, auth: OAuthProviderTests.auth!)

    // 1. Create a group to synchronize request creation by the fake RPCIssuer in `fetchSignInMethods`.
    let group = DispatchGroup()
    RPCIssuer?.group = group
    group.enter()

    provider.getCredentialWith(FakeUIDelegate()) { credential, error in
      // 4. After the response triggers the callback, verify the values in the callback credential
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      let oAuthCredential = credential as? OAuthCredential
      XCTAssertEqual(oAuthCredential?.OAuthResponseURLString, self.kFakeOAuthResponseURL)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake RPCIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(RPCIssuer?.request as? GetProjectConfigRequest)
    XCTAssertEqual(request.endpoint, "getProjectConfig")
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    _ = try RPCIssuer?.respond(withJSON: ["authorizedDomains": [kFakeAuthorizedDomain]])

    waitForExpectations(timeout: 105)
  }


}
#endif
