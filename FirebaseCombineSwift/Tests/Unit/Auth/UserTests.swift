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

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseCombineSwift
import Combine
import XCTest

class UserTests: XCTestCase {
  let expectationTimeout: Double = 2

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

  func testCreateUserWithEmailAndPassword() {
    let expect = expectation(description: "User created")

    let cancellable = Auth.auth()
      .createUser(withEmail: "johnnyappleseed@apple.com", password: "secret")
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          print("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        XCTAssertNotNil(authDataResult.user)
        XCTAssertEqual(authDataResult.user.email, "johnnyappleseed@apple.com")

        authDataResult.user.delete { error in
          expect.fulfill()
        }
      }

    waitForExpectations(timeout: expectationTimeout, handler: nil)
    cancellable.cancel()
  }

  let testUserEmail = "johnnyappleseed@apple.com"
  let testUserPassword = "secret"

  func testSignInUserWithEmailAndPassword() {
    var expect = expectation(description: "User created")

    var cancellables = Set<AnyCancellable>()

    Auth.auth()
      .createUser(withEmail: testUserEmail, password: testUserPassword)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          print("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        XCTAssertNotNil(authDataResult.user)
        XCTAssertEqual(authDataResult.user.email, self.testUserEmail)

        expect.fulfill()
      }
      .store(in: &cancellables)

    waitForExpectations(timeout: expectationTimeout, handler: nil)

    expect = expectation(description: "User signed in")

    Auth.auth()
      .signIn(withEmail: testUserEmail, password: testUserPassword)
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          print("💥 Something went wrong: \(error)")
        }
      } receiveValue: { authDataResult in
        XCTAssertNotNil(authDataResult.user)
        XCTAssertEqual(authDataResult.user.email, self.testUserEmail)

        authDataResult.user.delete { error in
          expect.fulfill()
        }
      }
      .store(in: &cancellables)

    waitForExpectations(timeout: expectationTimeout, handler: nil)
  }
}
