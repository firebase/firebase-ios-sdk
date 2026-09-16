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

  func testConcurrentProviderDataReadWrite() {
    let user: User
    do {
      user = try createTestUser()
    } catch {
      XCTFail("Failed to create test user: \(error)")
      return
    }
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

    // Dispatch concurrent reads and writes.
    for i in 0 ..< max(readIterations, writeIterations) {
      if i < readIterations {
        performConcurrentRead(on: user, queue: queue, dispatchGroup: dispatchGroup)
      }
      if i < writeIterations {
        performConcurrentWrite(on: user, queue: queue, dispatchGroup: dispatchGroup, iteration: i)
      }
    }

    // Wait for all operations to complete.
    let workItem = DispatchWorkItem {
      // Assert that the final state is consistent. Because writes are not ordered, we can't
      // know *which* provider is the last one, but we know there should only be one.
      XCTAssertEqual(user.providerData.count, 1)
      expectation.fulfill()
    }
    dispatchGroup.notify(queue: .main, work: workItem)

    // This will fail on timeout, which could indicate a deadlock.
    // The primary assertion is that no crash occurs.
    waitForExpectations(timeout: 10.0)
  }

  // MARK: - Helper Methods

  private func performConcurrentRead(on user: User,
                                     queue: DispatchQueue,
                                     dispatchGroup: DispatchGroup) {
    dispatchGroup.enter()
    queue.async {
      // Read the property.
      _ = user.providerData
      dispatchGroup.leave()
    }
  }

  private func performConcurrentWrite(on user: User,
                                      queue: DispatchQueue,
                                      dispatchGroup: DispatchGroup,
                                      iteration: Int) {
    dispatchGroup.enter()
    queue.async {
      defer { dispatchGroup.leave() }

      // Simulate a write by creating a mock response and updating the user.
      // This structure is based on the working unit tests for GetAccountInfoResponse.
      let providerInfo: [String: AnyHashable] = [
        "providerId": "provider-\(iteration)",
      ]

      let userInfo: [String: AnyHashable] = [
        "providerUserInfo": [providerInfo],
        "localId": "testLocalId",
        "displayName": "DisplayName",
        "email": "testEmail",
        "photoUrl": "testPhotoURL",
        "emailVerified": true,
        "passwordHash": "testPasswordHash",
      ]

      let responseDict: [String: AnyHashable] = ["users": [userInfo]]

      do {
        let mockResponse = try GetAccountInfoResponse(dictionary: responseDict)
        user.update(withGetAccountInfoResponse: mockResponse)
      } catch {
        XCTFail("Failed to create mock GetAccountInfoResponse: \(error)")
      }
    }
  }
}
