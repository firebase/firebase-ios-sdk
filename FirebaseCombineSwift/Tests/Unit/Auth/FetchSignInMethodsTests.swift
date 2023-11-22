// Copyright 2020 Google LLC
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
import Foundation
import XCTest

class FetchSignInMethodsTests: XCTestCase {
  override class func setUp() {
    FirebaseApp.configureForTests()
  }

  override class func tearDown() {
    FirebaseApp.app()?.delete { success in
      if success {
        print("Shut down app successfully.")
      } else {
        print("💥 There was a problem when shutting down the app..")
      }
    }
  }

  override func setUp() {
    do {
      try Auth.auth().signOut()
    } catch {}
  }

  static let apiKey = Credentials.apiKey
  static let email = "johnnyappleseed@apple.com"

  static let emailLinkAuthSignInMethod = "emailLink"
  static let facebookAuthSignInMethod = "facebook.com"

  static let allSignInMethods = [
    FetchSignInMethodsTests.emailLinkAuthSignInMethod,
    FetchSignInMethodsTests.facebookAuthSignInMethod,
  ]

  class MockCreateAuthURIResponse: FIRCreateAuthURIResponse {
    override var signinMethods: [String]? { return FetchSignInMethodsTests.allSignInMethods }
  }

  class MockAuthBackend: AuthBackendImplementationMock {
    override func createAuthURI(_ request: FIRCreateAuthURIRequest,
                                callback: @escaping FIRCreateAuthURIResponseCallback) {
      XCTAssertEqual(request.identifier, FetchSignInMethodsTests.email)
      XCTAssertNotNil(request.endpoint)
      XCTAssertEqual(request.apiKey, FetchSignInMethodsTests.apiKey)

      callback(MockCreateAuthURIResponse(), nil)
    }
  }

  func testFetchSignInMethodsForEmail() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())
    var cancellables = Set<AnyCancellable>()
    let fetchSignInMethodsExpectation = expectation(description: "Fetched Sign-in methods")

    // when
    Auth.auth()
      .fetchSignInMethods(forEmail: FetchSignInMethodsTests.email)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { signInMethods in
        XCTAssertEqual(signInMethods, FetchSignInMethodsTests.allSignInMethods)

        fetchSignInMethodsExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [fetchSignInMethodsExpectation], timeout: expectationTimeout)
  }
}
