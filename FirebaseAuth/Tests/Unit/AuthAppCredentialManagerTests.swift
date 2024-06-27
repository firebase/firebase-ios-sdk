// Copyright 2023 Google LLC
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

#if !os(macOS)
  import Foundation
  import XCTest

  @testable import FirebaseAuth

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthAppCredentialManagerTests: XCTestCase {
    let kReceipt = "FAKE_RECEIPT"
    let kVerificationTimeout = 1.0
    let kSecret = "FAKE_SECRET"
    let kAnotherReceipt = "OTHER_RECEIPT"
    let kAnotherSecret = "OTHER_SECRET"

    /** @fn testCompletion
        @brief Tests a successfully completed verification flow.
     */
    func testCompletion() {
      let fakeKeychain = AuthKeychainServices(
        service: "AuthAppCredentialManagerTests",
        storage: FakeAuthKeychainStorage()
      )
      let manager = AuthAppCredentialManager(withKeychain: fakeKeychain)
      XCTAssertNil(manager.credential)

      // Start verification.
      let expectation = self.expectation(description: #function)
      manager.didStartVerificationInternal(withReceipt: kReceipt,
                                           timeout: kVerificationTimeout) { [self] credential in
        XCTAssertEqual(credential.receipt, self.kReceipt)
        XCTAssertEqual(credential.secret, self.kSecret)
        expectation.fulfill()
      }
      XCTAssertNil(manager.credential)

      // Mismatched receipt shouldn't finish verification.
      XCTAssertFalse(manager
        .canFinishVerification(withReceipt: kAnotherReceipt, secret: kAnotherSecret))
      XCTAssertNil(manager.credential)

      // Finish verification.
      XCTAssertTrue(manager.canFinishVerification(withReceipt: kReceipt, secret: kSecret))
      waitForExpectations(timeout: 5)
      XCTAssertEqual(manager.credential?.receipt, kReceipt)
      XCTAssertEqual(manager.credential?.secret, kSecret)

      // Repeated receipt should have no effect.
      XCTAssertFalse(manager.canFinishVerification(withReceipt: kReceipt, secret: kSecret))
      XCTAssertEqual(manager.credential?.secret, kSecret)
    }

    /** @fn testTimeout
        @brief Tests a verification flow that times out.
     */
    func testTimeout() {
      let fakeKeychain = AuthKeychainServices(
        service: "AuthAppCredentialManagerTests",
        storage: FakeAuthKeychainStorage()
      )
      let manager = AuthAppCredentialManager(withKeychain: fakeKeychain)
      XCTAssertNil(manager.credential)

      // Start verification.
      let expectation = self.expectation(description: #function)
      manager.didStartVerificationInternal(withReceipt: kReceipt,
                                           timeout: kVerificationTimeout) { [self] credential in
        XCTAssertEqual(credential.receipt, self.kReceipt)
        XCTAssertNil(credential.secret) // different from test above.
        expectation.fulfill()
      }
      XCTAssertNil(manager.credential)

      // Timeout
      waitForExpectations(timeout: 5)

      // Finish verification.
      XCTAssertTrue(manager.canFinishVerification(withReceipt: kReceipt, secret: kSecret))
      XCTAssertEqual(manager.credential?.receipt, kReceipt)
      XCTAssertEqual(manager.credential?.secret, kSecret)
    }

    /** @fn testMaximumPendingReceipt
        @brief Tests the maximum allowed number of pending receipt.
     */
    func testMaximumPendingReceipt() {
      let fakeKeychain = AuthKeychainServices(
        service: "AuthAppCredentialManagerTests",
        storage: FakeAuthKeychainStorage()
      )
      let manager = AuthAppCredentialManager(withKeychain: fakeKeychain)
      XCTAssertNil(manager.credential)

      // Start verification.
      let expectation = self.expectation(description: #function)
      manager.didStartVerificationInternal(withReceipt: kReceipt,
                                           timeout: kVerificationTimeout) { [self] credential in
        XCTAssertEqual(credential.receipt, self.kReceipt)
        XCTAssertEqual(credential.secret, self.kSecret)
        expectation.fulfill()
      }
      XCTAssertNil(manager.credential)

      // Start verification of a number of random receipts without overflowing.
      for i in 1 ... (manager.maximumNumberOfPendingReceipts - 1) {
        let randomReceipt = "RANDOM_\(i)"
        let randomExpectation = self.expectation(description: randomReceipt)
        manager.didStartVerificationInternal(withReceipt: randomReceipt,
                                             timeout: kVerificationTimeout) { credential in
          // They all should get full credential because one is
          // available at this point.
          XCTAssertEqual(credential.receipt, self.kReceipt)
          XCTAssertEqual(credential.secret, self.kSecret)
          randomExpectation.fulfill()
        }
      }
      // Finish verification of target receipt.
      XCTAssertTrue(manager.canFinishVerification(withReceipt: kReceipt, secret: kSecret))
      waitForExpectations(timeout: 5)
      XCTAssertEqual(manager.credential?.receipt, kReceipt)
      XCTAssertEqual(manager.credential?.secret, kSecret)

      // Clear credential to prepare for next round.
      manager.clearCredential()
      XCTAssertNil(manager.credential)

      // Start verification of another target receipt.
      let anotherExpectation = self.expectation(description: "another")
      manager.didStartVerificationInternal(withReceipt: kAnotherReceipt,
                                           timeout: kVerificationTimeout) { [self] credential in
        XCTAssertEqual(credential.receipt, self.kAnotherReceipt)
        XCTAssertNil(credential.secret)
        anotherExpectation.fulfill()
      }
      XCTAssertNil(manager.credential)

      // Start verification of a number of random receipts to overflow.
      for i in 1 ... manager.maximumNumberOfPendingReceipts {
        let randomReceipt = "RANDOM_\(i)"
        let randomExpectation = self.expectation(description: randomReceipt)
        manager.didStartVerificationInternal(withReceipt: randomReceipt,
                                             timeout: kVerificationTimeout) { credential in
          // They all should get partial credential because verification
          // has never completed.
          XCTAssertEqual(credential.receipt, randomReceipt)
          XCTAssertNil(credential.secret)
          randomExpectation.fulfill()
        }
      }
      // Finish verification of the other target receipt.
      XCTAssertFalse(manager
        .canFinishVerification(withReceipt: kAnotherReceipt, secret: kAnotherSecret))
      waitForExpectations(timeout: 5)
      XCTAssertNil(manager.credential)
    }

    /** @fn testKeychain
        @brief Tests state preservation in the keychain.
     */
    func testKeychain() {
      let fakeKeychain = AuthKeychainServices(
        service: "AuthAppCredentialManagerTests",
        storage: FakeAuthKeychainStorage()
      )
      let manager = AuthAppCredentialManager(withKeychain: fakeKeychain)
      XCTAssertNil(manager.credential)

      // Start verification.
      let expectation = self.expectation(description: #function)
      manager.didStartVerificationInternal(withReceipt: kReceipt,
                                           timeout: kVerificationTimeout) { [self] credential in
        XCTAssertEqual(credential.receipt, self.kReceipt)
        XCTAssertNil(credential.secret)
        expectation.fulfill()
      }
      XCTAssertNil(manager.credential)

      // Timeout
      waitForExpectations(timeout: 5)

      // Start a new manager with saved data in keychain.
      let manager2 = AuthAppCredentialManager(withKeychain: fakeKeychain)
      XCTAssertNil(manager2.credential)

      // Finish verification.
      XCTAssertTrue(manager2.canFinishVerification(withReceipt: kReceipt, secret: kSecret))
      XCTAssertEqual(manager2.credential?.receipt, kReceipt)
      XCTAssertEqual(manager2.credential?.secret, kSecret)

      // Start yet another new manager with saved data in keychain.
      let manager3 = AuthAppCredentialManager(withKeychain: fakeKeychain)
      XCTAssertNotNil(manager3.credential)
      XCTAssertEqual(manager3.credential?.receipt, kReceipt)
      XCTAssertEqual(manager3.credential?.secret, kSecret)
    }
  }
#endif
