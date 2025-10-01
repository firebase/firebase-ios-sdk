// Copyright 2025 Google LLC
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

@available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *)
class AuthStateChangesAsyncTests: RPCBaseTests {
  var auth: Auth!
  static var testNum = 0

  override func setUp() {
    super.setUp()
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.apiKey = "FAKE_API_KEY"
    options.projectID = "myProjectID"
    let name = "test-AuthStateChangesAsyncTests\(AuthStateChangesAsyncTests.testNum)"
    AuthStateChangesAsyncTests.testNum += 1

    FirebaseApp.configure(name: name, options: options)
    let app = FirebaseApp.app(name: name)!

    #if (os(macOS) && !FIREBASE_AUTH_TESTING_USE_MACOS_KEYCHAIN) || SWIFT_PACKAGE
      let keychainStorageProvider = FakeAuthKeychainStorage()
    #else
      let keychainStorageProvider = AuthKeychainStorageReal.shared
    #endif

    auth = Auth(
      app: app,
      keychainStorageProvider: keychainStorageProvider,
      backend: authBackend
    )

    waitForAuthGlobalWorkQueueDrain()
  }

  override func tearDown() {
    auth = nil
    FirebaseApp.resetApps()
    super.tearDown()
  }

  private func waitForAuthGlobalWorkQueueDrain() {
    let workerSemaphore = DispatchSemaphore(value: 0)
    kAuthGlobalWorkQueue.async {
      workerSemaphore.signal()
    }
    _ = workerSemaphore.wait(timeout: DispatchTime.distantFuture)
  }

  @available(iOS 18.0, *)
  func testAuthStateChangesStreamYieldsUserOnSignIn() async throws {
    // Given
    let initialNilExpectation = expectation(description: "Stream should emit initial nil user")
    let signInExpectation = expectation(description: "Stream should emit signed-in user")
    try? auth.signOut()

    var iteration = 0
    let task = Task {
      for await user in auth.authStateChanges {
        if iteration == 0 {
          XCTAssertNil(user, "The initial user should be nil")
          initialNilExpectation.fulfill()
        } else if iteration == 1 {
          XCTAssertNotNil(user, "The stream should yield the new user")
          XCTAssertEqual(user?.uid, kLocalID)
          signInExpectation.fulfill()
        }
        iteration += 1
      }
    }

    // Wait for the initial nil value to be emitted before proceeding.
    await fulfillment(of: [initialNilExpectation], timeout: 1.0)

    // When
    // A user is signed in.
    setFakeGetAccountProviderAnonymous()
    setFakeSecureTokenService()
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(withJSON: ["idToken": "TEST_ACCESS_TOKEN",
                                            "refreshToken": self.kRefreshToken,
                                            "isNewUser": true])
    }
    _ = try await auth.signInAnonymously()

    // Then
    // The stream should emit the new, signed-in user.
    await fulfillment(of: [signInExpectation], timeout: 2.0)
    task.cancel()
  }

  @available(iOS 18.0, *)
  func testAuthStateChangesStreamIsCancelled() async throws {
    // Given: An inverted expectation that will fail the test if it's fulfilled.
    let streamCancelledExpectation =
      expectation(description: "Stream should not emit a value after cancellation")
    streamCancelledExpectation.isInverted = true
    try? auth.signOut()

    var iteration = 0
    let task = Task {
      for await _ in auth.authStateChanges {
        if iteration > 0 {
          // This line should not be reached. If it is, the inverted expectation will be
          // fulfilled, and the test will fail as intended.
          streamCancelledExpectation.fulfill()
        }
        iteration += 1
      }
    }

    // Let the stream emit its initial `nil` value.
    try await Task.sleep(nanoseconds: 200_000_000)

    // When: The listening task is cancelled.
    task.cancel()

    // And an attempt is made to trigger another update.
    setFakeGetAccountProviderAnonymous()
    setFakeSecureTokenService()
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(withJSON: ["idToken": "TEST_ACCESS_TOKEN",
                                            "refreshToken": self.kRefreshToken,
                                            "isNewUser": true])
    }
    _ = try? await auth.signInAnonymously()

    // Then: Wait for a period to ensure the inverted expectation is not fulfilled.
    await fulfillment(of: [streamCancelledExpectation], timeout: 1.0)

    // And explicitly check that the loop only ever ran once.
    XCTAssertEqual(iteration, 1, "The stream should have only emitted its initial value.")
  }

  @available(iOS 18.0, *)
  func testAuthStateChangesStreamYieldsNilOnSignOut() async throws {
    // Given
    let initialNilExpectation = expectation(description: "Stream should emit initial nil user")
    let signInExpectation = expectation(description: "Stream should emit signed-in user")
    let signOutExpectation = expectation(description: "Stream should emit nil after sign-out")
    try? auth.signOut()

    var iteration = 0
    let task = Task {
      for await user in auth.authStateChanges {
        switch iteration {
        case 0:
          XCTAssertNil(user, "The initial user should be nil")
          initialNilExpectation.fulfill()
        case 1:
          XCTAssertNotNil(user, "The stream should yield the signed-in user")
          signInExpectation.fulfill()
        case 2:
          XCTAssertNil(user, "The stream should yield nil after sign-out")
          signOutExpectation.fulfill()
        default:
          XCTFail("The stream should not have emitted more than three values.")
        }
        iteration += 1
      }
    }

    // Wait for the initial nil value.
    await fulfillment(of: [initialNilExpectation], timeout: 1.0)

    // Sign in a user.
    setFakeGetAccountProviderAnonymous()
    setFakeSecureTokenService()
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(withJSON: ["idToken": "TEST_ACCESS_TOKEN",
                                            "refreshToken": self.kRefreshToken,
                                            "isNewUser": true])
    }
    _ = try await auth.signInAnonymously()
    await fulfillment(of: [signInExpectation], timeout: 2.0)

    // When
    try auth.signOut()

    // Then
    await fulfillment(of: [signOutExpectation], timeout: 2.0)
    task.cancel()
  }
}
