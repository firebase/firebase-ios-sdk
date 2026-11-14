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
import SharedTestUtilities
import XCTest

/// Tests downloads: resuming them, their errors, the files they write, and pausing them.
class StorageDownloadTests: StorageTestHelpers {
  private let body = Data("Hello, download!".utf8)
  private let resumeData = Data("resume data".utf8)

  // MARK: - Resuming

  func testResumedDownloadsStartFromTheirResumeData() async throws {
    let transport = DownloadTestTransport { _ in .init(body: self.body) }
    await StorageHTTPService.shared.updateTestTransport(transport)

    let fileURL = try await download(resumeData: resumeData)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    XCTAssertEqual(try Data(contentsOf: fileURL), body)
    XCTAssertEqual(transport.sources.map(\.resumeData), [resumeData])
  }

  func testResumedDownloadsStartOverWhenTheirSavedCredentialsAreRejected() async throws {
    let storage = Storage(app: app, bucket: "bucket",
                          auth: FIRAuthInteropFake(token: "fresh-token", userID: nil, error: nil),
                          appCheck: nil)
    let transport = DownloadTestTransport { source in
      source.resumeData == nil ? .init(body: self.body) : .init(status: 401)
    }
    await StorageHTTPService.shared.updateTestTransport(transport)

    let fileURL = try await download(for: storage, resumeData: resumeData)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    XCTAssertEqual(try Data(contentsOf: fileURL), body)
    XCTAssertEqual(transport.sources.map(\.resumeData), [resumeData, nil])
    XCTAssertEqual(transport.sources.last?.request?.value(forHTTPHeaderField: "Authorization"),
                   "Firebase fresh-token")
    XCTAssertFalse(FileManager.default.fileExists(atPath: transport.files[0].path))
  }

  func testRetriesOfResumedDownloadsStartOver() async throws {
    let transport = DownloadTestTransport { source in
      source.resumeData == nil ? .init(body: self.body) : .init(status: 503)
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.001)

    let fileURL = try await download(resumeData: resumeData)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    XCTAssertEqual(try Data(contentsOf: fileURL), body)
    XCTAssertEqual(transport.sources.map(\.resumeData), [resumeData, nil])
  }

  func testCancelledDownloadsKeepTheirResumeDataAndAreNotRetried() async throws {
    let transport = DownloadTestTransport { _ in
      throw HTTPDownloadCancellation(resumeData: self.resumeData)
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.001)

    do {
      _ = try await download()
      XCTFail("Expected cancellation")
    } catch {
      XCTAssertEqual((error as? HTTPDownloadCancellation)?.resumeData, resumeData, "\(error)")
    }
    XCTAssertEqual(transport.sources.count, 1)
  }

  // MARK: - Errors

  func testDownloadErrorsHoldTheErrorBodyAndTheDownloadedFileIsDeleted() async throws {
    let errorBody = Data(#"{"error":{"code":404,"message":"Not Found."}}"#.utf8)
    let transport = DownloadTestTransport { _ in
      .init(status: 404, headers: ["Content-Type": "application/json"], body: errorBody)
    }
    await StorageHTTPService.shared.updateTestTransport(transport)

    do {
      _ = try await download()
      XCTFail("Expected an error")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, HTTPStatusError.domain)
      XCTAssertEqual(nsError.code, 404)
      XCTAssertEqual(nsError.userInfo[HTTPStatusError.dataKey] as? Data, errorBody)
      XCTAssertEqual(nsError.userInfo[HTTPStatusError.contentTypeKey] as? String,
                     "application/json")
    }
    XCTAssertEqual(transport.files.count, 1)
    XCTAssertFalse(FileManager.default.fileExists(atPath: transport.files[0].path))
  }

  func testDownloadErrorsLeaveOutErrorBodiesOverTheLimit() async throws {
    let errorBody = Data(count: StorageHTTPService.maxDownloadErrorBodyLength + 1)
    let transport = DownloadTestTransport { _ in .init(status: 404, body: errorBody) }
    await StorageHTTPService.shared.updateTestTransport(transport)

    do {
      _ = try await download()
      XCTFail("Expected an error")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.code, 404)
      XCTAssertNil(nsError.userInfo[HTTPStatusError.dataKey])
    }
  }

  // MARK: - Files

  func testWriteToFileCreatesMissingDirectories() async throws {
    await StorageHTTPService.shared
      .updateTestTransport(DownloadTestTransport { _ in .init(body: self.body) })
    let fileURL = try temporaryDirectory().appendingPathComponent("a/b/object.txt")

    _ = try await rootReference().child("object").writeAsync(toFile: fileURL)

    XCTAssertEqual(try Data(contentsOf: fileURL), body)
  }

  func testWriteToFileReplacesAnExistingFile() async throws {
    await StorageHTTPService.shared
      .updateTestTransport(DownloadTestTransport { _ in .init(body: self.body) })
    let fileURL = try temporaryDirectory().appendingPathComponent("object.txt")
    try Data("old contents".utf8).write(to: fileURL)

    _ = try await rootReference().child("object").writeAsync(toFile: fileURL)

    XCTAssertEqual(try Data(contentsOf: fileURL), body)
  }

  func testFailedWriteToFileKeepsAnExistingFile() async throws {
    await StorageHTTPService.shared
      .updateTestTransport(DownloadTestTransport { _ in .init(status: 404) })
    let fileURL = try temporaryDirectory().appendingPathComponent("object.txt")
    let oldContents = Data("old contents".utf8)
    try oldContents.write(to: fileURL)

    do {
      _ = try await rootReference().child("object").writeAsync(toFile: fileURL)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual((error as NSError).code, StorageErrorCode.objectNotFound.rawValue)
    }
    XCTAssertEqual(try Data(contentsOf: fileURL), oldContents)
  }

  // MARK: - Pausing

  func testPausedDownloadsToAFileResumeFromTheirResumeData() async throws {
    let requestStarted = expectation(description: "requestStarted")
    let transport = DownloadTestTransport { source in
      guard source.resumeData != nil else {
        requestStarted.fulfill()
        // Never respond, so that only pausing can end the download.
        try? await RetryBackoff.sleep(for: .infinity)
        throw HTTPDownloadCancellation(resumeData: self.resumeData)
      }
      return .init(body: self.body)
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    let fileURL = try temporaryDirectory().appendingPathComponent("object.txt")
    let paused = expectation(description: "paused")
    let succeeded = expectation(description: "succeeded")
    let task = rootReference().child("object").write(toFile: fileURL)
    task.observe(.pause) { _ in paused.fulfill() }
    task.observe(.success) { _ in succeeded.fulfill() }
    await fulfillment(of: [requestStarted], timeout: 10)

    task.pause()
    await fulfillment(of: [paused], timeout: 10)
    task.resume()
    await fulfillment(of: [succeeded], timeout: 10)

    XCTAssertEqual(try Data(contentsOf: fileURL), body)
    XCTAssertEqual(transport.sources.map(\.resumeData), [nil, resumeData])
  }

  func testPausedDownloadsToMemoryStartOverWhenResumed() async throws {
    let requestStarted = expectation(description: "requestStarted")
    let requestCount = UnfairLock(0)
    let transport = StorageTestTransport { request in
      let count = requestCount.withLock { count -> Int in
        count += 1
        return count
      }
      if count == 1 {
        requestStarted.fulfill()
        // Never respond, so that only pausing can end the download.
        try await RetryBackoff.sleep(for: .infinity)
      }
      return try (self.body, StorageTestTransport.response(to: request, statusCode: 200))
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    let paused = expectation(description: "paused")
    let completed = expectation(description: "completed")
    let task = rootReference().child("object").getData(maxSize: 1024) { data, error in
      XCTAssertNil(error)
      XCTAssertEqual(data, self.body)
      completed.fulfill()
    }
    task.observe(.pause) { _ in paused.fulfill() }
    await fulfillment(of: [requestStarted], timeout: 10)

    task.pause()
    await fulfillment(of: [paused], timeout: 10)
    task.resume()
    await fulfillment(of: [completed], timeout: 10)

    XCTAssertEqual(transport.requests.count, 2)
  }

  // MARK: - Helpers

  private func download(for storage: Storage? = nil, resumeData: Data? = nil) async throws -> URL {
    let storage = storage ?? self.storage()
    return try await StorageHTTPService.shared.download(
      for: URLRequest(url: objectURL()), resumeData: resumeData, storage: storage,
      maxRetryTime: 120, progress: { _ in }
    )
  }

  /// Returns a new directory that is deleted when the test ends.
  private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("StorageDownloadTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: directory)
    }
    return directory
  }
}

/// Answers downloads to a file in unit tests. It writes each response body to a new temporary
/// file, as `URLSessionTransport` does, and records where each download started.
private final class DownloadTestTransport: HTTPTransport, @unchecked Sendable {
  struct Reply {
    var status = 200
    var headers: [String: String]?
    var body = Data()
  }

  typealias Handler = (HTTPDownloadSource) async throws -> Reply

  private let handler: Handler
  private let recordedSources = UnfairLock<[HTTPDownloadSource]>([])
  private let recordedFiles = UnfairLock<[URL]>([])

  /// Where each download started, in order.
  var sources: [HTTPDownloadSource] {
    recordedSources.value()
  }

  /// The files that the transport wrote, in order.
  var files: [URL] {
    recordedFiles.value()
  }

  init(_ handler: @escaping Handler) {
    self.handler = handler
  }

  func data(for request: URLRequest,
            policy: HTTPRequestPolicy) async throws -> (Data, HTTPURLResponse) {
    XCTFail("Downloads to a file should use download(_:policy:progress:)")
    throw URLError(.unsupportedURL)
  }

  func download(_ source: HTTPDownloadSource,
                policy: HTTPRequestPolicy,
                progress: @escaping @Sendable (HTTPTransferProgress) -> Void) async throws
    -> (URL, HTTPURLResponse) {
    recordedSources.withLock { $0.append(source) }
    let reply = try await handler(source)
    let url = try XCTUnwrap(source.request?.url ?? URL(string: "https://example.com/resumed"))
    let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: reply.status,
                                                 httpVersion: "HTTP/1.1",
                                                 headerFields: reply.headers))
    let length = Int64(reply.body.count)
    progress(HTTPTransferProgress(completedBytes: length, expectedBytes: length))
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("StorageDownloadTests-\(UUID().uuidString)")
    try reply.body.write(to: fileURL)
    recordedFiles.withLock { $0.append(fileURL) }
    return (fileURL, response)
  }
}

private extension HTTPDownloadSource {
  var request: URLRequest? {
    if case let .request(request) = self {
      return request
    }
    return nil
  }

  var resumeData: Data? {
    if case let .resumeData(resumeData) = self {
      return resumeData
    }
    return nil
  }
}
