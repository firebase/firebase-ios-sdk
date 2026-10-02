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

@testable import FirebaseStorage
import Foundation
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif
import XCTest

class StorageAsyncAwaitTests: StorageTestHelpers {
  // MARK: - Cancellation

  func testDataThrowsCancelledWhenTaskIsCancelled() async throws {
    let ref = storage().reference(withPath: "object")
    await assertCancelledDuringRequest {
      _ = try await ref.data(maxSize: 1024)
    }
  }

  func testDataThrowsCancelledWhenTaskIsAlreadyCancelled() async throws {
    await StorageFetcherService.shared.updateTestBlock { _, _ in
      // Never respond, so that only cancellation can end the download.
    }
    let ref = storage().reference(withPath: "object")
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      _ = try await ref.data(maxSize: 1024)
    }
    await assertThrowsCancelled(task)
  }

  func testPutDataAsyncThrowsCancelledWhenTaskIsCancelled() async throws {
    let ref = storage().reference(withPath: "object")
    let data = try XCTUnwrap("Hello".data(using: .utf8))
    await assertCancelledDuringRequest {
      _ = try await ref.putDataAsync(data)
    }
  }

  func testPutDataAsyncWithProgressThrowsCancelledWhenTaskIsCancelled() async throws {
    let ref = storage().reference(withPath: "object")
    let data = try XCTUnwrap("Hello".data(using: .utf8))
    await assertCancelledDuringRequest {
      _ = try await ref.putDataAsync(data) { _ in }
    }
  }

  func testPutFileAsyncThrowsCancelledWhenTaskIsCancelled() async throws {
    let ref = storage().reference(withPath: "object")
    let fileURL = try temporaryFileURL()
    try XCTUnwrap("Hello".data(using: .utf8)).write(to: fileURL)
    await assertCancelledDuringRequest {
      _ = try await ref.putFileAsync(from: fileURL) { _ in }
    }
  }

  func testWriteAsyncThrowsCancelledWhenTaskIsCancelled() async throws {
    let ref = storage().reference(withPath: "object")
    let fileURL = try temporaryFileURL()
    await assertCancelledDuringRequest {
      _ = try await ref.writeAsync(toFile: fileURL) { _ in }
    }
  }

  // MARK: - Results

  func testDataReturnsDownloadedData() async throws {
    let data = try XCTUnwrap("Hello".data(using: .utf8))
    await StorageFetcherService.shared.updateTestBlock(responseBlock(with: data))
    let ref = storage().reference(withPath: "object")
    let downloadedData = try await ref.data(maxSize: 1024)
    XCTAssertEqual(downloadedData, data)
  }

  func testPutDataAsyncWithProgressReturnsMetadata() async throws {
    let metadata = StorageMetadata(dictionary: ["name": "object", "contentType": "text/plain"])
    await StorageFetcherService.shared.updateTestBlock(successBlock(withMetadata: metadata))
    let ref = storage().reference(withPath: "object")
    let data = try XCTUnwrap("Hello".data(using: .utf8))
    var progressCount = 0
    let uploadedMetadata = try await ref.putDataAsync(data) { _ in progressCount += 1 }
    XCTAssertEqual(uploadedMetadata.name, "object")
    XCTAssertEqual(uploadedMetadata.contentType, "text/plain")
    XCTAssertGreaterThan(progressCount, 0)
  }

  func testPutFileAsyncWithProgressReturnsMetadata() async throws {
    let metadata = StorageMetadata(dictionary: ["name": "object", "contentType": "text/plain"])
    await StorageFetcherService.shared.updateTestBlock(successBlock(withMetadata: metadata))
    let ref = storage().reference(withPath: "object")
    let fileURL = try temporaryFileURL()
    try XCTUnwrap("Hello".data(using: .utf8)).write(to: fileURL)
    var progressCount = 0
    let uploadedMetadata = try await ref.putFileAsync(from: fileURL) { _ in progressCount += 1 }
    XCTAssertEqual(uploadedMetadata.name, "object")
    XCTAssertEqual(uploadedMetadata.contentType, "text/plain")
    XCTAssertGreaterThan(progressCount, 0)
  }

  func testWriteAsyncWithProgressWritesFile() async throws {
    let data = try XCTUnwrap("Hello".data(using: .utf8))
    await StorageFetcherService.shared.updateTestBlock(responseBlock(with: data))
    let ref = storage().reference(withPath: "object")
    let fileURL = try temporaryFileURL()
    var progressCount = 0
    let url = try await ref.writeAsync(toFile: fileURL) { _ in progressCount += 1 }
    XCTAssertEqual(url, fileURL)
    XCTAssertEqual(try Data(contentsOf: fileURL), data)
    XCTAssertGreaterThan(progressCount, 0)
  }

  // MARK: - Helpers

  /// Runs `operation` in a new task with a test block that never responds, cancels the task once
  /// the request has started, and checks that `operation` throws `StorageError.cancelled` and
  /// that the request was stopped.
  private func assertCancelledDuringRequest(file: StaticString = #filePath,
                                            line: UInt = #line,
                                            _ operation: @escaping () async throws -> Void)
    async {
    let requestStarted = expectation(description: "requestStarted")
    var requestFetcher: GTMSessionFetcher?
    await StorageFetcherService.shared.updateTestBlock { fetcher, _ in
      // Never respond, so that only cancellation can end the request.
      requestFetcher = fetcher
      requestStarted.fulfill()
    }
    let task = Task {
      try await operation()
    }
    await fulfillment(of: [requestStarted], timeout: 10)
    task.cancel()
    await assertThrowsCancelled(task, file: file, line: line)
    XCTAssertEqual(requestFetcher?.isFetching, false, "The request was not stopped",
                   file: file, line: line)
  }

  /// Checks that `task` throws `StorageError.cancelled`, failing instead of waiting forever if
  /// `task` doesn't finish.
  private func assertThrowsCancelled(_ task: Task<Void, Error>,
                                     file: StaticString = #filePath,
                                     line: UInt = #line) async {
    let finished = expectation(description: "finished")
    Task {
      do {
        try await task.value
        XCTFail("Expected StorageError.cancelled", file: file, line: line)
      } catch {
        let error = error as NSError
        XCTAssertEqual(error.domain, StorageErrorDomain, file: file, line: line)
        XCTAssertEqual(error.code, StorageErrorCode.cancelled.rawValue, file: file, line: line)
      }
      finished.fulfill()
    }
    await fulfillment(of: [finished], timeout: 10)
  }

  /// Returns a test block that responds with `data` and status code 200.
  private func responseBlock(with data: Data) -> GTMSessionFetcherTestBlock {
    return { fetcher, response in
      let httpResponse = HTTPURLResponse(url: fetcher.request!.url!,
                                         statusCode: 200,
                                         httpVersion: "HTTP/1.1",
                                         headerFields: nil)
      response(httpResponse, data, nil)
    }
  }

  /// Returns the URL of a temporary file, which is removed when the test finishes.
  private func temporaryFileURL(function: String = #function) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
    // createDirectory is necessary because SPM tests on CI can fail with ENOENT if the temporary
    // directory doesn't exist yet.
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let name = function.replacingOccurrences(of: "()", with: "")
    let fileURL = directory.appendingPathComponent("\(name)-\(UUID().uuidString).txt")
    addTeardownBlock {
      try? FileManager.default.removeItem(at: fileURL)
    }
    return fileURL
  }
}
