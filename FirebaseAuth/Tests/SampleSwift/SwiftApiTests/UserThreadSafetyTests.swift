// Copyright 2024 Google LLC
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

@testable import FirebaseAuth
import FirebaseCore
import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class UserThreadSafetyTests: XCTestCase {
  // A basic user setup for testing purposes.
  private func createTestUser() throws -> User {
    let app = try XCTUnwrap(FirebaseApp.app())
    let auth = Auth(app: app)
    let tokenService = SecureTokenService(
      withRequestConfiguration: auth.requestConfiguration,
      accessToken: "testAccessToken",
      accessTokenExpirationDate: Date().addingTimeInterval(3600),
      refreshToken: "testRefreshToken"
    )
    let user = User(withTokenService: tokenService, backend: auth.backend)
    user.auth = auth
    return user
  }

  func testConcurrentProviderDataReadWrite() throws {
    let user = try createTestUser()
    let expectation = self
      .expectation(description: "Concurrent read/write on providerData should not crash")
    let dispatchGroup = DispatchGroup()
    let queue = DispatchQueue(
      label: "com.google.firebase.auth.test.concurrent",
      attributes: .concurrent
    )

    // Number of concurrent operations to perform.
    let readIterations = 500
    let writeIterations = 500

    // Dispatch concurrent reads.
    for _ in 0 ..< readIterations {
      dispatchGroup.enter()
      queue.async {
        // Read the property.
        _ = user.providerData
        dispatchGroup.leave()
      }
    }

    // Dispatch concurrent writes.
    for i in 0 ..< writeIterations {
      dispatchGroup.enter()
      queue.async {
        // Simulate a write by creating a mock response and updating the user.
        let mockProviderInfo = GetAccountInfoResponse.ProviderUserInfo(providerID: "provider-\(i)",
                                                                       displayName: nil,
                                                                       photoURL: nil,
                                                                       federatedID: nil,
                                                                       email: nil,
                                                                       rawID: nil,
                                                                       phoneNumber: nil)
        let mockUser = GetAccountInfoResponse.User(localID: "testUserID",
                                                   email: nil,
                                                   emailVerified: false,
                                                   displayName: nil,
                                                   photoURL: nil,
                                                   passwordHash: nil,
                                                   providerUserInfo: [mockProviderInfo],
                                                   creationDate: Date(),
                                                   lastLoginDate: Date(),
                                                   mfaEnrollments: nil,
                                                   phoneNumber: nil)
        let mockResponse = GetAccountInfoResponse(withUsers: [mockUser])
        user.update(withGetAccountInfoResponse: mockResponse)
        dispatchGroup.leave()
      }
    }

    // Wait for all operations to complete.
    dispatchGroup.notify(queue: .main) {
      expectation.fulfill()
    }

    // This will fail on timeout, which could indicate a deadlock.
    // The primary assertion is that no crash occurs.
    waitForExpectations(timeout: 10.0)
  }
}
