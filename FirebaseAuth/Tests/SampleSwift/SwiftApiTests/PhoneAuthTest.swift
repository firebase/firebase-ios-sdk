//
//  PhoneAuthTest.swift
//  SwiftApiTests
//
//  Created by Srushti Vaidya on 12/08/24.
//  Copyright © 2024 Firebase. All rights reserved.
//

import FirebaseAuth
import Foundation
import XCTest

class PhoneAuthTests: TestsBase {
  let kPhoneNumber = "+19999999999"
  // This test verification code is specified for the given test phone number in the developer
  // console.
  let kVerificationCode = "777777"

  func testSignInWithPhoneNumber() throws {
    Auth.auth().settings?.isAppVerificationDisabledForTesting = true // toAdd
    let auth = Auth.auth()
    let expectation = self.expectation(description: "Sign in with phone number")

    // PhoneAuthProvider used to initiate the Verification process and obtain a verificationID.
    PhoneAuthProvider.provider()
      .verifyPhoneNumber(kPhoneNumber, uiDelegate: nil) { verificationID, error in
        if let error {
          XCTAssertNil(error, "Verification error should be nil")
          XCTAssertNotNil(verificationID, "Verification ID should not be nil")
        }

        // Create a credential using the test verification code.
        let credential = PhoneAuthProvider.provider().credential(
          withVerificationID: verificationID ?? "",
          verificationCode: self.kVerificationCode
        )
        // signs in using the credential and verifies that the user is signed in correctly by
        // checking auth.currentUser.
        auth.signIn(with: credential) { authResult, error in
          if let error {
            XCTAssertNil(error, "Sign in error should be nil")
            XCTAssertNotNil(authResult, "AuthResult should not be nil")
            XCTAssertEqual(
              auth.currentUser?.phoneNumber,
              self.kPhoneNumber,
              "Phone number does not match"
            )
          }
          expectation.fulfill()
        }
      }

    waitForExpectations(timeout: TestsBase.kExpectationsTimeout)
    // deleteCurrentUser()
  }
}
