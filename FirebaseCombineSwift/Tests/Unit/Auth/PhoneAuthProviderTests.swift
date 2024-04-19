// Copyright 2021 Google LLC
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

import Combine
import FirebaseAuth
import FirebaseAuthTestingSupport
import Foundation
import XCTest

class PhoneAuthProviderTests: XCTestCase {
  fileprivate static let phoneNumber = "55555555"
  fileprivate static let invalidPhoneNumber = "555+!*55555"
  fileprivate static let verificationID = "verificationID"

  func testVerifyEmptyPhoneNumber() {
    // given
    let provider = PhoneAuthProviderFake()
    var cancellables = Set<AnyCancellable>()
    provider.verifyPhoneNumberHandler = { completion in
      completion(nil, FIRAuthErrorUtils.missingPhoneNumberError(withMessage: ""))
    }

    // Empty phone number is checked on the client side so no backend RPC is mocked.
    let expectation = self.expectation(description: #function)

    // When
    provider.verifyPhoneNumber("", uiDelegate: nil)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.missingPhoneNumber.rawValue)

          expectation.fulfill()
        }
      } receiveValue: { verificationID in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [expectation], timeout: expectationTimeout)
  }

  func testVerifyInvalidPhoneNumber() {
    // given
    let provider = PhoneAuthProviderFake()
    var cancellables = Set<AnyCancellable>()
    provider.verifyPhoneNumberHandler = { completion in
      completion(nil, FIRAuthErrorUtils.invalidPhoneNumberError(withMessage: ""))
    }

    let expectation = self.expectation(description: #function)

    // When
    provider.verifyPhoneNumber(Self.invalidPhoneNumber, uiDelegate: nil)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.invalidPhoneNumber.rawValue)

          expectation.fulfill()
        }
      } receiveValue: { verificationID in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [expectation], timeout: expectationTimeout)
  }

  func testVerifyPhoneNumber() {
    // given
    let provider = PhoneAuthProviderFake()
    var cancellables = Set<AnyCancellable>()
    provider.verifyPhoneNumberHandler = { completion in
      completion(Self.verificationID, nil)
    }

    let expectation = self.expectation(description: #function)

    // When
    provider.verifyPhoneNumber(Self.phoneNumber, uiDelegate: nil)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { verificationID in
        XCTAssertEqual(verificationID, Self.verificationID)

        expectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [expectation], timeout: expectationTimeout)
  }

  func testVerifyPhoneNumberInTestModeFailure() {
    // given
    let provider = PhoneAuthProviderFake()
    var cancellables = Set<AnyCancellable>()
    provider.verifyPhoneNumberHandler = { completion in
      let underlyingError = NSError(domain: "Test Error", code: 1, userInfo: nil)
      completion(nil, FIRAuthErrorUtils.networkError(withUnderlyingError: underlyingError))
    }

    let expectation = self.expectation(description: #function)

    // When
    provider.verifyPhoneNumber(Self.phoneNumber, uiDelegate: nil)
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.networkError.rawValue)

          expectation.fulfill()
        }
      } receiveValue: { verificationID in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [expectation], timeout: expectationTimeout)
  }
}
