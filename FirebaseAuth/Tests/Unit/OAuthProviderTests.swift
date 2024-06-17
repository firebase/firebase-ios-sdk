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

@testable import FirebaseAuth
import FirebaseCore

#if os(iOS)
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class OAuthProviderTests: RPCBaseTests {
    static let kFakeAuthorizedDomain = "test.firebaseapp.com"
    static let kFakeAuthorizedWebDomain = "test.web.app"
    private let kFakeAccessToken = "fakeAccessToken"
    private let kFakeIDToken = "fakeIDToken"
    private let kFakeProviderID = "fakeProviderID"
    static let kFakeAPIKey = "asdfghjkl"
    static let kFakeEmulatorHost = "emulatorhost"
    static let kFakeEmulatorPort = 12345
    static let kFakeClientID = "123456.apps.googleusercontent.com"
    static let kFakeOAuthResponseURL = "fakeOAuthResponseURL"
    static let kFakeFirebaseAppID = "1:123456789:ios:123abc456def"
    static let kFakeEncodedFirebaseAppID = "app-1-123456789-ios-123abc456def"
    static let kFakeTenantID = "tenantID"
    static let kFakeReverseClientID = "com.googleusercontent.apps.123456"

    // Switches for testing different OAuth test flows
    // TODO: Consider using an enum for these instead.
    static var testTenantID = false
    static var testCancel = false
    static var testErrorString = false
    static var testInternalError = false
    static var testInvalidClientID = false
    static var testUnknownError = false
    static var testAppID = false
    static var testEmulator = false
    static var testAppCheck = false

    static var auth: Auth?

    /** @fn testObtainingOAuthCredentialNoIDToken
        @brief Tests the correct creation of an OAuthCredential without an IDToken.
     */
    func testObtainingOAuthCredentialNoIDToken() throws {
      initApp(#function)
      let credential = OAuthProvider.credential(providerID: .apple,
                                                accessToken: kFakeAccessToken)
      XCTAssertEqual(credential.accessToken, kFakeAccessToken)
      XCTAssertEqual(credential.provider, AuthProviderID.apple.rawValue)
      XCTAssertNil(credential.idToken)
    }

    /** @fn testObtainingOAuthCredentialWithFullName
        @brief Tests the correct creation of an OAuthCredential with a fullName.
     */
    func testObtainingOAuthCredentialWithFullName() throws {
      let kFakeGivenName = "Paul"
      let kFakeFamilyName = "B"
      var fullName = PersonNameComponents()
      fullName.givenName = kFakeGivenName
      fullName.familyName = kFakeFamilyName
      initApp(#function)
      let credential = OAuthProvider.appleCredential(withIDToken: kFakeIDToken, rawNonce: nil,
                                                     fullName: fullName)
      XCTAssertEqual(credential.fullName, fullName)
      XCTAssertEqual(credential.provider, "apple.com")
      XCTAssertEqual(credential.idToken, kFakeIDToken)
      XCTAssertNil(credential.accessToken)
    }

    /** @fn testObtainingOAuthCredentialWithIDToken
        @brief Tests the correct creation of an OAuthCredential with an IDToken
     */
    func testObtainingOAuthCredentialWithIDToken() throws {
      initApp(#function)
      let credential = OAuthProvider.credential(providerID: .email,
                                                idToken: kFakeIDToken,
                                                accessToken: kFakeAccessToken)
      XCTAssertEqual(credential.accessToken, kFakeAccessToken)
      XCTAssertEqual(credential.provider, AuthProviderID.email.rawValue)
      XCTAssertEqual(credential.idToken, kFakeIDToken)
    }

    /** @fn testObtainingOAuthProvider
        @brief Tests the correct creation of an FIROAuthProvider instance.
     */
    func testObtainingOAuthProvider() throws {
      initApp(#function)
      let provider = OAuthProvider(providerID: kFakeProviderID, auth: OAuthProviderTests.auth!)
      XCTAssertEqual(provider.providerID, kFakeProviderID)
    }

    /** @fn testGetCredentialWithUIDelegateWithClientID
        @brief Tests a successful invocation of @c getCredentialWithUIDelegate
     */
    func testGetCredentialWithUIDelegateWithClientID() throws {
      initApp(#function)
      try testOAuthFlow(description: #function)
    }

    /** @fn testGetCredentialWithUIDelegateWithTenantID
        @brief Tests a successful invocation of @c getCredentialWithUIDelegate:completion:
     */
    func testGetCredentialWithUIDelegateWithTenantID() throws {
      initApp(#function)

      // Update tenantID on workqueue to enable _protectedDataDidBecomeAvailableObserver to finish
      // init.
      kAuthGlobalWorkQueue.sync {
        OAuthProviderTests.auth?.tenantID = OAuthProviderTests.kFakeTenantID
      }
      OAuthProviderTests.testTenantID = true
      try testOAuthFlow(description: #function)
      OAuthProviderTests.auth?.tenantID = nil
      OAuthProviderTests.testTenantID = false
    }

    /** @fn testGetCredentialWithUIDelegateUserCancellationWithClientID
        @brief Tests an unsuccessful invocation of @c testGetCredentialWithUIDelegateUserCancellationWithClientID due to user
            cancelation.
     */
    func testGetCredentialWithUIDelegateUserCancellationWithClientID() throws {
      initApp(#function)
      OAuthProviderTests.testCancel = true
      try testOAuthFlow(description: #function)
      OAuthProviderTests.testCancel = false
    }

    /** @fn testGetCredentialWithUIDelegateNetworkRequestFailedWithClientID
        @brief Tests an unsuccessful invocation of @c getCredentialWithUIDelegate due to a
            failed network request within the web context.
     */
    func testGetCredentialWithUIDelegateNetworkRequestFailedWithClientID() throws {
      initApp(#function)
      OAuthProviderTests.testErrorString = true
      try testOAuthFlow(description: #function)
      OAuthProviderTests.testErrorString = false
    }

    /** @fn testGetCredentialWithUIDelegateInternalErrorWithClientID
        @brief Tests an unsuccessful invocation of @c getCredentialWithUIDelegate due to an
            internal error within the web context.
     */
    func testGetCredentialWithUIDelegateInternalErrorWithClientID() throws {
      initApp(#function)
      OAuthProviderTests.testInternalError = true
      try testOAuthFlow(description: #function)
      OAuthProviderTests.testInternalError = false
    }

    /** @fn testGetCredentialWithUIDelegateInvalidClientID
        @brief Tests an unsuccessful invocation of @c getCredentialWithUIDelegate due to an
            use of an invalid client ID.
     */
    func testGetCredentialWithUIDelegateInvalidClientID() throws {
      initApp(#function)
      OAuthProviderTests.testInvalidClientID = true
      try testOAuthFlow(description: #function)
      OAuthProviderTests.testInvalidClientID = false
    }

    /** @fn testGetCredentialWithUIDelegateUnknownErrorWithClientID
        @brief Tests an unsuccessful invocation of @c getCredentialWithUIDelegate due to an
            unknown error.
     */
    func testGetCredentialWithUIDelegateUnknownErrorWithClientID() throws {
      initApp(#function)
      OAuthProviderTests.testUnknownError = true
      try testOAuthFlow(description: #function)
      OAuthProviderTests.testUnknownError = false
    }

    /** @fn testGetCredentialWithUIDelegateWithFirebaseAppID
        @brief Tests a successful invocation of @c getCredentialWithUIDelegate
     */
    func testGetCredentialWithUIDelegateWithFirebaseAppID() throws {
      initApp(#function, useAppID: true, omitClientID: true,
              scheme: OAuthProviderTests.kFakeEncodedFirebaseAppID)
      OAuthProviderTests.testAppID = true
      try testOAuthFlow(description: #function)
      OAuthProviderTests.testAppID = false
    }

    /** @fn testGetCredentialWithUIDelegateWithFirebaseAppIDWhileClientIdPresent
        @brief Tests a successful invocation of @c getCredentialWithUIDelegate when the
       client ID is present in the plist file, but the encoded app ID is the registered custom URL
       scheme.
     */
    func testGetCredentialWithUIDelegateWithFirebaseAppIDWhileClientIdPresent() throws {
      initApp(#function, useAppID: true, scheme: OAuthProviderTests.kFakeEncodedFirebaseAppID)
      OAuthProviderTests.testAppID = true
      try testOAuthFlow(description: #function)
      OAuthProviderTests.testAppID = false
    }

    /** @fn testGetCredentialWithUIDelegateUseEmulator
        @brief Tests a successful invocation of @c getCredentialWithUIDelegate when using the emulator.
     */
    func testGetCredentialWithUIDelegateUseEmulator() throws {
      initApp(#function, useAppID: true)
      OAuthProviderTests.auth?.requestConfiguration.emulatorHostAndPort =
        "\(OAuthProviderTests.kFakeEmulatorHost):\(OAuthProviderTests.kFakeEmulatorPort)"
      OAuthProviderTests.testEmulator = true
      try testOAuthFlow(description: #function)
      OAuthProviderTests.testEmulator = false
    }

    /** @fn testGetCredentialWithUIDelegateWithAppCheckToken
        @brief Tests a successful invocation of @c getCredentialWithUIDelegate
     */
    func testGetCredentialWithUIDelegateWithAppCheckToken() throws {
      let fakeAppCheck = FakeAppCheck()
      initApp(#function, useAppID: true)
      OAuthProviderTests.auth?.requestConfiguration.appCheck = fakeAppCheck
      OAuthProviderTests.testAppCheck = true
      try testOAuthFlow(description: #function)
      OAuthProviderTests.testAppCheck = false
    }

    /** @fn testOAuthCredentialCoding
        @brief Tests successful archiving and unarchiving of @c GoogleAuthCredential.
     */
    func testOAuthCredentialCoding() throws {
      let kAccessToken = "accessToken"
      let kIDToken = "idToken"
      let kRawNonce = "nonce"
      let kSecret = "sEcret"
      let kFullName = PersonNameComponents()
      let kPendingToken = "pendingToken"

      let credential = OAuthCredential(withProviderID: "dummyProvider",
                                       idToken: kIDToken,
                                       rawNonce: kRawNonce,
                                       accessToken: kAccessToken,
                                       secret: kSecret,
                                       fullName: kFullName,
                                       pendingToken: kPendingToken)

      XCTAssertTrue(OAuthCredential.supportsSecureCoding)
      let data = try NSKeyedArchiver.archivedData(
        withRootObject: credential,
        requiringSecureCoding: true
      )
      let unarchivedCredential = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
        ofClasses: [OAuthCredential.self, NSPersonNameComponents.self], from: data
      ) as? OAuthCredential)
      XCTAssertEqual(unarchivedCredential.idToken, kIDToken)
      XCTAssertEqual(unarchivedCredential.rawNonce, kRawNonce)
      XCTAssertEqual(unarchivedCredential.accessToken, kAccessToken)
      XCTAssertEqual(unarchivedCredential.secret, kSecret)
      XCTAssertEqual(unarchivedCredential.fullName, kFullName)
      XCTAssertEqual(unarchivedCredential.pendingToken, kPendingToken)
      XCTAssertEqual(unarchivedCredential.provider, OAuthProvider.id)
    }

    private func initApp(_ functionName: String, useAppID: Bool = false, omitClientID: Bool = false,
                         scheme: String = OAuthProviderTests.kFakeReverseClientID) {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.apiKey = OAuthProviderTests.kFakeAPIKey
      options.projectID = "myProjectID"
      if useAppID {
        options.googleAppID = OAuthProviderTests.kFakeFirebaseAppID
      }
      if !omitClientID {
        options.clientID = OAuthProviderTests.kFakeClientID
      }

      let strippedName = functionName.replacingOccurrences(of: "(", with: "")
        .replacingOccurrences(of: ")", with: "")
      FirebaseApp.configure(name: strippedName, options: options)
      OAuthProviderTests.auth = Auth.auth(app: FirebaseApp.app(name: strippedName)!)
      OAuthProviderTests.auth?.mainBundleUrlTypes =
        [["CFBundleURLSchemes": [scheme]]]
    }

    private func testOAuthFlow(description: String,
                               with fakeAppCheck: FakeAppCheck? = nil) throws {
      let expectation = self.expectation(description: description)
      let provider = OAuthProvider(providerID: kFakeProviderID, auth: OAuthProviderTests.auth!)

      // Use fake authURLPresenter so we can test the parameters that get sent to it.
      OAuthProviderTests.auth?.authURLPresenter = FakePresenter()

      // 1. Setup fakes and parameters for getCredential.
      if !OAuthProviderTests.testEmulator {
        let projectConfigExpectation = self.expectation(description: "projectConfiguration")
        rpcIssuer?.projectConfigRequester = { request in
          // 3. Validate the created Request instance.
          XCTAssertEqual(request.apiKey, OAuthProviderTests.kFakeAPIKey)
          XCTAssertEqual(request.endpoint, "getProjectConfig")
          // 4. Fulfill the expectation.
          projectConfigExpectation.fulfill()
          kAuthGlobalWorkQueue.async {
            do {
              // 5. Send the response from the fake backend.
              try self.rpcIssuer?
                .respond(withJSON: ["authorizedDomains": [
                  OAuthProviderTests.kFakeAuthorizedWebDomain,
                  OAuthProviderTests.kFakeAuthorizedDomain]])
            } catch {
              XCTFail("Failure sending response: \(error)")
            }
          }
        }
      }

      class FakePresenter: NSObject, AuthWebViewControllerDelegate {
        func webViewController(_ webViewController: AuthWebViewController,
                               canHandle URL: URL) -> Bool {
          XCTFail("Do not call")
          return false
        }

        func webViewControllerDidCancel(_ webViewController: AuthWebViewController) {
          XCTFail("Do not call")
        }

        func webViewController(_ webViewController: AuthWebViewController,
                               didFailWithError error: Error) {
          XCTFail("Do not call")
        }

        func present(_ presentURL: URL, uiDelegate UIDelegate: AuthUIDelegate?,
                     callbackMatcher: @escaping (URL?) -> Bool,
                     completion: @escaping (URL?, Error?) -> Void) {
          // 6. Verify flow triggers present in the FakePresenter class with the right parameters.
          if OAuthProviderTests.testEmulator {
            XCTAssertEqual(presentURL.scheme, "http")
            XCTAssertEqual(presentURL.host, OAuthProviderTests.kFakeEmulatorHost)
            XCTAssertEqual(presentURL.port, OAuthProviderTests.kFakeEmulatorPort)
            XCTAssertEqual(presentURL.path, "/emulator/auth/handler")
          } else {
            XCTAssertEqual(presentURL.scheme, "https")
            XCTAssertEqual(presentURL.host, OAuthProviderTests.kFakeAuthorizedDomain)
            XCTAssertEqual(presentURL.path, "/__/auth/handler")
          }
          let params = AuthWebUtils.dictionary(withHttpArgumentsString: presentURL.query)
          XCTAssertEqual(params["ibi"], Bundle.main.bundleIdentifier)
          if OAuthProviderTests.testAppID {
            XCTAssertEqual(params["appId"], OAuthProviderTests.kFakeFirebaseAppID)
          } else {
            XCTAssertEqual(params["clientId"], OAuthProviderTests.kFakeClientID)
          }
          XCTAssertEqual(params["apiKey"], OAuthProviderTests.kFakeAPIKey)
          XCTAssertEqual(params["authType"], "signInWithRedirect")
          XCTAssertNotNil(params["v"])
          if OAuthProviderTests.testTenantID {
            XCTAssertEqual(params["tid"], OAuthProviderTests.kFakeTenantID)
          } else {
            XCTAssertNil(params["tid"])
          }
          let appCheckToken = presentURL.fragment
          let verifyAppCheckToken = OAuthProviderTests.testAppCheck ? "fac=fakeAppCheckToken" : nil
          XCTAssertEqual(appCheckToken, verifyAppCheckToken)

          // 7. Test callbackMatcher
          let kFakeRedirectStart = OAuthProviderTests
            .testAppID ? "app-1-123456789-ios-123abc456def" :
            OAuthProviderTests.kFakeReverseClientID
          let kFakeRedirectURLBase = kFakeRedirectStart + "://firebaseauth/" +
            "link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcallback%3F"
          var kFakeRedirectURLRest = "authType%3DsignInWithRedirect%26link%3D"

          if OAuthProviderTests.testInternalError {
            kFakeRedirectURLRest = "firebaseError%3D%257B%2522code%2522%253" +
              "A%2522auth%252Finternal-error%2522%252C%2522message%2522%253A%2522Internal%2520" +
              "error%2520.%2522%257D%26authType%3DsignInWithRedirect"
          } else if OAuthProviderTests.testInvalidClientID {
            kFakeRedirectURLRest = "firebaseError%3D%257B%2522code%2522%253A%2522auth" +
              "%252Finvalid-oauth-client-id%2522%252C%2522message%2522%253A%2522The%2520OAuth%2520client%" +
              "2520ID%2520provided%2520is%2520either%2520invalid%2520or%2520does%2520not%2520match%2520the%" +
              "2520specified%2520API%2520key.%2522%257D%26authType%3DsignInWithRedirect"
          } else if OAuthProviderTests.testErrorString {
            kFakeRedirectURLRest = "firebaseError%3D%257B%2522code%2" +
              "522%253A%2522auth%252Fnetwork-request-failed%2522%252C%2522message%2522%253A%2522The%" +
              "2520network%2520request%2520failed%2520.%2522%257D%26authType%3DsignInWithRedirect"
          } else if OAuthProviderTests.testUnknownError {
            kFakeRedirectURLRest = "firebaseError%3D%257B%2522code%2522%253A%2522auth%2" +
              "52Funknown-error-id%2522%252C%2522message%2522%253A%2522The%2520OAuth%2520client%2520ID%" +
              "2520provided%2520is%2520either%2520invalid%2520or%2520does%2520not%2520match%2520the%2520" +
              "specified%2520API%2520key.%2522%257D%26authType%3DsignInWithRedirect"
          }
          var redirectURL = "\(kFakeRedirectURLBase)\(kFakeRedirectURLRest)"
          // Add fake OAuthResponse to callback.
          if !OAuthProviderTests.testErrorString, !OAuthProviderTests.testInternalError,
             !OAuthProviderTests.testInvalidClientID, !OAuthProviderTests.testUnknownError {
            redirectURL += OAuthProviderTests.kFakeOAuthResponseURL
          }

          // Verify that the URL is rejected by the callback matcher without the event ID.
          XCTAssertFalse(callbackMatcher(URL(string: "\(redirectURL)")))

          // Verify that the URL is accepted by the callback matcher with the matching event ID.
          let redirectWithEventID =
            "\(redirectURL)%26eventId%3D\(params["eventId"] ?? "missingEventID")"
          let originalComponents = URLComponents(string: redirectWithEventID)!
          XCTAssertTrue(callbackMatcher(originalComponents.url))

          var components = originalComponents
          components.query = "https"
          XCTAssertFalse(callbackMatcher(components.url))

          components = originalComponents
          components.host = "badhost"
          XCTAssertFalse(callbackMatcher(components.url))

          components = originalComponents
          components.path = "badpath"
          XCTAssertFalse(callbackMatcher(components.url))

          components = originalComponents
          components.query = "badquery"
          XCTAssertFalse(callbackMatcher(components.url))

          // 8. Do the callback to the original call.
          kAuthGlobalWorkQueue.async {
            if OAuthProviderTests.testCancel {
              completion(nil, AuthErrorUtils.webContextCancelledError(message: nil))
            } else {
              completion(originalComponents.url, nil)
            }
          }
        }
      }

      // 2. Request the credential.
      provider.getCredentialWith(nil) { credential, error in

        // 9. After the response triggers the callback, verify the values in the callback credential
        XCTAssertTrue(Thread.isMainThread)
        if OAuthProviderTests.testCancel {
          XCTAssertNil(credential)
          XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.webContextCancelled.rawValue)
        } else if OAuthProviderTests.testErrorString {
          XCTAssertNil(credential)
          XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.webNetworkRequestFailed.rawValue)
        } else if OAuthProviderTests.testInternalError {
          XCTAssertNil(credential)
          XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.webInternalError.rawValue)
        } else if OAuthProviderTests.testInvalidClientID {
          XCTAssertNil(credential)
          XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidClientID.rawValue)
        } else if OAuthProviderTests.testUnknownError {
          XCTAssertNil(credential)
          XCTAssertEqual(
            (error as? NSError)?.code,
            AuthErrorCode.webSignInUserInteractionFailure.rawValue
          )
        } else {
          XCTAssertNil(error)
          let oAuthCredential = credential as? OAuthCredential
          XCTAssertEqual(
            oAuthCredential?.OAuthResponseURLString,
            OAuthProviderTests.kFakeOAuthResponseURL
          )
        }
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }
  }
#endif
