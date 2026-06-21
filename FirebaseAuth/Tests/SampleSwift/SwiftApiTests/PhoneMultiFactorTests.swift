/*
 * Copyright 2019 Google
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
import XCTest

let kNoSecondFactorUserEmail = "iosapitests+no_second_factor@gmail.com"
let kNoSecondFactorUserPassword = "aaaaaa"

let kPhoneSecondFactorPhoneNumber = "+16509999999"
let kPhoneSecondFactorVerificationCode = "123456"
let kPhoneSecondFactorDisplayName = "phone1"

let kOneSecondFactorUserEmail = "iosapitests+one_phone_second_factor@gmail.com"
let kOneSecondFactorUserPassword = "aaaaaa"

// TODO: Restore these tests that haven't been built or run for years before Swift conversion.

class PhoneMultiFactorTests: TestsBase {
  func SKIPtestEnrollUnenroll() {
    let enrollExpectation = expectation(description: "Enroll phone multi factor finished.")
    let unenrollExpectation = expectation(description: "Unenroll phone multi factor finished.")
    Auth.auth()
      .signIn(withEmail: kNoSecondFactorUserEmail,
              password: kNoSecondFactorUserPassword) { result, error in
        XCTAssertNil(error, "User normal sign in failed. Error: \(error!.localizedDescription)")

        // Enroll
        guard let user = result?.user else {
          XCTFail("No valid user after attempted sign-in.")
          return
        }
        user.multiFactor.getSessionWithCompletion { session, error in
          XCTAssertNil(error,
                       "Get multi factor session failed. Error: \(error!.localizedDescription)")
          PhoneAuthProvider.provider().verifyPhoneNumber(
            kPhoneSecondFactorPhoneNumber,
            uiDelegate: nil,
            multiFactorSession: session
          ) { verificationId, error in
            XCTAssertNil(error, "Verify phone number failed. Error: \(error!.localizedDescription)")
            let credential = PhoneAuthProvider.provider().credential(
              withVerificationID: verificationId!,
              verificationCode: kPhoneSecondFactorVerificationCode
            )
            let assertion = PhoneMultiFactorGenerator.assertion(with: credential)
            user.multiFactor
              .enroll(with: assertion, displayName: kPhoneSecondFactorDisplayName) { error in
                XCTAssertNil(error,
                             "Phone multi factor enroll failed. Error: \(error!.localizedDescription)")
                XCTAssertEqual(
                  Auth.auth().currentUser?.multiFactor.enrolledFactors.first?.displayName,
                  kPhoneSecondFactorDisplayName
                )
                enrollExpectation.fulfill()

                // Unenroll
                XCTAssertEqual(user, Auth.auth().currentUser)
                user.multiFactor
                  .unenroll(with: (user.multiFactor.enrolledFactors.first)!, completion: { error in
                    XCTAssertNil(error,
                                 "Phone multi factor unenroll failed. Error: \(error!.localizedDescription)")
                    XCTAssertEqual(Auth.auth().currentUser?.multiFactor.enrolledFactors.count, 0)
                    unenrollExpectation.fulfill()
                  })
              }
          }
        }
      }

    waitForExpectations(timeout: 30) { error in
      XCTAssertNil(error,
                   "Failed to wait for enroll and unenroll phone multi factor finished. Error: \(error!.localizedDescription)")
    }
  }

  func SKIPtestSignInWithSecondFactor() {
    let signInExpectation = expectation(description: "Sign in with phone multi factor finished.")
    Auth.auth()
      .signIn(withEmail: kOneSecondFactorUserEmail,
              password: kOneSecondFactorUserPassword) { result, error in
        // SignIn
        guard let error = error as? NSError,
              error.code == AuthErrorCode.secondFactorRequired.rawValue else {
          XCTFail("User sign in returns wrong error. Error: \(error!.localizedDescription)")
          return
        }
        let resolver = error
          .userInfo["FIRAuthErrorUserInfoMultiFactorResolverKey"] as! MultiFactorResolver
        let hint = resolver.hints.first as! PhoneMultiFactorInfo
        PhoneAuthProvider.provider().verifyPhoneNumber(
          with: hint,
          uiDelegate: nil,
          multiFactorSession: resolver.session
        ) { verificationId, error in
          XCTAssertNil(error,
                       "Failed to verify phone number. Error: \(error!.localizedDescription)")
          let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationId!,
            verificationCode: kPhoneSecondFactorVerificationCode
          )
          let assertion = PhoneMultiFactorGenerator.assertion(with: credential)
          resolver.resolveSignIn(with: assertion) { authResult, error in
            XCTAssertNil(error,
                         "Failed to sign in with phone multi factor. Error: \(error!.localizedDescription)")
            signInExpectation.fulfill()
          }
        }
      }

    waitForExpectations(timeout: 300) { error in
      XCTAssertNil(error,
                   "Failed to wait for enroll and unenroll phone multi factor finished. Error: \(error!.localizedDescription)")
    }
  }
}
