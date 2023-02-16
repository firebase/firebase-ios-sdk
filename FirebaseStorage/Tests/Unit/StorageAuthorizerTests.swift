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

import Foundation
@testable import FirebaseStorage
import GTMSessionFetcherCore
import SharedTestUtilities
import XCTest

class StorageAuthorizerTests: StorageTestHelpers {
  var appCheckTokenSuccess: FIRAppCheckTokenResultFake!
  var appCheckTokenError: FIRAppCheckTokenResultFake!
  var fetcher: GTMSessionFetcher!
  var fetcherService: GTMSessionFetcherService!
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

    fetcherService = GTMSessionFetcherService()
    auth = FIRAuthInteropFake(token: StorageTestAuthToken, userID: nil, error: nil)
    appCheck = FIRAppCheckFake()
    fetcher?.authorizer = StorageTokenAuthorizer(googleAppID: "dummyAppID",
                                                 fetcherService: fetcherService!,
                                                 authProvider: auth, appCheck: appCheck)
  }

  override func tearDown() {
    fetcher = nil
    fetcherService = nil
    auth = nil
    appCheck = nil
    appCheckTokenSuccess = nil
    super.tearDown()
  }

  func testSuccessfulAuth() {
    let expectation = self.expectation(description: #function)
    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: true)
    }
    fetcher?.beginFetch { data, error in
      let headers = self.fetcher!.request?.allHTTPHeaderFields
      XCTAssertEqual(headers!["Authorization"], "Firebase \(self.StorageTestAuthToken)")
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testUnsuccessfulAuth() {
    let expectation = self.expectation(description: #function)
    let authError = NSError(domain: "FIRStorageErrorDomain",
                            code: StorageErrorCode.unauthenticated.rawValue, userInfo: nil)
    let failedAuth = FIRAuthInteropFake(token: nil, userID: nil, error: authError)
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      fetcherService: fetcherService!,
      authProvider: failedAuth,
      appCheck: nil
    )
    setFetcherTestBlock(with: 401) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: false)
    }
    fetcher?.beginFetch { data, error in
      let headers = self.fetcher!.request?.allHTTPHeaderFields
      XCTAssertNil(headers)
      let nsError = error as? NSError
      XCTAssertEqual(nsError?.domain, "FIRStorageErrorDomain")
      XCTAssertEqual(nsError?.code, StorageErrorCode.unauthenticated.rawValue)
      XCTAssertEqual(nsError?.localizedDescription, "User is not authenticated, please " +
        "authenticate using Firebase Authentication and try again.")
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testSuccessfulUnauthenticatedAuth() {
    let expectation = self.expectation(description: #function)

    // Simulate Auth not being included at all
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      fetcherService: fetcherService!,
      authProvider: nil,
      appCheck: nil
    )

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: false)
    }
    fetcher?.beginFetch { data, error in
      let headers = self.fetcher!.request?.allHTTPHeaderFields
      XCTAssertNil(headers!["Authorization"])
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testSuccessfulAppCheckNoAuth() {
    let expectation = self.expectation(description: #function)
    appCheck?.tokenResult = appCheckTokenSuccess!

    // Simulate Auth not being included at all
    fetcher?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      fetcherService: fetcherService!,
      authProvider: nil,
      appCheck: appCheck
    )

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: false)
    }
    fetcher?.beginFetch { data, error in
      let headers = self.fetcher!.request?.allHTTPHeaderFields
      XCTAssertEqual(headers!["X-Firebase-AppCheck"], self.appCheckTokenSuccess?.token)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testSuccessfulAppCheckAndAuth() {
    let expectation = self.expectation(description: #function)
    appCheck?.tokenResult = appCheckTokenSuccess!

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: true)
    }
    fetcher?.beginFetch { data, error in
      let headers = self.fetcher!.request?.allHTTPHeaderFields
      XCTAssertEqual(headers!["Authorization"], "Firebase \(self.StorageTestAuthToken)")
      XCTAssertEqual(headers!["X-Firebase-AppCheck"], self.appCheckTokenSuccess?.token)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testAppCheckError() {
    let expectation = self.expectation(description: #function)
    appCheck?.tokenResult = appCheckTokenError!

    setFetcherTestBlock(with: 200) { fetcher in
      self.checkAuthorizer(fetcher: fetcher, trueFalse: true)
    }
    fetcher?.beginFetch { data, error in
      let headers = self.fetcher!.request?.allHTTPHeaderFields
      XCTAssertEqual(headers!["Authorization"], "Firebase \(self.StorageTestAuthToken)")
      XCTAssertEqual(headers!["X-Firebase-AppCheck"], self.appCheckTokenError?.token)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testIsAuthorizing() {
    let expectation = self.expectation(description: #function)

    setFetcherTestBlock(with: 200) { fetcher in
      do {
        let authorizer = try XCTUnwrap(fetcher.authorizer)
        XCTAssertFalse(authorizer.isAuthorizingRequest(fetcher.request!))
      } catch {
        XCTFail("Failed to get authorizer: \(error)")
      }
    }
    fetcher?.beginFetch { data, error in
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testStopAuthorizingNoop() {
    let expectation = self.expectation(description: #function)

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
    fetcher?.beginFetch { data, error in
      XCTAssertNil(error)
      let headers = self.fetcher!.request?.allHTTPHeaderFields
      XCTAssertEqual(headers!["Authorization"], "Firebase \(self.StorageTestAuthToken)")
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testEmail() {
    let expectation = self.expectation(description: #function)

    setFetcherTestBlock(with: 200) { fetcher in
      do {
        let authorizer = try XCTUnwrap(fetcher.authorizer)
        XCTAssertNil(authorizer.userEmail)
      } catch {
        XCTFail("Failed to get authorizer: \(error)")
      }
    }
    fetcher?.beginFetch { data, error in
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectation(test: self)
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
