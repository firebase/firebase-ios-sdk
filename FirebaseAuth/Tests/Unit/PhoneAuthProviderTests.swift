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

  @testable import FirebaseAuth
  import FirebaseCore
  import SafariServices

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class PhoneAuthProviderTests: RPCBaseTests {
    static let kFakeAuthorizedDomain = "test.firebaseapp.com"
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
    private let kTestReceipt = "receipt"
    private let kTestTimeout = "1"
    private let kTestSecret = "secret"
    private let kVerificationIDKey = "sessionInfo"
    private let kFakeEncodedFirebaseAppID = "app-1-123456789-ios-123abc456def"
    private let kFakeReCAPTCHAToken = "fakeReCAPTCHAToken"

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
      switch credential.credentialKind {
      case .phoneNumber: XCTFail("Should be verification case")
      case let .verification(id, code):
        XCTAssertEqual(id, kTestVerificationID)
        XCTAssertEqual(code, kTestVerificationCode)
      }
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
      try internalTestVerify(errorString: "INVALID_PHONE_NUMBER",
                             errorCode: AuthErrorCode.invalidPhoneNumber.rawValue,
                             function: #function)
    }

    /** @fn testVerifyPhoneNumber
     @brief Tests a successful invocation of @c verifyPhoneNumber:completion:.
     */
    func testVerifyPhoneNumber() throws {
      try internalTestVerify(function: #function)
    }

    /** @fn testVerifyPhoneNumberInTestMode
     @brief Tests a successful invocation of @c verifyPhoneNumber:completion: when app verification
     is disabled.
     */
    func testVerifyPhoneNumberInTestMode() throws {
      try internalTestVerify(function: #function, testMode: true)
    }

    /** @fn testVerifyPhoneNumberInTestModeFailure
     @brief Tests a failed invocation of @c verifyPhoneNumber:completion: when app verification
     is disabled.
     */
    func testVerifyPhoneNumberInTestModeFailure() throws {
      try internalTestVerify(errorString: "INVALID_PHONE_NUMBER",
                             errorCode: AuthErrorCode.invalidPhoneNumber.rawValue,
                             function: #function, testMode: true)
    }

    /** @fn testVerifyPhoneNumberUIDelegateFirebaseAppIdFlow
     @brief Tests a successful invocation of @c verifyPhoneNumber:UIDelegate:completion:.
     */
    func testVerifyPhoneNumberUIDelegateFirebaseAppIdFlow() throws {
      try internalTestVerify(function: #function, reCAPTCHAfallback: true)
    }

    /** @fn testVerifyPhoneNumberUIDelegateFirebaseAppIdWhileClientIdPresentFlow
     @brief Tests a successful invocation of @c verifyPhoneNumber:UIDelegate:completion: when the
     client ID is present in the plist file, but the encoded app ID is the registered custom URL scheme.
     */
    func testVerifyPhoneNumberUIDelegateFirebaseAppIdWhileClientIdPresentFlow() throws {
      try internalTestVerify(function: #function, useClientID: true,
                             bothClientAndAppID: true, reCAPTCHAfallback: true)
    }

    /** @fn testVerifyPhoneNumberUIDelegateClientIdFlow
     @brief Tests a successful invocation of @c verifyPhoneNumber:UIDelegate:completion:.
     */
    func testVerifyPhoneNumberUIDelegateClientIdFlow() throws {
      try internalTestVerify(function: #function, useClientID: true, reCAPTCHAfallback: true)
    }

    /** @fn testVerifyPhoneNumberUIDelegateInvalidClientID
     @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in an
     invalid client ID error.
     */
    func testVerifyPhoneNumberUIDelegateInvalidClientID() throws {
      try internalTestVerify(
        errorURLString: PhoneAuthProviderTests.kFakeRedirectURLStringInvalidClientID,
        errorCode: AuthErrorCode.invalidClientID.rawValue,
        function: #function,
        useClientID: true,
        reCAPTCHAfallback: true
      )
    }

    /** @fn testVerifyPhoneNumberUIDelegateWebNetworkRequestFailed
     @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in a web
     network request failed error.
     */
    func testVerifyPhoneNumberUIDelegateWebNetworkRequestFailed() throws {
      try internalTestVerify(
        errorURLString: PhoneAuthProviderTests.kFakeRedirectURLStringWebNetworkRequestFailed,
        errorCode: AuthErrorCode.webNetworkRequestFailed.rawValue,
        function: #function,
        useClientID: true,
        reCAPTCHAfallback: true
      )
    }

    /** @fn testVerifyPhoneNumberUIDelegateWebInternalError
     @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in a web
     internal error.
     */
    func testVerifyPhoneNumberUIDelegateWebInternalError() throws {
      try internalTestVerify(
        errorURLString: PhoneAuthProviderTests.kFakeRedirectURLStringWebInternalError,
        errorCode: AuthErrorCode.webInternalError.rawValue,
        function: #function,
        useClientID: true,
        reCAPTCHAfallback: true
      )
    }

    /** @fn testVerifyPhoneNumberUIDelegateUnexpectedError
        @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in an
            invalid client ID.
     */
    func testVerifyPhoneNumberUIDelegateUnexpectedError() throws {
      try internalTestVerify(
        errorURLString: PhoneAuthProviderTests.kFakeRedirectURLStringUnknownError,
        errorCode: AuthErrorCode.webSignInUserInteractionFailure.rawValue,
        function: #function,
        useClientID: true,
        reCAPTCHAfallback: true
      )
    }

    /** @fn testVerifyPhoneNumberUIDelegateUnstructuredError
        @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in an
            error being surfaced with a default NSLocalizedFailureReasonErrorKey due to an unexpected
            structure of the error response.
     */
    func testVerifyPhoneNumberUIDelegateUnstructuredError() throws {
      try internalTestVerify(
        errorURLString: PhoneAuthProviderTests.kFakeRedirectURLStringUnstructuredError,
        errorCode: AuthErrorCode.appVerificationUserInteractionFailure.rawValue,
        function: #function,
        useClientID: true,
        reCAPTCHAfallback: true
      )
    }

    // TODO: This test is skipped. What was formerly an Objective-C exception is now a Swift fatal_error.
    // The test runs correctly, but it's not clear how to automate fatal_error testing. Switching to
    // Swift exceptions would break the API.
    /** @fn testVerifyPhoneNumberUIDelegateRaiseException
        @brief Tests a invocation of @c verifyPhoneNumber:UIDelegate:completion: which results in an
            exception.
     */
    func SKIPtestVerifyPhoneNumberUIDelegateRaiseException() throws {
      initApp(#function)
      let auth = try XCTUnwrap(PhoneAuthProviderTests.auth)
      auth.mainBundleUrlTypes = [["CFBundleURLSchemes": ["fail"]]]
      let provider = PhoneAuthProvider.provider(auth: auth)
      provider.verifyPhoneNumber(kTestPhoneNumber, uiDelegate: nil) { verificationID, error in
        XCTFail("Should not call completion")
      }
    }

    /** @fn testNotForwardingNotification
        @brief Tests returning an error for the app failing to forward notification.
     */
    func testNotForwardingNotification() throws {
      func testVerifyPhoneNumberUIDelegateUnstructuredError() throws {
        try internalTestVerify(
          errorURLString: PhoneAuthProviderTests.kFakeRedirectURLStringUnstructuredError,
          errorCode: AuthErrorCode.appVerificationUserInteractionFailure.rawValue,
          function: #function,
          useClientID: true,
          reCAPTCHAfallback: true,
          forwardingNotification: false
        )
      }
    }

    /** @fn testMissingAPNSToken
        @brief Tests returning an error for the app failing to provide an APNS device token.
     */
    func testMissingAPNSToken() throws {
      try internalTestVerify(
        errorCode: AuthErrorCode.missingAppToken.rawValue,
        function: #function,
        useClientID: true,
        reCAPTCHAfallback: true,
        presenterError: NSError(
          domain: AuthErrors.domain,
          code: AuthErrorCode.missingAppToken.rawValue
        )
      )
    }

    /** @fn testVerifyPhoneNumberUIDelegateiOSSecretMissingFlow
        @brief Tests a successful invocation of @c verifyPhoneNumber:UIDelegate:completion: that falls
       back to the reCAPTCHA flow when the push notification is not received before the timeout.
     */
    func testVerifyPhoneNumberUIDelegateiOSSecretMissingFlow() throws {
      try internalFlow(function: #function, useClientID: false, reCAPTCHAfallback: true)
    }

    /** @fn testVerifyClient
        @brief Tests verifying client before sending verification code.
     */
    func testVerifyClient() throws {
      try internalFlow(function: #function, useClientID: true, reCAPTCHAfallback: false)
    }

    /** @fn testSendVerificationCodeFailedRetry
        @brief Tests failed retry after failing to send verification code.
     */
    func testSendVerificationCodeFailedRetry() throws {
      try internalFlowRetry(function: #function)
    }

    /** @fn testSendVerificationCodeSuccessfulRetry
        @brief Tests successful retry after failing to send verification code.
     */
    func testSendVerificationCodeSuccessfulRetry() throws {
      try internalFlowRetry(function: #function, goodRetry: true)
    }

    /** @fn testPhoneAuthCredentialCoding
        @brief Tests successful archiving and unarchiving of @c PhoneAuthCredential.
     */
    func testPhoneAuthCredentialCoding() throws {
      let kVerificationID = "My verificationID"
      let kVerificationCode = "1234"
      let credential = PhoneAuthCredential(withProviderID: PhoneAuthProvider.id,
                                           verificationID: kVerificationID,
                                           verificationCode: kVerificationCode)
      XCTAssertTrue(PhoneAuthCredential.supportsSecureCoding)
      let data = try NSKeyedArchiver.archivedData(
        withRootObject: credential,
        requiringSecureCoding: true
      )
      let unarchivedCredential = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
        ofClass: PhoneAuthCredential.self, from: data
      ))
      switch unarchivedCredential.credentialKind {
      case .phoneNumber: XCTFail("Should be verification case")
      case let .verification(id, code):
        XCTAssertEqual(id, kVerificationID)
        XCTAssertEqual(code, kVerificationCode)
      }
      XCTAssertEqual(unarchivedCredential.provider, PhoneAuthProvider.id)
    }

    /** @fn testPhoneAuthCredentialCodingPhone
        @brief Tests successful archiving and unarchiving of @c PhoneAuthCredential after other constructor.
     */
    func testPhoneAuthCredentialCodingPhone() throws {
      let kTemporaryProof = "Proof"
      let kPhoneNumber = "123457"
      let credential = PhoneAuthCredential(withTemporaryProof: kTemporaryProof,
                                           phoneNumber: kPhoneNumber,
                                           providerID: PhoneAuthProvider.id)
      XCTAssertTrue(PhoneAuthCredential.supportsSecureCoding)
      let data = try NSKeyedArchiver.archivedData(
        withRootObject: credential,
        requiringSecureCoding: true
      )
      let unarchivedCredential = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
        ofClasses: [PhoneAuthCredential.self, NSString.self], from: data
      ) as? PhoneAuthCredential)
      switch unarchivedCredential.credentialKind {
      case let .phoneNumber(phoneNumber, temporaryProof):
        XCTAssertEqual(temporaryProof, kTemporaryProof)
        XCTAssertEqual(phoneNumber, kPhoneNumber)
      case .verification: XCTFail("Should be phoneNumber case")
      }
      XCTAssertEqual(unarchivedCredential.provider, PhoneAuthProvider.id)
    }

    private func internalFlowRetry(function: String, goodRetry: Bool = false) throws {
      let function = function
      initApp(function, useClientID: true, fakeToken: true)
      let auth = try XCTUnwrap(PhoneAuthProviderTests.auth)
      let provider = PhoneAuthProvider.provider(auth: auth)
      let expectation = self.expectation(description: function)

      // Fake push notification.
      auth.appCredentialManager?.fakeCredential = AuthAppCredential(
        receipt: kTestReceipt,
        secret: kTestSecret
      )

      // 1. Intercept, handle, and test three RPC calls.

      let verifyClientRequestExpectation = self.expectation(description: "verifyClientRequest")
      verifyClientRequestExpectation.expectedFulfillmentCount = 2
      rpcIssuer?.verifyClientRequester = { request in
        XCTAssertEqual(request.appToken, "21402324255E")
        XCTAssertFalse(request.isSandbox)
        verifyClientRequestExpectation.fulfill()
        do {
          // Response for the underlying VerifyClientRequest RPC call.
          try self.rpcIssuer?.respond(withJSON: [
            "receipt": self.kTestReceipt,
            "suggestedTimeout": self.kTestTimeout,
          ])
        } catch {
          XCTFail("Failure sending response: \(error)")
        }
      }

      let verifyRequesterExpectation = self.expectation(description: "verifyRequester")
      verifyRequesterExpectation.expectedFulfillmentCount = 2
      var visited = false
      rpcIssuer?.verifyRequester = { request in
        XCTAssertEqual(request.phoneNumber, self.kTestPhoneNumber)
        switch request.codeIdentity {
        case let .credential(credential):
          XCTAssertEqual(credential.receipt, self.kTestReceipt)
          XCTAssertEqual(credential.secret, self.kTestSecret)
        default:
          XCTFail("Should be credential")
        }
        verifyRequesterExpectation.fulfill()
        do {
          if visited == false || goodRetry == false {
            // First Response for the underlying SendVerificationCode RPC call.
            try self.rpcIssuer?.respond(serverErrorMessage: "INVALID_APP_CREDENTIAL")
            visited = true
          } else {
            // Second Response for the underlying SendVerificationCode RPC call.
            try self.rpcIssuer?
              .respond(withJSON: [self.kVerificationIDKey: self.kTestVerificationID])
          }
        } catch {
          XCTFail("Failure sending response: \(error)")
        }
      }

      // Use fake authURLPresenter so we can test the parameters that get sent to it.
      PhoneAuthProviderTests.auth?.authURLPresenter =
        FakePresenter(
          urlString: PhoneAuthProviderTests.kFakeRedirectURLStringWithReCAPTCHAToken,
          clientID: PhoneAuthProviderTests.kFakeClientID,
          firebaseAppID: nil,
          errorTest: false,
          presenterError: nil
        )

      // 2. After setting up the fakes and parameters, call `verifyPhoneNumber`.
      provider
        .verifyPhoneNumber(kTestPhoneNumber, uiDelegate: nil) { verificationID, error in

          // 8. After the response triggers the callback in the FakePresenter, verify the callback.
          XCTAssertTrue(Thread.isMainThread)
          if goodRetry {
            XCTAssertNil(error)
            XCTAssertEqual(verificationID, self.kTestVerificationID)
          } else {
            XCTAssertNil(verificationID)
            XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.internalError.rawValue)
          }
          expectation.fulfill()
        }
      waitForExpectations(timeout: 5)
    }

    private func internalFlow(function: String,
                              useClientID: Bool = false,
                              reCAPTCHAfallback: Bool = false) throws {
      let function = function
      initApp(function, useClientID: useClientID, fakeToken: true)
      let auth = try XCTUnwrap(PhoneAuthProviderTests.auth)
      let provider = PhoneAuthProvider.provider(auth: auth)
      let expectation = self.expectation(description: function)

      // Fake push notification.
      auth.appCredentialManager?.fakeCredential = AuthAppCredential(
        receipt: kTestReceipt,
        secret: reCAPTCHAfallback ? nil : kTestSecret
      )

      // 1. Intercept, handle, and test three RPC calls.

      let verifyClientRequestExpectation = self.expectation(description: "verifyClientRequest")
      rpcIssuer?.verifyClientRequester = { request in
        XCTAssertEqual(request.appToken, "21402324255E")
        XCTAssertFalse(request.isSandbox)
        verifyClientRequestExpectation.fulfill()
        do {
          // Response for the underlying VerifyClientRequest RPC call.
          try self.rpcIssuer?.respond(withJSON: [
            "receipt": self.kTestReceipt,
            "suggestedTimeout": self.kTestTimeout,
          ])
        } catch {
          XCTFail("Failure sending response: \(error)")
        }
      }
      if reCAPTCHAfallback {
        let projectConfigExpectation = self.expectation(description: "projectConfiguration")
        rpcIssuer?.projectConfigRequester = { request in
          XCTAssertEqual(request.apiKey, PhoneAuthProviderTests.kFakeAPIKey)
          projectConfigExpectation.fulfill()
          kAuthGlobalWorkQueue.async {
            do {
              // Response for the underlying VerifyClientRequest RPC call.
              try self.rpcIssuer?.respond(
                withJSON: ["projectId": "kFakeProjectID",
                           "authorizedDomains": [PhoneAuthProviderTests.kFakeAuthorizedDomain]]
              )
            } catch {
              XCTFail("Failure sending response: \(error)")
            }
          }
        }
      }

      let verifyRequesterExpectation = self.expectation(description: "verifyRequester")
      rpcIssuer?.verifyRequester = { request in
        XCTAssertEqual(request.phoneNumber, self.kTestPhoneNumber)
        if reCAPTCHAfallback {
          switch request.codeIdentity {
          case let .recaptcha(token):
            XCTAssertEqual(token, self.kFakeReCAPTCHAToken)
          default:
            XCTFail("Should be recaptcha")
          }
        } else {
          switch request.codeIdentity {
          case let .credential(credential):
            XCTAssertEqual(credential.receipt, self.kTestReceipt)
            XCTAssertEqual(credential.secret, self.kTestSecret)
          default:
            XCTFail("Should be credential")
          }
        }
        verifyRequesterExpectation.fulfill()
        do {
          // Response for the underlying SendVerificationCode RPC call.
          try self.rpcIssuer?
            .respond(withJSON: [self.kVerificationIDKey: self.kTestVerificationID])
        } catch {
          XCTFail("Failure sending response: \(error)")
        }
      }

      // Use fake authURLPresenter so we can test the parameters that get sent to it.
      PhoneAuthProviderTests.auth?.authURLPresenter =
        FakePresenter(
          urlString: PhoneAuthProviderTests.kFakeRedirectURLStringWithReCAPTCHAToken,
          clientID: useClientID ? PhoneAuthProviderTests.kFakeClientID : nil,
          firebaseAppID: useClientID ? nil : PhoneAuthProviderTests.kFakeFirebaseAppID,
          errorTest: false,
          presenterError: nil
        )
      let uiDelegate = reCAPTCHAfallback ? FakeUIDelegate() : nil

      // 2. After setting up the fakes and parameters, call `verifyPhoneNumber`.
      provider
        .verifyPhoneNumber(kTestPhoneNumber, uiDelegate: uiDelegate) { verificationID, error in

          // 8. After the response triggers the callback in the FakePresenter, verify the callback.
          XCTAssertTrue(Thread.isMainThread)
          XCTAssertNil(error)
          XCTAssertEqual(verificationID, self.kTestVerificationID)
          expectation.fulfill()
        }

      waitForExpectations(timeout: 5)
    }

    /** @fn testVerifyClient
        @brief Tests verifying client before sending verification code.
     */

    private func internalTestVerify(errorString: String? = nil,
                                    errorURLString: String? = nil,
                                    errorCode: Int = 0,
                                    function: String,
                                    testMode: Bool = false,
                                    useClientID: Bool = false,
                                    bothClientAndAppID: Bool = false,
                                    reCAPTCHAfallback: Bool = false,
                                    forwardingNotification: Bool = true,
                                    presenterError: Error? = nil) throws {
      initApp(function, useClientID: useClientID, bothClientAndAppID: bothClientAndAppID,
              testMode: testMode,
              forwardingNotification: forwardingNotification)
      let auth = try XCTUnwrap(PhoneAuthProviderTests.auth)
      let provider = PhoneAuthProvider.provider(auth: auth)
      let expectation = self.expectation(description: function)

      if !reCAPTCHAfallback {
        // Fake out appCredentialManager flow.
        auth.appCredentialManager?.credential = AuthAppCredential(receipt: kTestReceipt,
                                                                  secret: kTestSecret)
      } else {
        // 1. Intercept, handle, and test the projectConfiguration RPC calls.
        let projectConfigExpectation = self.expectation(description: "projectConfiguration")
        rpcIssuer?.projectConfigRequester = { request in
          XCTAssertEqual(request.apiKey, PhoneAuthProviderTests.kFakeAPIKey)
          projectConfigExpectation.fulfill()
          do {
            // Response for the underlying VerifyClientRequest RPC call.
            try self.rpcIssuer?.respond(
              withJSON: ["projectId": "kFakeProjectID",
                         "authorizedDomains": [PhoneAuthProviderTests.kFakeAuthorizedDomain]]
            )
          } catch {
            XCTFail("Failure sending response: \(error)")
          }
        }
      }

      if errorURLString == nil, presenterError == nil {
        let requestExpectation = self.expectation(description: "verifyRequester")
        rpcIssuer?.verifyRequester = { request in
          XCTAssertEqual(request.phoneNumber, self.kTestPhoneNumber)
          switch request.codeIdentity {
          case let .credential(credential):
            XCTAssertFalse(reCAPTCHAfallback)
            XCTAssertEqual(credential.receipt, self.kTestReceipt)
            XCTAssertEqual(credential.secret, self.kTestSecret)
          case let .recaptcha(token):
            XCTAssertTrue(reCAPTCHAfallback)
            XCTAssertEqual(token, self.kFakeReCAPTCHAToken)
          case .empty:
            XCTAssertTrue(testMode)
          }
          requestExpectation.fulfill()
          do {
            // Response for the underlying SendVerificationCode RPC call.
            if let errorString {
              try self.rpcIssuer?.respond(serverErrorMessage: errorString)
            } else {
              try self.rpcIssuer?
                .respond(withJSON: [self.kVerificationIDKey: self.kTestVerificationID])
            }
          } catch {
            XCTFail("Failure sending response: \(error)")
          }
        }
      }
      if reCAPTCHAfallback {
        // Use fake authURLPresenter so we can test the parameters that get sent to it.
        let urlString = errorURLString ??
          PhoneAuthProviderTests.kFakeRedirectURLStringWithReCAPTCHAToken
        let errorTest = errorURLString != nil
        PhoneAuthProviderTests.auth?.authURLPresenter =
          FakePresenter(
            urlString: urlString,
            clientID: useClientID ? PhoneAuthProviderTests.kFakeClientID : nil,
            firebaseAppID: useClientID ? nil : PhoneAuthProviderTests.kFakeFirebaseAppID,
            errorTest: errorTest,
            presenterError: presenterError
          )
      }
      let uiDelegate = reCAPTCHAfallback ? FakeUIDelegate() : nil

      // 2. After setting up the parameters, call `verifyPhoneNumber`.
      provider
        .verifyPhoneNumber(kTestPhoneNumber, uiDelegate: uiDelegate) { verificationID, error in

          // 8. After the response triggers the callback in the FakePresenter, verify the callback.
          XCTAssertTrue(Thread.isMainThread)
          if errorCode != 0 {
            XCTAssertNil(verificationID)
            XCTAssertEqual((error as? NSError)?.code, errorCode)
          } else {
            XCTAssertNil(error)
            XCTAssertEqual(verificationID, self.kTestVerificationID)
          }
          expectation.fulfill()
        }
      waitForExpectations(timeout: 5)
    }

    private func initApp(_ functionName: String,
                         useClientID: Bool = false,
                         bothClientAndAppID: Bool = false,
                         testMode: Bool = false,
                         forwardingNotification: Bool = true,
                         fakeToken: Bool = false) {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.apiKey = PhoneAuthProviderTests.kFakeAPIKey
      options.projectID = "myProjectID"
      if useClientID {
        options.clientID = PhoneAuthProviderTests.kFakeClientID
      }
      if !useClientID || bothClientAndAppID {
        // Use the appID.
        options.googleAppID = PhoneAuthProviderTests.kFakeFirebaseAppID
      }
      let scheme = useClientID ? PhoneAuthProviderTests.kFakeReverseClientID :
        PhoneAuthProviderTests.kFakeEncodedFirebaseAppID

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
          settings.appVerificationDisabledForTesting = true
          auth.settings = settings
        }
        auth.notificationManager?.immediateCallbackForTestFaking = { forwardingNotification }
        auth.mainBundleUrlTypes = [["CFBundleURLSchemes": [scheme]]]

        if fakeToken {
          guard let data = "!@#$%^".data(using: .utf8) else {
            XCTFail("Failed to encode data for fake token")
            return
          }
          auth.tokenManager?.tokenStore = AuthAPNSToken(withData: data, type: .prod)
        } else {
          // Skip APNS token fetching.
          auth.tokenManager = FakeTokenManager(withApplication: UIApplication.shared)
        }
      }
    }

    class FakeTokenManager: AuthAPNSTokenManager {
      override func getTokenInternal(callback: @escaping (Result<AuthAPNSToken, Error>) -> Void) {
        let error = NSError(domain: "dummy domain", code: AuthErrorCode.missingAppToken.rawValue)
        callback(.failure(error))
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

      func present(_ presentURL: URL,
                   uiDelegate UIDelegate: AuthUIDelegate?,
                   callbackMatcher: @escaping (URL?) -> Bool,
                   completion: @escaping (URL?, Error?) -> Void) {
        // 5. Verify flow triggers present in the FakePresenter class with the right parameters.
        XCTAssertEqual(presentURL.scheme, "https")
        XCTAssertEqual(presentURL.host, kFakeAuthorizedDomain)
        XCTAssertEqual(presentURL.path, "/__/auth/handler")

        let actualURLComponents = URLComponents(url: presentURL, resolvingAgainstBaseURL: false)
        guard let _ = actualURLComponents?.queryItems else {
          XCTFail("Failed to get queryItems")
          return
        }
        let params = AuthWebUtils.dictionary(withHttpArgumentsString: presentURL.query)
        XCTAssertEqual(params["ibi"], Bundle.main.bundleIdentifier)
        XCTAssertEqual(params["apiKey"], PhoneAuthProviderTests.kFakeAPIKey)
        XCTAssertEqual(params["authType"], "verifyApp")
        XCTAssertNotNil(params["v"])
        if OAuthProviderTests.testTenantID {
          XCTAssertEqual(params["tid"], OAuthProviderTests.kFakeTenantID)
        } else {
          XCTAssertNil(params["tid"])
        }
        let appCheckToken = presentURL.fragment
        let verifyAppCheckToken = OAuthProviderTests.testAppCheck ? "fac=fakeAppCheckToken" : nil
        XCTAssertEqual(appCheckToken, verifyAppCheckToken)

        var redirectURL = ""
        if let clientID {
          XCTAssertEqual(params["clientId"], clientID)
          redirectURL = "\(kFakeReverseClientID)\(urlString)"
        }
        if let firebaseAppID {
          XCTAssertEqual(params["appId"], firebaseAppID)
          redirectURL = "\(kFakeEncodedFirebaseAppID)\(urlString)"
        }

        // 6. Test callbackMatcher
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher(URL(string: "\(redirectURL)")))

        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        guard let eventID = params["eventId"] else {
          XCTFail("Failed to get eventID")
          return
        }
        let redirectWithEventID = "\(redirectURL)%26eventId%3D\(eventID)"
        let originalComponents = URLComponents(string: redirectWithEventID)!
        XCTAssertEqual(callbackMatcher(originalComponents.url), !errorTest)

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

        // 7. Do the callback to the original call.
        kAuthGlobalWorkQueue.async {
          if let presenterError = self.presenterError {
            completion(nil, presenterError)
          } else {
            completion(URL(string: "\(kFakeEncodedFirebaseAppID)\(self.urlString)") ?? nil, nil)
          }
        }
      }

      let urlString: String
      let clientID: String?
      let firebaseAppID: String?
      let errorTest: Bool
      let presenterError: Error?

      init(urlString: String, clientID: String?, firebaseAppID: String?, errorTest: Bool,
           presenterError: Error?) {
        self.urlString = urlString
        self.clientID = clientID
        self.firebaseAppID = firebaseAppID
        self.errorTest = errorTest
        self.presenterError = presenterError
      }
    }

    private class FakeUIDelegate: NSObject, AuthUIDelegate {
      func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                   completion: (() -> Void)? = nil) {
        guard let safariController = viewControllerToPresent as? SFSafariViewController,
              let delegate = safariController.delegate as? AuthURLPresenter,
              let uiDelegate = delegate.uiDelegate as? FakeUIDelegate else {
          XCTFail("Failed to get presentURL from controller")
          return
        }
        XCTAssertEqual(self, uiDelegate)
      }

      func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        XCTFail("Implement me")
      }
    }

    private static let kFakeRedirectURLStringInvalidClientID =
      "//firebaseauth/" +
      "link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcal" +
      "lback%3FfirebaseError%3D%257B%2522code%2522%253A%2522auth%252Finvalid-oauth-client-id%2522%252" +
      "C%2522message%2522%253A%2522The%2520OAuth%2520client%2520ID%2520provided%2520is%2520either%252" +
      "0invalid%2520or%2520does%2520not%2520match%2520the%2520specified%2520API%2520key.%2522%257D%26" +
      "authType%3DverifyApp"

    private static let kFakeRedirectURLStringWebNetworkRequestFailed =
      "//firebaseauth/link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fc" +
      "allback%3FfirebaseError%3D%257B%2522code%2522%253A%2522auth%252Fnetwork-request-failed%2522%" +
      "252C%2522message%2522%253A%2522The%2520network%2520request%2520failed%2520.%2522%257D%" +
      "26authType%3DverifyApp"

    private static let kFakeRedirectURLStringWebInternalError =
      "//firebaseauth/link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcal" +
      "lback%3FfirebaseError%3D%257B%2522code%2522%253A%2522auth%252Finternal-error%2522%252C%" +
      "2522message%2522%253A%2522Internal%2520error%2520.%2522%257D%26authType%3DverifyApp"

    private static let kFakeRedirectURLStringUnknownError =
      "//firebaseauth/link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcal" +
      "lback%3FfirebaseError%3D%257B%2522code%2522%253A%2522auth%252Funknown-error-id%2522%252" +
      "C%2522message%2522%253A%2522The%2520OAuth%2520client%2520ID%2520provided%2520is%2520either%252" +
      "0invalid%2520or%2520does%2520not%2520match%2520the%2520specified%2520API%2520key.%2522%257D%26" +
      "authType%3DverifyApp"

    private static let kFakeRedirectURLStringUnstructuredError =
      "//firebaseauth/link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcal" +
      "lback%3FfirebaseError%3D%257B%2522unstructuredcode%2522%253A%2522auth%252Funknown-error-id%" +
      "2522%252" +
      "C%2522unstructuredmessage%2522%253A%2522The%2520OAuth%2520client%2520ID%2520provided%2520is%" +
      "2520either%252" +
      "0invalid%2520or%2520does%2520not%2520match%2520the%2520specified%2520API%2520key.%2522%257D%" +
      "26authType%3DverifyApp"

    private static let kFakeRedirectURLStringWithReCAPTCHAToken =
      "://firebaseauth/" +
      "link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcallback%3FauthType%" +
      "3DverifyApp%26recaptchaToken%3DfakeReCAPTCHAToken"
  }
#endif
