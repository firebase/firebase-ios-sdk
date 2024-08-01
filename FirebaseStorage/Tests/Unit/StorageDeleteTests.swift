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
import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class StorageDeleteTests: StorageTestHelpers {
  var fetcherService: GTMSessionFetcherService?
  var dispatchQueue: DispatchQueue?

  override func setUp() {
    super.setUp()
    fetcherService = GTMSessionFetcherService()
    fetcherService?.authorizer = StorageTokenAuthorizer(
      googleAppID: "dummyAppID",
      authProvider: nil,
      appCheck: nil
    )
    dispatchQueue = DispatchQueue(label: "Test dispatch queue")
  }

  override func tearDown() {
    fetcherService = nil
    super.tearDown()
  }

  func testFetcherConfiguration() {
    let expectation = self.expectation(description: #function)
    fetcherService!.testBlock = { (fetcher: GTMSessionFetcher!,
                                   response: GTMSessionFetcherTestResponse) in
        XCTAssertEqual(fetcher.request?.url, self.objectURL())
        XCTAssertEqual(fetcher.request?.httpMethod, "DELETE")
        let httpResponse = HTTPURLResponse(
          url: (fetcher.request?.url)!,
          statusCode: 200,
          httpVersion: "HTTP/1.1",
          headerFields: nil
        )
        response(httpResponse, nil, nil)
    }
    let path = objectPath()
    let ref = StorageReference(storage: storage(), path: path)
    StorageDeleteTask.deleteTask(
      reference: ref,
      queue: dispatchQueue!.self
    ) { _, error in
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testSuccessfulFetch() {
    let expectation = self.expectation(description: #function)
    fetcherService!.testBlock = { (fetcher: GTMSessionFetcher!,
                                   response: GTMSessionFetcherTestResponse) in
        XCTAssertEqual(fetcher.request?.url, self.objectURL())
        XCTAssertEqual(fetcher.request?.httpMethod, "DELETE")
        let httpResponse = HTTPURLResponse(
          url: (fetcher.request?.url)!,
          statusCode: 200,
          httpVersion: "HTTP/1.1",
          headerFields: nil
        )
        response(httpResponse, nil, nil)
    }
    let path = objectPath()
    let ref = StorageReference(storage: storage(), path: path)
    StorageDeleteTask.deleteTask(
      reference: ref,
      queue: dispatchQueue!.self
    ) { _, error in
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testSuccessfulFetchWithEmulator() {
    let expectation = self.expectation(description: #function)
    let storage = self.storage()
    storage.useEmulator(withHost: "localhost", port: 8080)
    fetcherService?.allowLocalhostRequest = true

    fetcherService!
      .testBlock = successBlock(
        withURL: URL(string: "http://localhost:8080/v0/b/bucket/o/object")!
      )

    let path = objectPath()
    let ref = StorageReference(storage: storage, path: path)
    StorageDeleteTask.deleteTask(
      reference: ref,
      queue: dispatchQueue!.self
    ) { _, error in
      expectation.fulfill()
    }
    waitForExpectation(test: self)
  }

  func testUnsuccessfulFetchUnauthenticated() async {
    let storage = storage()
    await storage.fetcherService.updateTestBlock(unauthenticatedBlock())
    let path = objectPath()
    let ref = StorageReference(storage: storage, path: path)
    do {
      try await ref.delete()
    } catch {
      XCTAssertEqual((error as NSError).code, StorageErrorCode.unauthenticated.rawValue)
    }
  }

  func testUnsuccessfulFetchUnauthorized() async {
    let storage = storage()
    await storage.fetcherService.updateTestBlock(unauthorizedBlock())
    let path = objectPath()
    let ref = StorageReference(storage: storage, path: path)
    do {
      try await ref.delete()
    } catch {
      XCTAssertEqual((error as NSError).code, StorageErrorCode.unauthorized.rawValue)
    }
  }

  func testUnsuccessfulFetchObjectDoesntExist() async {
    let storage = storage()
    await storage.fetcherService.updateTestBlock(notFoundBlock())
    let path = objectPath()
    let ref = StorageReference(storage: storage, path: path)
    do {
      try await ref.delete()
    } catch {
      XCTAssertEqual((error as NSError).code, StorageErrorCode.objectNotFound.rawValue)
    }
  }
}
