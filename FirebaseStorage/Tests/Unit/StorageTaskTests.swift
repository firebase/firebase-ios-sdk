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

import FirebaseCoreInternal
@testable import FirebaseStorage
import Foundation
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif
import XCTest

/// Tests for `StorageUploadTask` and `StorageDownloadTask`.
class StorageTaskTests: StorageTestHelpers {
  func testUploadTaskIsReleasedAfterCancel() async throws {
    let requestStarted = await setNeverRespondingTestBlock()
    let ref = storage().reference(withPath: "object")
    let completed = expectation(description: "completed")
    weak var weakTask: StorageUploadTask?
    do {
      let task = ref.putData(Data("Hello".utf8)) { _, error in
        XCTAssertEqual((error as? NSError)?.code, StorageErrorCode.cancelled.rawValue)
        completed.fulfill()
      }
      weakTask = task
      await fulfillment(of: [requestStarted], timeout: 10)
      task.cancel()
    }
    await fulfillment(of: [completed], timeout: 10)
    await assertReleased { weakTask }
  }

  func testUploadTaskIsReleasedAfterSuccess() async throws {
    let metadata = StorageMetadata(dictionary: ["name": "object"])
    await StorageFetcherService.shared.updateTestBlock(successBlock(withMetadata: metadata))
    let ref = storage().reference(withPath: "object")
    let completed = expectation(description: "completed")
    weak var weakTask: StorageUploadTask?
    do {
      let task = ref.putData(Data("Hello".utf8)) { metadata, error in
        XCTAssertNil(error)
        XCTAssertEqual(metadata?.name, "object")
        completed.fulfill()
      }
      weakTask = task
    }
    await fulfillment(of: [completed], timeout: 10)
    await assertReleased { weakTask }
  }

  func testDownloadTaskIsReleasedAfterCancel() async throws {
    let requestStarted = await setNeverRespondingTransport()
    let ref = storage().reference(withPath: "object")
    let completed = expectation(description: "completed")
    weak var weakTask: StorageDownloadTask?
    do {
      let task = ref.getData(maxSize: 1024) { _, error in
        XCTAssertEqual((error as? NSError)?.code, StorageErrorCode.cancelled.rawValue)
        completed.fulfill()
      }
      weakTask = task
      await fulfillment(of: [requestStarted], timeout: 10)
      task.cancel()
    }
    await fulfillment(of: [completed], timeout: 10)
    await assertReleased { weakTask }
  }

  func testDownloadTaskIsReleasedAfterSuccess() async throws {
    await StorageHTTPService.shared.updateTestTransport(responseTransport(with: Data("Hello".utf8)))
    let ref = storage().reference(withPath: "object")
    let completed = expectation(description: "completed")
    weak var weakTask: StorageDownloadTask?
    do {
      let task = ref.getData(maxSize: 1024) { data, error in
        XCTAssertNil(error)
        XCTAssertEqual(data, Data("Hello".utf8))
        completed.fulfill()
      }
      weakTask = task
    }
    await fulfillment(of: [completed], timeout: 10)
    await assertReleased { weakTask }
  }

  func testDownloadTaskIsReleasedAfterPauseAndResume() async throws {
    let requestStarted = await setNeverRespondingTransport()
    let ref = storage().reference(withPath: "object")
    let completed = expectation(description: "completed")
    weak var weakTask: StorageDownloadTask?
    do {
      let task = ref.getData(maxSize: 1024) { data, error in
        XCTAssertNil(error)
        XCTAssertEqual(data, Data("Hello".utf8))
        completed.fulfill()
      }
      weakTask = task
      await fulfillment(of: [requestStarted], timeout: 10)
      task.pause()
      await StorageHTTPService.shared
        .updateTestTransport(responseTransport(with: Data("Hello".utf8)))
      task.resume()
    }
    await fulfillment(of: [completed], timeout: 10)
    await assertReleased { weakTask }
  }

  func testGetDataWithEmptyResponseReturnsEmptyData() async throws {
    await StorageHTTPService.shared.updateTestTransport(responseTransport(with: nil))
    let ref = storage().reference(withPath: "object")
    let data = try await ref.data(maxSize: 1024)
    XCTAssertEqual(data, Data())
  }

  // MARK: - Helpers

  /// Sets a test block that never responds, and returns an expectation that is fulfilled when
  /// the request starts.
  private func setNeverRespondingTestBlock() async -> XCTestExpectation {
    let requestStarted = expectation(description: "requestStarted")
    await StorageFetcherService.shared.updateTestBlock { _, _ in
      // Never respond, so that the request stays in flight until it is stopped.
      requestStarted.fulfill()
    }
    return requestStarted
  }

  /// Sets a transport that never responds to downloads, and returns an expectation that is
  /// fulfilled when the request starts.
  private func setNeverRespondingTransport() async -> XCTestExpectation {
    let requestStarted = expectation(description: "requestStarted")
    await StorageHTTPService.shared.updateTestTransport(StorageTestTransport { _ in
      requestStarted.fulfill()
      // Never respond, so that the request stays in flight until it is cancelled.
      try await RetryBackoff.sleep(for: .infinity)
      throw CancellationError()
    })
    return requestStarted
  }

  /// Returns a transport that responds with `data` and status code 200.
  private func responseTransport(with data: Data?) -> StorageTestTransport {
    StorageTestTransport { request in
      try (data ?? Data(), StorageTestTransport.response(to: request, statusCode: 200))
    }
  }

  /// Fails unless `object` returns nil within 10 seconds.
  private func assertReleased(_ object: () -> AnyObject?,
                              file: StaticString = #filePath,
                              line: UInt = #line) async {
    for _ in 0 ..< 1000 {
      if object() == nil {
        return
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("The task was not released", file: file, line: line)
  }
}
