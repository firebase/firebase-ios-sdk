// Copyright 2026 Google LLC
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
import XCTest

@testable import FirebaseAuth
import FirebaseCore

class AuthPersistenceTests: RPCBaseTests {
  static let kFakeAPIKey = "FAKE_API_KEY"
  static var testNum = 0

  var app: FirebaseApp!
  var auth: Auth!

  override func setUp() {
    super.setUp()
    Auth.persistence = .inMemory

    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.apiKey = Self.kFakeAPIKey
    options.projectID = "myProjectID"
    let name = "test-AuthPersistenceTests\(Self.testNum)"
    Self.testNum += 1
    FirebaseApp.configure(name: name, options: options)
    app = FirebaseApp.app(name: name)
    // Uses the default storage, which comes from `Auth.persistence`.
    auth = Auth(app: app, backend: authBackend)
    waitForAuthGlobalWorkQueueDrain()
  }

  override func tearDown() {
    Auth.persistence = .keychain
    super.tearDown()
  }

  func testDefaultPersistenceIsKeychain() {
    Auth.persistence = .keychain
    XCTAssertTrue(Auth.persistence.keychainStorage is AuthKeychainStorageReal)
  }

  func testInMemoryPersistenceStoresSignedInUserInMemory() throws {
    try signInAnonymously()

    XCTAssertEqual(auth.currentUser?.uid, kLocalID)
    XCTAssertNotNil(try storedUserData())
  }

  func testInMemoryPersistenceRestoresUserInNewAuthInstance() throws {
    try signInAnonymously()

    let restoredAuth = Auth(app: app, backend: authBackend)
    waitForAuthGlobalWorkQueueDrain()
    XCTAssertEqual(restoredAuth.currentUser?.uid, kLocalID)
  }

  func testSignOutRemovesUserFromMemory() throws {
    try signInAnonymously()
    try auth.signOut()

    XCTAssertNil(auth.currentUser)
    XCTAssertNil(try storedUserData())
  }

  private func signInAnonymously() throws {
    let expectation = self.expectation(description: #function)
    setFakeSecureTokenService()
    setFakeGetAccountProviderAnonymous()
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                            "isNewUser": true,
                                            "refreshToken": self.kRefreshToken])
    }
    auth.signInAnonymously { _, error in
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  private func storedUserData() throws -> Data? {
    let keychain = AuthKeychainServices(service: Auth.keychainServiceName(for: app),
                                        storage: AuthInMemoryStorage.shared)
    return try keychain.data(forKey: "\(app.name)_firebase_user")
  }

  private func waitForAuthGlobalWorkQueueDrain() {
    let workerSemaphore = DispatchSemaphore(value: 0)
    kAuthGlobalWorkQueue.async {
      workerSemaphore.signal()
    }
    _ = workerSemaphore.wait(timeout: DispatchTime.distantFuture)
  }
}
