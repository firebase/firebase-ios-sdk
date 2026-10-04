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

import FirebaseAppCheckInterop
import FirebaseCore
internal import FirebaseCoreExtension
import FirebaseCoreInternal
import Foundation
import Testing

@Suite(.serialized)
struct FirebaseAppCheckInteropPortableTests {
  // MARK: - Test Doubles

  private struct MockAppCheckError: Error, Equatable {
    let reason: String
  }

  private struct MockTokenResult: FIRAppCheckTokenResultInterop {
    let token: String
    let error: (any Error)?
  }

  private final class MockAppCheck: AppCheckInterop {
    private static let placeholderToken = "placeholder-token"

    private let token: String
    private let error: (any Error)?
    private let lastForcingRefresh = UnfairLock<Bool?>(nil)

    init(token: String, error: (any Error)? = nil) {
      self.token = token
      self.error = error
    }

    init(error: any Error) {
      token = Self.placeholderToken
      self.error = error
    }

    var recordedForcingRefresh: Bool? {
      lastForcingRefresh.value()
    }

    func getToken(forcingRefresh: Bool) async -> any FIRAppCheckTokenResultInterop {
      lastForcingRefresh.withLock { $0 = forcingRefresh }
      return MockTokenResult(token: token, error: error)
    }

    func getLimitedUseToken() async -> any FIRAppCheckTokenResultInterop {
      MockTokenResult(token: "limited_use_\(token)", error: error)
    }

    func tokenDidChangeNotificationName() -> String {
      "FIRAppCheckAppCheckTokenDidChangeNotification"
    }

    func notificationTokenKey() -> String {
      "FIRAppCheckTokenNotificationKey"
    }

    func notificationAppNameKey() -> String {
      "FIRAppCheckAppNameNotificationKey"
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
    FirebaseComponentContainer.register(for: (any AppCheckInterop).self) { _ in
      MockAppCheck(token: "valid-fac-token")
    }
    FirebaseApp.configure(name: "appcheck-interop-app", options: options)
    let app = try #require(FirebaseApp.app(name: "appcheck-interop-app"))

    let resolved = try #require(
      ComponentType<any AppCheckInterop>.instance(
        for: (any AppCheckInterop).self,
        in: app.container
      )
    )
    let standardResult = await resolved.getToken(forcingRefresh: true)
    let limitedUseResult = await resolved.getLimitedUseToken()
    let mock = try #require(resolved as? MockAppCheck)

    #expect(standardResult.token == "valid-fac-token")
    #expect(standardResult.error == nil)
    #expect(limitedUseResult.token == "limited_use_valid-fac-token")
    #expect(limitedUseResult.error == nil)
    #expect(mock.recordedForcingRefresh == true)
    #expect(
      resolved.tokenDidChangeNotificationName()
        == "FIRAppCheckAppCheckTokenDidChangeNotification"
    )
    #expect(resolved.notificationTokenKey() == "FIRAppCheckTokenNotificationKey")
    #expect(resolved.notificationAppNameKey() == "FIRAppCheckAppNameNotificationKey")
  }

  @Test
  func errorResultCarriesPlaceholderTokenAndError() async {
    let expectedError = MockAppCheckError(reason: "attestation-failed")
    let mock = MockAppCheck(error: expectedError)

    let standardResult = await mock.getToken(forcingRefresh: false)
    let limitedUseResult = await mock.getLimitedUseToken()

    #expect(mock.recordedForcingRefresh == false)
    #expect(standardResult.token == "placeholder-token")
    #expect(standardResult.error as? MockAppCheckError == expectedError)
    #expect(limitedUseResult.token == "limited_use_placeholder-token")
    #expect(limitedUseResult.error as? MockAppCheckError == expectedError)
  }
}
