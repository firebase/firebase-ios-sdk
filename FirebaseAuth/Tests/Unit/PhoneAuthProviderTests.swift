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

#if os(iOS)

  import Foundation
  import XCTest

  import FirebaseCore
  @testable import FirebaseAuth

  class PhoneAuthProviderTests: RPCBaseTests {
    static let kFakeAuthorizedDomain = "test.firebaseapp.com"
    static let kFakeBundleID = "com.firebaseapp.example"
    private let kFakeAccessToken = "fakeAccessToken"
    private let kFakeIDToken = "fakeIDToken"
    private let kFakeProviderID = "fakeProviderID"
    static let kFakeAPIKey = "asdfghjkl"
    static let kFakeEmulatorHost = "emulatorhost"
    static let kFakeEmulatorPort = 12345
    static let kFakeClientID = "123456.apps.googleusercontent.com"
    static let kFakeFirebaseAppID = "1:123456789:ios:123abc456def"
    static let kFakeEncodedFirebaseAppID = "app-1-123456789-ios-123abc456def"
    static let kFakeTenantID = "tenantID"
    static let kFakeReverseClientID = "com.googleusercontent.apps.123456"

    private let kTestVerificationID = "verificationID"
    private let kTestVerificationCode = "verificationCode"
    private let kTestPhoneNumber = "55555555"
    private let kTestReceipt = "receipt"
    private let kTestSecret = "secret"
    private let kVerificationIDKey = "sessionInfo"

    // Switches for testing different Phone Auth test flows
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

    /** @fn testCredentialWithVerificationID
        @brief Tests the @c credentialWithToken method to make sure that it returns a valid AuthCredential instance.
     */
    func testCredentialWithVerificationID() throws {
      initApp(#function)
      let auth = try XCTUnwrap(PhoneAuthProviderTests.auth)
      let provider = PhoneAuthProvider.provider(auth: auth)
      let credential = provider.credential(withVerificationID: kTestVerificationID,
                                           verificationCode: kTestVerificationCode)
      XCTAssertEqual(credential.verificationID, kTestVerificationID)
      XCTAssertEqual(credential.verificationCode, kTestVerificationCode)
      XCTAssertNil(credential.temporaryProof)
      XCTAssertNil(credential.phoneNumber)
    }

    /** @fn testVerifyEmptyPhoneNumber
        @brief Tests a failed invocation @c verifyPhoneNumber:completion: because an empty phone
            number was provided.
     */
    func testVerifyEmptyPhoneNumber() throws {
      initApp(#function)
      let auth = try XCTUnwrap(PhoneAuthProviderTests.auth)
      let provider = PhoneAuthProvider.provider(auth: auth)
      let expectation = self.expectation(description: #function)

      // Empty phone number is checked on the client side so no backend RPC is faked.
      provider.verifyPhoneNumber("", uiDelegate: nil) { verificationID, error in
        XCTAssertNotNil(error)
        XCTAssertNil(verificationID)
        XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.missingPhoneNumber.rawValue)
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testVerifyInvalidPhoneNumber
        @brief Tests a failed invocation @c verifyPhoneNumber:completion: because an invalid phone
            number was provided.
     */
    func testVerifyInvalidPhoneNumber() throws {
      try internalTestVerify(valid: false, function: #function)
    }

    /** @fn testVerifyPhoneNumber
        @brief Tests a successful invocation of @c verifyPhoneNumber:completion:.
     */
    func testVerifyPhoneNumber() throws {
      try internalTestVerify(valid: true, function: #function)
    }

    /** @fn testVerifyPhoneNumberInTestMode
        @brief Tests a successful invocation of @c verifyPhoneNumber:completion: when app verification
            is disabled.
     */
    func testVerifyPhoneNumberInTestMode() throws {
      try internalTestVerify(valid: true, function: #function, testMode: true)
    }

    /** @fn testVerifyPhoneNumberInTestModeFailure
        @brief Tests a failed invocation of @c verifyPhoneNumber:completion: when app verification
            is disabled.
     */
    func testVerifyPhoneNumberInTestModeFailure() throws {
      try internalTestVerify(valid: false, function: #function, testMode: true)
    }

    // TODO: Pausing here pending AuthURLPresenter.swift along with faking capability.
    // TODO: Also need to be able to fake getToken from AuthAPNSTokenManager.
    /** @fn testVerifyPhoneNumberUIDelegateFirebaseAppIdFlow
        @brief Tests a successful invocation of @c verifyPhoneNumber:UIDelegate:completion:.
     */
    func SKIPtestVerifyPhoneNumberUIDelegateFirebaseAppIdFlow() throws {
      try internalTestVerify(valid: true, function: #function, reCAPTCHAfallback: true)
    }

    private func internalTestVerify(valid: Bool, function: String, testMode: Bool = false,
                                    reCAPTCHAfallback: Bool = false) throws {
      initApp(function, testMode: testMode, reCAPTCHAfallback: reCAPTCHAfallback)
      let auth = try XCTUnwrap(PhoneAuthProviderTests.auth)
      let provider = PhoneAuthProvider.provider(auth: auth)
      let expectation = self.expectation(description: #function)
      let group = createGroup()

      provider.verifyPhoneNumber(kTestPhoneNumber, uiDelegate: nil) { verificationID, error in
        XCTAssertTrue(Thread.isMainThread)
        if valid {
          XCTAssertNil(error)
          XCTAssertEqual(verificationID, self.kTestVerificationID)
        } else {
          XCTAssertNotNil(error)
          XCTAssertNil(verificationID)
          XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidPhoneNumber.rawValue)
        }
        expectation.fulfill()
      }
      group.wait()
      if reCAPTCHAfallback {
        // Response for the underlying GetProjectConfig RPC call.
        try rpcIssuer?.respond(withJSON: ["projectId": "kFakeProjectID",
                                          "authorizedDomains": [PhoneAuthProviderTests
                                            .kFakeAuthorizedDomain]])
      } else if valid {
        // Response for the underlying SendVerificationCode RPC call.
        try rpcIssuer?.respond(withJSON: [kVerificationIDKey: kTestVerificationID])
      } else {
        try rpcIssuer?.respond(serverErrorMessage: "INVALID_PHONE_NUMBER")
      }
      waitForExpectations(timeout: 5)
    }

    // TODO: verify all options are needed for PhoneAuthTests
    private func initApp(_ functionName: String, useAppID: Bool = false, omitClientID: Bool = false,
                         scheme: String = PhoneAuthProviderTests.kFakeReverseClientID,
                         testMode: Bool = false, reCAPTCHAfallback: Bool = false) {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.apiKey = PhoneAuthProviderTests.kFakeAPIKey
      options.projectID = "myProjectID"
      if useAppID {
        options.googleAppID = PhoneAuthProviderTests.kFakeFirebaseAppID
      }
      if !omitClientID {
        options.clientID = PhoneAuthProviderTests.kFakeClientID
      }

      let strippedName = functionName.replacingOccurrences(of: "(", with: "")
        .replacingOccurrences(of: ")", with: "")
      FirebaseApp.configure(name: strippedName, options: options)
      let auth = Auth.auth(app: FirebaseApp.app(name: strippedName)!)

      kAuthGlobalWorkQueue.sync {
        // Wait for Auth protectedDataInitialization to finish.
        PhoneAuthProviderTests.auth = auth
        if testMode {
          // Disable app verification.
          let settings = AuthSettings()
          settings.isAppVerificationDisabledForTesting = true
          auth.settings = settings
        } else if !reCAPTCHAfallback {
          // Fake out appCredentialManager flow.
          auth.appCredentialManager.credential = AuthAppCredential(receipt: kTestReceipt,
                                                                   secret: kTestSecret)
        }
        auth.notificationManager.immediateCallbackForTestFaking = true
        auth.mainBundleUrlTypes = [["CFBundleURLSchemes": [scheme]]]
      }
    }

    private class FakeApplication: Application {
      var delegate: UIApplicationDelegate?
    }
  }
#endif
