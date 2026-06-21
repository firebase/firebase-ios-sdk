/*
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import FirebaseAuth
import Foundation
import XCTest

class PhoneAuthTests: TestsBase {
  let phoneNumber = "+12345678910"
  // This test verification code is specified for the given test phone number in the developer
  // console.
  let verificationCode = "123456"

  func testSignInWithPhoneNumber() throws {
    Auth.auth().settings?.isAppVerificationDisabledForTesting = true
    let auth = Auth.auth()
    let expectation = self.expectation(description: "Sign in with phone number")

    // PhoneAuthProvider used to initiate the Verification process and obtain a verificationID.
    PhoneAuthProvider.provider()
      .verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
        if let error {
          XCTAssertNil(error, "Verification error should be nil")
          XCTAssertNotNil(verificationID, "Verification ID should not be nil")
        }

        // Create a credential using the test verification code.
        let credential = PhoneAuthProvider.provider().credential(
          withVerificationID: verificationID ?? "",
          verificationCode: self.verificationCode
        )
        // Signs in using the credential and verifies that the user is signed in correctly by
        // checking auth.currentUser.
        auth.signIn(with: credential) { authResult, error in
          if let error {
            XCTAssertNil(error, "Sign in error should be nil")
            XCTAssertNotNil(authResult, "AuthResult should not be nil")
            XCTAssertEqual(
              auth.currentUser?.phoneNumber,
              self.phoneNumber,
              "Phone number does not match"
            )
          }
          expectation.fulfill()
        }
      }

    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)
  }

  func testSignInWithPhoneNumberAsync_Success() async throws {
    Auth.auth().settings?.isAppVerificationDisabledForTesting = true
    let auth = Auth.auth()

    // Start phone number verification
    let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(
      phoneNumber,
      uiDelegate: nil
    )
    XCTAssertNotNil(verificationID, "Expected a verification ID")

    // Create the phone auth credential
    let credential = PhoneAuthProvider.provider().credential(
      withVerificationID: verificationID,
      verificationCode: verificationCode
    )

    // Sign in with the credential
    let authResult = try await auth.signIn(with: credential)
    XCTAssertNotNil(authResult, "Expected a non-nil AuthResult")
    XCTAssertEqual(auth.currentUser?.phoneNumber, phoneNumber, "Phone number does not match")
  }
}
