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

import FirebaseAuthInterop
import FirebaseCore
import FirebaseCoreExtension
import FirebaseCoreInternal
import Foundation
import Testing

@Suite(.serialized)
struct FirebaseAuthInteropPortableTests {
  // MARK: - Test Doubles

  private struct MockAuthError: Error, Equatable {
    let message: String
  }

  private final class MockAuth: AuthInterop {
    private let uid: String?
    private let token: String?
    private let error: (any Error)?
    private let lastForcingRefresh = UnfairLock<Bool?>(nil)

    init(uid: String?, token: String?, error: (any Error)? = nil) {
      self.uid = uid
      self.token = token
      self.error = error
    }

    var recordedForcingRefresh: Bool? {
      lastForcingRefresh.value()
    }

    func getToken(forcingRefresh: Bool) async throws -> String? {
      lastForcingRefresh.withLock { $0 = forcingRefresh }
      if let error {
        throw error
      }
      return token
    }

    func getUserID() -> String? {
      uid
    }
  }

  // MARK: - Tests

  @Test
  func containerRegistrationAndAsyncTokenLookup() async throws {
    let options = FirebaseOptions(googleAppID: "1:123:ios:abc", gcmSenderID: "123")
    defer {
      FirebaseApp.resetApps()
      FirebaseComponentContainer.removeAllRegistrations()
    }
    FirebaseComponentContainer.register(for: (any AuthInterop).self) { _ in
      MockAuth(uid: "user-123", token: "jwt-id-token")
    }
    FirebaseApp.configure(name: "auth-interop-app", options: options)
    let app = try #require(FirebaseApp.app(name: "auth-interop-app"))

    let resolved = try #require(
      ComponentType<any AuthInterop>.instance(
        for: (any AuthInterop).self,
        in: app.container
      )
    )
    let token = try await resolved.getToken(forcingRefresh: true)
    let mock = try #require(resolved as? MockAuth)

    #expect(token == "jwt-id-token")
    #expect(resolved.getUserID() == "user-123")
    #expect(mock.recordedForcingRefresh == true)
  }

  @Test
  func signedOutUserReturnsNilTokenAndNilUserID() async throws {
    let mock = MockAuth(uid: nil, token: nil)

    let token = try await mock.getToken(forcingRefresh: false)

    #expect(token == nil)
    #expect(mock.getUserID() == nil)
    #expect(mock.recordedForcingRefresh == false)
  }

  @Test
  func tokenFetchPropagatesThrownError() async {
    let expectedError = MockAuthError(message: "network-timeout")
    let failingAuth = MockAuth(uid: "user-1", token: nil, error: expectedError)

    await #expect(throws: expectedError) {
      _ = try await failingAuth.getToken(forcingRefresh: true)
    }
    #expect(failingAuth.recordedForcingRefresh == true)
  }
}
