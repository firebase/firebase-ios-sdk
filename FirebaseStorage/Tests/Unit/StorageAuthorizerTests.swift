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

@testable import FirebaseStorage
import Foundation
import FirebaseAppCheckInterop
import FirebaseAuthInterop
import GTMSessionFetcherCore
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
    resumeCallbacks.wait()
  }

  func resumeBoth() {
    callbacksReady.wait()
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

private final class ThreadCheckedMutableURLRequest: NSMutableURLRequest, @unchecked Sendable {
  private let mutationLock = NSLock()
  private var activeMutations = 0
  private(set) var didMutateConcurrently = false

  override init(url: URL,
                cachePolicy: NSURLRequest.CachePolicy,
                timeoutInterval: TimeInterval) {
    super.init(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  override func setValue(_ value: String?, forHTTPHeaderField field: String) {
    mutationLock.lock()
    if activeMutations > 0 {
      didMutateConcurrently = true
    }
    activeMutations += 1
    mutationLock.unlock()

    Thread.sleep(forTimeInterval: 0.02)
    super.setValue(value, forHTTPHeaderField: field)

    mutationLock.lock()
    activeMutations -= 1
    mutationLock.unlock()
  }
}

class StorageAuthorizerTests: StorageTestHelpers {
  var appCheckTokenSuccess: FIRAppCheckTokenResultFake!
  var appCheckTokenError: FIRAppCheckTokenResultFake!
  var fetcher: GTMSessionFetcher!
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

    let fetchRequest = URLRequest(url: StorageTestHelpers().objectURL())
    fetcher = GTMSessionFetcher(request: fetchRequest)

    auth = FIRAuthInteropFake(token: StorageTestAuthToken, userID: nil, error: nil)
    appCheck = FIRAppCheckFake()
    fetcher?.authorizer = StorageTokenAuthorizer(googleAppID: "dummyAppID",
                                                 callbackQueue: DispatchQueue.main,
                                                 authProvider: auth, appCheck: appCheck)
  }

  override func tearDown() {
    fetcher = nil
    auth = nil
    appCheck = nil
    appCheckTokenSuccess = nil
    super.tearDown()
  }

  func testSuccessfulAuth() async throws {
    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: true)
    }
    let _ = try await fetcher?.beginFetch()
    let headers = fetcher!.request?.allHTTPHeaderFields
    XCTAssertEqual(headers!["Authorization"], "Firebase \(StorageTestAuthToken)")
  }

  func testUnsuccessfulAuth() async {
    let authError = NSError(domain: "FIRStorageErrorDomain",
                            code: StorageErrorCode.unauthenticated.rawValue, userInfo: nil)
    let failedAuth = FIRAuthInteropFake(token: nil, userID: nil, error: authError)
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: failedAuth,
      appCheck: nil
    )
    setFetcherTestBlock(with: 401) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: false)
    }
    do {
      let _ = try await fetcher?.beginFetch()
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
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: nil,
      appCheck: nil
    )

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: false)
    }
    let _ = try await fetcher?.beginFetch()
    let headers = fetcher!.request?.allHTTPHeaderFields
    XCTAssertNil(headers!["Authorization"])
  }

  func testSuccessfulAppCheckNoAuth() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!

    // Simulate Auth not being included at all
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: nil,
      appCheck: appCheck
    )

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: false)
    }
    let _ = try await fetcher?.beginFetch()
    let headers = fetcher!.request?.allHTTPHeaderFields
    XCTAssertEqual(headers!["X-Firebase-AppCheck"], appCheckTokenSuccess?.token)
  }

  func testSuccessfulAppCheckAndAuth() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: true)
    }
    let _ = try await fetcher?.beginFetch()
    let headers = fetcher!.request?.allHTTPHeaderFields
    XCTAssertEqual(headers!["Authorization"], "Firebase \(StorageTestAuthToken)")
    XCTAssertEqual(headers!["X-Firebase-AppCheck"], appCheckTokenSuccess?.token)
  }

  func testAuthAndAppCheckTokenHeadersAreMutatedSerially() {
    let barrier = ParallelCallbackBarrier()
    let request = ThreadCheckedMutableURLRequest(
      url: URL(string: "https://storage.googleapis.com/v0/b/bucket/o/object")!,
      cachePolicy: .useProtocolCachePolicy,
      timeoutInterval: 60
    )
    let authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      callbackQueue: DispatchQueue(label: "com.google.firebase.storage.authorizer-test"),
      authProvider: ConcurrentAuthInteropFake(barrier: barrier),
      appCheck: ConcurrentAppCheckInteropFake(barrier: barrier)
    )
    let completion = expectation(description: "Token authorization completes")

    authorizer.authorizeRequest(request) { error in
      XCTAssertNil(error)
      completion.fulfill()
    }
    barrier.resumeBoth()
    wait(for: [completion], timeout: 3)

    XCTAssertFalse(request.didMutateConcurrently)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Firebase auth-token")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"), "app-check-token")
  }

  func testAppCheckError() async throws {
    appCheck?.tokenResult = appCheckTokenError!

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: true)
    }
    let _ = try await fetcher?.beginFetch()
    let headers = fetcher!.request?.allHTTPHeaderFields
    XCTAssertEqual(headers!["Authorization"], "Firebase \(StorageTestAuthToken)")
    XCTAssertEqual(headers!["X-Firebase-AppCheck"], appCheckTokenError?.token)
  }

  func testIsAuthorizing() async throws {
    setFetcherTestBlock(with: 200) { fetcher in
      do {
        let authorizer = try XCTUnwrap(fetcher.authorizer)
        XCTAssertFalse(authorizer.isAuthorizingRequest(fetcher.request!))
      } catch {
        XCTFail("Failed to get authorizer: \(error)")
      }
    }
    let _ = try await fetcher?.beginFetch()
  }

  func testStopAuthorizingNoop() async throws {
    setFetcherTestBlock(with: 200) { fetcher in
      do {
        let authorizer = try XCTUnwrap(fetcher.authorizer)

        // Since both of these are noops, we expect that invoking them
        // will still result in successful authenticatio
        authorizer.stopAuthorization()
        authorizer.stopAuthorization(for: fetcher.request!)
      } catch {
        XCTFail("Failed to get authorizer: \(error)")
      }
    }
    let _ = try await fetcher?.beginFetch()
    let headers = fetcher!.request?.allHTTPHeaderFields
    XCTAssertEqual(headers!["Authorization"], "Firebase \(StorageTestAuthToken)")
  }

  func testEmail() async throws {
    setFetcherTestBlock(with: 200) { fetcher in
      do {
        let authorizer = try XCTUnwrap(fetcher.authorizer)
        XCTAssertNil(authorizer.userEmail)
      } catch {
        XCTFail("Failed to get authorizer: \(error)")
      }
    }
    let _ = try await fetcher?.beginFetch()
  }

  func testInsecureHostFailsWhenTokensPresent() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!
    let insecureRequest = URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!)
    fetcher = GTMSessionFetcher(request: insecureRequest)
    fetcher?.allowedInsecureSchemes = ["http"]
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      callbackQueue: DispatchQueue.main,
      authProvider: auth,
      appCheck: appCheck
    )

    do {
      let _ = try await fetcher?.beginFetch()
      XCTFail("Expected fetch to fail due to insecure token attachment")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, StorageErrorDomain)
      XCTAssertEqual(nsError.code, StorageErrorCode.unauthenticated.rawValue)
    }
  }

  func testInsecureHostSucceedsWhenNoTokensPresent() async throws {
    let insecureRequest = URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!)
    fetcher = GTMSessionFetcher(request: insecureRequest)
    fetcher?.allowedInsecureSchemes = ["http"]
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      callbackQueue: DispatchQueue.main,
      authProvider: nil,
      appCheck: nil
    )

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: false)
    }
    let _ = try await fetcher?.beginFetch()
    let headers = fetcher!.request?.allHTTPHeaderFields
    XCTAssertNil(headers?["Authorization"])
    XCTAssertNil(headers?["X-Firebase-AppCheck"])
  }

  func testInsecureHostSucceedsWhenAuthProviderIsPresentButUserSignedOut() async throws {
    let unauthenticatedAuthFake = FIRAuthInteropFake(token: nil, userID: nil, error: nil)
    let insecureRequest = URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!)
    fetcher = GTMSessionFetcher(request: insecureRequest)
    fetcher?.allowedInsecureSchemes = ["http"]
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      callbackQueue: DispatchQueue.main,
      authProvider: unauthenticatedAuthFake,
      appCheck: nil
    )

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: false)
    }
    let _ = try await fetcher?.beginFetch()
    let headers = fetcher!.request?.allHTTPHeaderFields
    XCTAssertNil(headers?["Authorization"])
    XCTAssertNil(headers?["X-Firebase-AppCheck"])
  }

  func testLocalhostDoesAttachTokensOverHttp() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!
    let localRequest = URLRequest(url: URL(string: "http://localhost/v0/b/bucket/o/object")!)
    fetcher = GTMSessionFetcher(request: localRequest)
    fetcher?.allowedInsecureSchemes = ["http"]
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      callbackQueue: DispatchQueue.main,
      authProvider: auth,
      appCheck: appCheck
    )

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: true)
    }
    let _ = try await fetcher?.beginFetch()
    let headers = fetcher!.request?.allHTTPHeaderFields
    XCTAssertEqual(headers?["Authorization"], "Firebase \(StorageTestAuthToken)")
    XCTAssertEqual(headers?["X-Firebase-AppCheck"], appCheckTokenSuccess?.token)
  }

  func testDynamicAllowInsecureTokenAttachment() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!
    let insecureRequest = URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!)
    fetcher = GTMSessionFetcher(request: insecureRequest)
    fetcher?.allowedInsecureSchemes = ["http"]

    var allowInsecure = false
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      callbackQueue: DispatchQueue.main,
      authProvider: auth,
      appCheck: appCheck,
      allowInsecureTokenAttachment: { allowInsecure }
    )

    // Update allowInsecure to true after authorizer has been initialized
    allowInsecure = true

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: true)
    }

    let _ = try await fetcher?.beginFetch()
    let headers = fetcher!.request?.allHTTPHeaderFields
    XCTAssertEqual(headers?["Authorization"], "Firebase \(StorageTestAuthToken)")
    XCTAssertEqual(headers?["X-Firebase-AppCheck"], appCheckTokenSuccess?.token)
  }

  func testInsecureHostFailsWhenOnlyAppCheckTokenIsPresent() async throws {
    appCheck?.tokenResult = appCheckTokenSuccess!
    let insecureRequest = URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!)
    fetcher = GTMSessionFetcher(request: insecureRequest)
    fetcher?.allowedInsecureSchemes = ["http"]
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      callbackQueue: DispatchQueue.main,
      authProvider: nil,
      appCheck: appCheck
    )

    do {
      let _ = try await fetcher?.beginFetch()
      XCTFail("Expected fetch to fail due to insecure AppCheck token attachment")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, StorageErrorDomain)
      XCTAssertEqual(nsError.code, StorageErrorCode.unauthenticated.rawValue)
    }
  }

  func testInsecureHostFailsWhenOnlyAuthTokenIsPresent() async throws {
    let insecureRequest = URLRequest(url: URL(string: "http://10.0.0.1/v0/b/bucket/o/object")!)
    fetcher = GTMSessionFetcher(request: insecureRequest)
    fetcher?.allowedInsecureSchemes = ["http"]
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      callbackQueue: DispatchQueue.main,
      authProvider: auth,
      appCheck: nil
    )

    do {
      let _ = try await fetcher?.beginFetch()
      XCTFail("Expected fetch to fail due to insecure Auth token attachment")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, StorageErrorDomain)
      XCTAssertEqual(nsError.code, StorageErrorCode.unauthenticated.rawValue)
    }
  }

  // MARK: Helpers

  private func setFetcherTestBlock(with statusCode: Int,
                                   _ validationBlock: @escaping (GTMSessionFetcher) -> Void) {
    fetcher?.testBlock = { (fetcher: GTMSessionFetcher,
                            response: GTMSessionFetcherTestResponse) in
        validationBlock(fetcher)
        let httpResponse = HTTPURLResponse(url: (fetcher.request?.url)!,
                                           statusCode: statusCode,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: nil)
        response(httpResponse, nil, nil)
    }
  }

  private func checkAuthorizer(fetcher: GTMSessionFetcher, trueFalse: Bool) {
    do {
      let authorizer = try XCTUnwrap(fetcher.authorizer)
      XCTAssertEqual(authorizer.isAuthorizedRequest(fetcher.request!), trueFalse)
    } catch {
      XCTFail("Failed to get authorizer: \(error)")
    }
  }
}
