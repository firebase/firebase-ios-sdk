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
import GTMSessionFetcherCore
import SharedTestUtilities
import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
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
