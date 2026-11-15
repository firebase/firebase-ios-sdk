// Copyright 2022 Google LLC
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
import FirebaseAuthInterop
import FirebaseCore
@testable import FirebaseStorage
import Foundation
import SharedTestUtilities
import XCTest

private final class ParallelCallbackBarrier: @unchecked Sendable {
  private let lock = NSLock()
  private var callbackCount = 0
  private let callbacksReady = DispatchSemaphore(value: 0)
  private let resumeCallbacks = DispatchSemaphore(value: 0)

  func waitForRelease() {
    lock.lock()
    callbackCount += 1
    if callbackCount == 2 {
      callbacksReady.signal()
    }
    lock.unlock()
    if resumeCallbacks.wait(timeout: .now() + 2) == .timedOut {
      XCTFail("Timed out waiting for token callbacks to be released")
    }
  }

  func resumeBoth() {
    if callbacksReady.wait(timeout: .now() + 2) == .timedOut {
      XCTFail("Timed out waiting for both token callbacks")
    }
    resumeCallbacks.signal()
    resumeCallbacks.signal()
  }
}

private final class ConcurrentAuthInteropFake: NSObject, AuthInterop, @unchecked Sendable {
  let barrier: ParallelCallbackBarrier

  init(barrier: ParallelCallbackBarrier) {
    self.barrier = barrier
  }

  func getToken(forcingRefresh: Bool, completion handler: @escaping (String?, Error?) -> Void) {
    DispatchQueue.global().async {
      self.barrier.waitForRelease()
      handler("auth-token", nil)
    }
  }

  func getUserID() -> String? { nil }
}

private final class ConcurrentAppCheckTokenResult: NSObject, FIRAppCheckTokenResultInterop,
  @unchecked Sendable {
  let token = "app-check-token"
  let error: Error? = nil
}

private final class ConcurrentAppCheckInteropFake: NSObject, AppCheckInterop, @unchecked Sendable {
  let barrier: ParallelCallbackBarrier

  init(barrier: ParallelCallbackBarrier) {
    self.barrier = barrier
  }

  func getToken(forcingRefresh: Bool, completion handler: @escaping AppCheckTokenHandlerInterop) {
    DispatchQueue.global().async {
      self.barrier.waitForRelease()
      handler(ConcurrentAppCheckTokenResult())
    }
  }

  func tokenDidChangeNotificationName() -> String { "AppCheckTokenDidChange" }
  func notificationTokenKey() -> String { "AppCheckToken" }
  func notificationAppNameKey() -> String { "AppName" }
}

class StorageAuthorizerTests: StorageTestHelpers {
  var appCheckTokenSuccess: FIRAppCheckTokenResultFake!
  var appCheckTokenError: FIRAppCheckTokenResultFake!
  var authorizer: StorageTokenAuthorizer!
  var auth: FIRAuthInteropFake!
  var appCheck: FIRAppCheckFake!

  let StorageTestAuthToken = "1234-5678-9012-3456-7890"

  override func setUp() {
    super.setUp()

    appCheckTokenSuccess = FIRAppCheckTokenResultFake(token: "token", error: nil)
    appCheckTokenError = FIRAppCheckTokenResultFake(token: "dummy token",
                                                    error: NSError(
                                                      domain: "testAppCheckError",
                                                      code: -1,
                                                      userInfo: nil
                                                    ))

    auth = FIRAuthInteropFake(token: StorageTestAuthToken, userID: nil, error: nil)
    appCheck = FIRAppCheckFake()
    authorizer = StorageTokenAuthorizer(googleAppID: "dummyAppID", authProvider: auth,
                                        appCheck: appCheck)
  }

  override func tearDown() {
    authorizer = nil
    auth = nil
    appCheck = nil
    appCheckTokenSuccess = nil
    super.tearDown()
  }

  func testSuccessfulAuth() async throws {
    let request = try await authorizer.authorize(URLRequest(url: objectURL()))
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"),
                   "Firebase \(StorageTestAuthToken)")
  }

  func testUnsuccessfulAuth() async {
    let authError = NSError(domain: "FIRStorageErrorDomain",
                            code: StorageErrorCode.unauthenticated.rawValue, userInfo: nil)
    let failedAuth = FIRAuthInteropFake(token: nil, userID: nil, error: authError)
    authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: failedAuth,
      appCheck: nil
    )
    do {
      _ = try await authorizer.authorize(URLRequest(url: objectURL()))
      XCTFail("Expected an error")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, "FIRStorageErrorDomain")
      XCTAssertEqual(nsError.code, StorageErrorCode.unauthenticated.rawValue)
      XCTAssertEqual(nsError.localizedDescription, "User is not authenticated, please " +
        "authenticate using Firebase Authentication and try again.")
    }
  }

  func testSuccessfulUnauthenticatedAuth() async throws {
    // Simulate Auth not being included at all
    authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: nil,
      appCheck: nil
    )

    let request = try await authorizer.authorize(URLRequest(url: objectURL()))
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
  }

  func testSuccessfulAppCheckNoAuth() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!

    // Simulate Auth not being included at all
    authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: nil,
      appCheck: appCheck
    )

    let request = try await authorizer.authorize(URLRequest(url: objectURL()))
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"),
                   appCheckTokenSuccess?.token)
  }

  func testSuccessfulAppCheckAndAuth() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!

    let request = try await authorizer.authorize(URLRequest(url: objectURL()))
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"),
                   "Firebase \(StorageTestAuthToken)")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"),
                   appCheckTokenSuccess?.token)
  }

  func testAuthAndAppCheckTokensAreRequestedAtTheSameTime() async throws {
    let barrier = ParallelCallbackBarrier()
    let authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: ConcurrentAuthInteropFake(barrier: barrier),
      appCheck: ConcurrentAppCheckInteropFake(barrier: barrier)
    )
    // Each token callback waits until both have been requested.
    DispatchQueue.global().async {
      barrier.resumeBoth()
    }

    let request = try await authorizer.authorize(
      URLRequest(url: URL(string: "https://storage.googleapis.com/v0/b/bucket/o/object")!)
    )

    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Firebase auth-token")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"), "app-check-token")
  }

  func testAppCheckError() async throws {
    appCheck?.tokenResult = appCheckTokenError!

    let request = try await authorizer.authorize(URLRequest(url: objectURL()))
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"),
                   "Firebase \(StorageTestAuthToken)")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"),
                   appCheckTokenError?.token)
  }

  func testInsecureHostFailsWhenTokensPresent() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!
    await assertAuthorizationFails(
      of: URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!),
      authProvider: auth, appCheck: appCheck
    )
  }

  func testInsecureHostSucceedsWhenNoTokensPresent() async throws {
    let authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: nil,
      appCheck: nil
    )

    let request = try await authorizer.authorize(
      URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!)
    )
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    XCTAssertNil(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"))
  }

  func testInsecureHostSucceedsWhenAuthProviderIsPresentButUserSignedOut() async throws {
    let unauthenticatedAuthFake = FIRAuthInteropFake(token: nil, userID: nil, error: nil)
    let authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: unauthenticatedAuthFake,
      appCheck: nil
    )

    let request = try await authorizer.authorize(
      URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!)
    )
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    XCTAssertNil(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"))
  }

  func testLocalhostDoesAttachTokensOverHttp() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!

    let request = try await authorizer.authorize(
      URLRequest(url: URL(string: "http://localhost/v0/b/bucket/o/object")!)
    )
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"),
                   "Firebase \(StorageTestAuthToken)")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"),
                   appCheckTokenSuccess?.token)
  }

  func testDynamicAllowInsecureTokenAttachment() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!
    var allowInsecure = false
    let authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: auth,
      appCheck: appCheck,
      allowInsecureTokenAttachment: { allowInsecure }
    )

    // Update allowInsecure to true after authorizer has been initialized
    allowInsecure = true

    let request = try await authorizer.authorize(
      URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!)
    )
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"),
                   "Firebase \(StorageTestAuthToken)")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"),
                   appCheckTokenSuccess?.token)
  }

  func testInsecureHostFailsWhenOnlyAppCheckTokenIsPresent() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!
    await assertAuthorizationFails(
      of: URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!),
      authProvider: nil, appCheck: appCheck
    )
  }

  func testInsecureHostFailsWhenOnlyAuthTokenIsPresent() async throws {
    await assertAuthorizationFails(
      of: URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!),
      authProvider: auth, appCheck: nil
    )
  }

  // MARK: authorize(_:)

  func testAuthorizeAddsTheStorageHeaders() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!
    let authorizer = StorageTokenAuthorizer(googleAppID: "dummyAppID", authProvider: auth,
                                            appCheck: appCheck)

    let request = try await authorizer.authorize(URLRequest(url: objectURL()))

    XCTAssertEqual(request.value(forHTTPHeaderField: "x-firebase-storage-version"),
                   "ios/\(FirebaseVersion())")
    XCTAssertEqual(request.value(forHTTPHeaderField: "x-firebase-gmpid"), "dummyAppID")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"),
                   "Firebase \(StorageTestAuthToken)")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"),
                   appCheckTokenSuccess?.token)
  }

  func testAuthorizeSendsTheAppCheckPlaceholderTokenWhenAppCheckFails() async throws {
    appCheck?.tokenResult = appCheckTokenError!
    let authorizer = StorageTokenAuthorizer(googleAppID: "dummyAppID", authProvider: nil,
                                            appCheck: appCheck)

    let request = try await authorizer.authorize(URLRequest(url: objectURL()))

    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"), "dummy token")
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
  }

  func testAuthorizeReportsAuthErrors() async {
    let authError = NSError(domain: "AuthErrorDomain", code: 17020, userInfo: ["key": "value"])
    let authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: FIRAuthInteropFake(token: nil, userID: nil, error: authError),
      appCheck: nil
    )

    do {
      _ = try await authorizer.authorize(URLRequest(url: objectURL()))
      XCTFail("Expected an error")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, StorageErrorDomain)
      XCTAssertEqual(nsError.code, StorageErrorCode.unauthenticated.rawValue)
      XCTAssertEqual(nsError.userInfo["ResponseErrorDomain"] as? String, "AuthErrorDomain")
      XCTAssertEqual(nsError.userInfo["ResponseErrorCode"] as? Int, 17020)
      XCTAssertEqual(nsError.userInfo["key"] as? String, "value")
    }
  }

  // MARK: Helpers

  /// Asserts that authorizing `request` fails with `StorageErrorCode.unauthenticated`, because
  /// it would send tokens over HTTP to a host that isn't a loopback address.
  private func assertAuthorizationFails(of request: URLRequest,
                                        authProvider: AuthInterop?,
                                        appCheck: AppCheckInterop?,
                                        file: StaticString = #filePath,
                                        line: UInt = #line) async {
    let authorizer = StorageTokenAuthorizer(googleAppID: "dummyAppID",
                                            authProvider: authProvider, appCheck: appCheck)
    do {
      _ = try await authorizer.authorize(request)
      XCTFail("Expected authorization to fail due to insecure token attachment",
              file: file, line: line)
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, StorageErrorDomain, file: file, line: line)
      XCTAssertEqual(nsError.code, StorageErrorCode.unauthenticated.rawValue,
                     file: file, line: line)
    }
  }
}
