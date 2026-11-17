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

@_spi(FirebaseNetworking) import FirebaseCoreInternal
@testable import FirebaseStorage
import Foundation
import XCTest

/// Tests the resumable upload protocol that `StorageResumableUpload` speaks, mostly through
/// `StorageUploadTask`. `StorageWireCompatibilityTests` pins the requests themselves.
class StorageResumableUploadTests: StorageTestHelpers {
  /// The server's chunk granularity, 256 KiB.
  private let granularity: Int64 = 262_144

  private let metadataJSON = Data(#"{"bucket":"bucket","name":"object"}"#.utf8)

  // MARK: - Chunk layout

  func testChunksRoundUpToTheGranularityAndTakeSmallRemainders() {
    let upload = makeUpload(length: 2 * granularity + 1000, chunkSize: 1)
    assertLayout(of: upload, at: 0, granularity: granularity,
                 equals: (0, granularity, "upload"))
    // Fewer than 2,500 bytes would remain after a full chunk, so the chunk takes them.
    assertLayout(of: upload, at: granularity, granularity: granularity,
                 equals: (granularity, granularity + 1000, "upload, finalize"))
  }

  func testChunksRoundDownToAMultipleOfTheGranularity() {
    let upload = makeUpload(length: 10 * granularity, chunkSize: 2 * granularity + 5)
    assertLayout(of: upload, at: 0, granularity: granularity,
                 equals: (0, 2 * granularity, "upload"))
  }

  func testOffsetsRoundDownToAMultipleOfTheGranularity() {
    let upload = makeUpload(length: 10 * granularity, chunkSize: 2 * granularity)
    assertLayout(of: upload, at: granularity + 5, granularity: granularity,
                 equals: (granularity, 2 * granularity, "upload"))
  }

  func testTheLastChunkTakesRemaindersOfFewerThan2500Bytes() {
    assertLayout(of: makeUpload(length: 10000, chunkSize: 7600), at: 0, granularity: 0,
                 equals: (0, 10000, "upload, finalize"))
    assertLayout(of: makeUpload(length: 10000, chunkSize: 7400), at: 0, granularity: 0,
                 equals: (0, 7400, "upload"))
  }

  func testUploadsWithNoBytesLeftSendAnEmptyFinalizeChunk() {
    assertLayout(of: makeUpload(length: 10), at: 10, granularity: 0, equals: (10, 0, "finalize"))
    assertLayout(of: makeUpload(length: 0), at: 0, granularity: granularity,
                 equals: (0, 0, "finalize"))
  }

  func testChunksInMemoryAreLimitedInSize() {
    let maxSize = StorageResumableUpload.maxChunkBufferSize
    assertLayout(of: makeUpload(length: 3 * maxSize), at: 0, granularity: granularity,
                 equals: (0, maxSize, "upload"))
  }

  func testWholeFilesAreSentInOneChunk() {
    let maxSize = StorageResumableUpload.maxChunkBufferSize
    let upload = makeUpload(source: .file(URL(fileURLWithPath: "/upload")), length: 3 * maxSize)
    assertLayout(of: upload, at: 0, granularity: granularity,
                 equals: (0, 3 * maxSize, "upload, finalize"))
    // The rest of a file whose start the server received is read into memory in chunks.
    assertLayout(of: upload, at: granularity, granularity: granularity,
                 equals: (granularity, maxSize, "upload"))
  }

  func testChunkSizesBelowOneByteStillMakeProgress() {
    assertLayout(of: makeUpload(length: 10000, chunkSize: 0), at: 0, granularity: 0,
                 equals: (0, 1, "upload"))
    assertLayout(of: makeUpload(length: 10000, chunkSize: 0), at: 0, granularity: granularity,
                 equals: (0, 10000, "upload, finalize"))
  }

  // MARK: - Uploads

  func testFileUploadsSendChunksReadFromTheFile() async throws {
    let content = Data((0 ..< (2 * granularity + 1000)).map { UInt8($0 % 251) })
    let fileURL = try temporaryFileURL()
    try content.write(to: fileURL)
    let transport = StorageTestTransport { request in
      switch Self.command(of: request) {
      case "start":
        return try self.sessionReply(to: request)
      case "upload":
        let offset = Int(request.value(forHTTPHeaderField: "X-Goog-Upload-Offset") ?? "") ?? 0
        return try self.activeReply(to: request,
                                    receivedBytes: offset + (request.httpBody?.count ?? 0))
      default:
        return try self.finalReply(to: request)
      }
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    let storage = self.storage()
    storage.uploadChunkSizeBytes = 1

    let metadata = try await storage.reference(withPath: "object").putFileAsync(from: fileURL)

    XCTAssertEqual(metadata.name, "object")
    let chunks = Array(transport.requests.dropFirst())
    XCTAssertEqual(chunks.map { Self.command(of: $0) }, ["upload", "upload, finalize"])
    XCTAssertEqual(chunks.map(\.httpBody),
                   [content.prefix(Int(granularity)), content.dropFirst(Int(granularity))])
    for chunk in chunks {
      // File uploads send the file's length with every chunk.
      XCTAssertEqual(chunk.value(forHTTPHeaderField: "X-Goog-Upload-Content-Length"),
                     "\(content.count)")
    }
    // Chunks of files are only written to temporary files for background sessions, and those
    // are deleted once sent.
    let temporaryFiles = try FileManager.default
      .contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path)
      .filter { $0.hasPrefix("FirebaseStorageUpload-") }
    XCTAssertEqual(temporaryFiles, [])
  }

  func testProgressIncludesTheMetadataThatTheStartRequestSends() async throws {
    let content = Data("Hello, progress!".utf8)
    let transport = StorageTestTransport { request in
      Self.command(of: request) == "start"
        ? try self.sessionReply(to: request)
        : try self.finalReply(to: request)
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    let progress = UnfairLock<[(completed: Int64, total: Int64)]>([])

    _ = try await storage().reference(withPath: "object").putDataAsync(content) { snapshot in
      if let snapshot {
        progress.withLock { $0.append((snapshot.completedUnitCount, snapshot.totalUnitCount)) }
      }
    }

    let metadataLength = try Int64(XCTUnwrap(transport.requests.first?.httpBody).count)
    let reported = progress.value()
    let expectedTotal = metadataLength + Int64(content.count)
    XCTAssertEqual(reported.first?.completed, metadataLength)
    XCTAssertEqual(reported.last?.completed, expectedTotal)
    XCTAssertEqual(Set(reported.map(\.total)), [expectedTotal])
  }

  // MARK: - Pause, resume, and cancel

  func testResumeContinuesTheUploadSession() async throws {
    let chunkStarted = expectation(description: "chunkStarted")
    let uploadCount = UnfairLock(0)
    let transport = StorageTestTransport { request in
      switch Self.command(of: request) {
      case "start":
        return try self.sessionReply(to: request)
      case "query":
        return try self.activeReply(to: request, receivedBytes: 0)
      default:
        if uploadCount.withLock({ count -> Int in
          count += 1
          return count
        }) == 1 {
          chunkStarted.fulfill()
          // Hold the chunk until the pause stops it.
          try await RetryBackoff.sleep(for: .infinity)
        }
        return try self.finalReply(to: request)
      }
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    let completed = expectation(description: "completed")

    let task = storage().reference(withPath: "object").putData(Data("Hi".utf8)) { metadata, error in
      XCTAssertNil(error)
      XCTAssertEqual(metadata?.name, "object")
      completed.fulfill()
    }
    await fulfillment(of: [chunkStarted], timeout: 10)
    task.pause()
    task.resume()
    await fulfillment(of: [completed], timeout: 10)

    // The resumed upload asks how much of the session's bytes the server has, instead of
    // opening another session.
    XCTAssertEqual(transport.requests.map { Self.command(of: $0) },
                   ["start", "upload, finalize", "query", "upload, finalize"])
    let query = transport.requests[2]
    XCTAssertEqual(query.httpMethod, "PUT")
    XCTAssertEqual(query.url?.absoluteString, Self.uploadSessionURL)
    assertSessionRequestHeaders(of: query)
  }

  func testCancelClosesTheUploadSession() async throws {
    let chunkStarted = expectation(description: "chunkStarted")
    let cancelSent = expectation(description: "cancelSent")
    let transport = holdingTransport(chunkStarted: chunkStarted, cancelSent: cancelSent)
    await StorageHTTPService.shared.updateTestTransport(transport)
    let completed = expectation(description: "completed")

    let task = storage().reference(withPath: "object").putData(Data("Hi".utf8)) { _, error in
      XCTAssertEqual((error as NSError?)?.code, StorageErrorCode.cancelled.rawValue)
      completed.fulfill()
    }
    await fulfillment(of: [chunkStarted], timeout: 10)
    task.cancel()
    await fulfillment(of: [completed, cancelSent], timeout: 10)

    let cancel = try XCTUnwrap(transport.requests.last)
    XCTAssertEqual(Self.command(of: cancel), "cancel")
    XCTAssertEqual(cancel.httpMethod, "PUT")
    XCTAssertEqual(cancel.url?.absoluteString, Self.uploadSessionURL)
    assertSessionRequestHeaders(of: cancel)
  }

  func testReleasingAPausedTaskClosesTheUploadSession() async throws {
    let chunkStarted = expectation(description: "chunkStarted")
    let cancelSent = expectation(description: "cancelSent")
    let transport = holdingTransport(chunkStarted: chunkStarted, cancelSent: cancelSent)
    await StorageHTTPService.shared.updateTestTransport(transport)

    do {
      let task = storage().reference(withPath: "object").putData(Data("Hi".utf8))
      await fulfillment(of: [chunkStarted], timeout: 10)
      task.pause()
    }

    await fulfillment(of: [cancelSent], timeout: 10)
  }

  // MARK: - Retries

  func testRetryableQueryFailuresAreRetried() async throws {
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.001)
    let queryCount = UnfairLock(0)
    let uploadCount = UnfairLock(0)
    let transport = StorageTestTransport { request in
      switch Self.command(of: request) {
      case "start":
        return try self.sessionReply(to: request)
      case "query":
        let count = queryCount.withLock { count -> Int in
          count += 1
          return count
        }
        return count == 1
          ? try self.reply(to: request, statusCode: 503)
          : try self.activeReply(to: request, receivedBytes: 0)
      default:
        let count = uploadCount.withLock { count -> Int in
          count += 1
          return count
        }
        return count == 1
          ? try self.reply(to: request, statusCode: 503)
          : try self.finalReply(to: request)
      }
    }
    await StorageHTTPService.shared.updateTestTransport(transport)

    let metadata = try await storage().reference(withPath: "object").putDataAsync(Data("Hi".utf8))

    XCTAssertEqual(metadata.name, "object")
    XCTAssertEqual(transport.requests.map { Self.command(of: $0) },
                   ["start", "upload, finalize", "query", "query", "upload, finalize"])
  }

  func testEachFailureAfterConfirmedProgressGetsTheWholeRetryTime() async throws {
    // A single retry fits in the retry time limit, but two in a row don't.
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.015)
    let storage = self.storage()
    storage.maxUploadRetryTime = 0.02
    storage.uploadChunkSizeBytes = 1
    let receivedBytes = UnfairLock(0)
    let transport = StorageTestTransport { request in
      switch Self.command(of: request) {
      case "start":
        return try self.sessionReply(to: request)
      case "query":
        return try self.activeReply(to: request, receivedBytes: receivedBytes.value())
      case "upload":
        // The server receives the chunk, but its response is lost.
        let offset = Int(request.value(forHTTPHeaderField: "X-Goog-Upload-Offset") ?? "") ?? 0
        receivedBytes.withLock { $0 = offset + (request.httpBody?.count ?? 0) }
        return try self.reply(to: request, statusCode: 503)
      default:
        return try self.finalReply(to: request)
      }
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    let content = Data(count: Int(3 * granularity + 1000))

    let metadata = try await storage.reference(withPath: "object").putDataAsync(content)

    XCTAssertEqual(metadata.name, "object")
    XCTAssertEqual(transport.requests.map { Self.command(of: $0) },
                   ["start", "upload", "query", "upload", "query", "upload, finalize"])
  }

  func testUploadsFailWhenTheServerKeepsTakingNoBytes() async throws {
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.001)
    let cancelSent = expectation(description: "cancelSent")
    let transport = StorageTestTransport { request in
      switch Self.command(of: request) {
      case "start":
        return try self.sessionReply(to: request)
      case "cancel":
        cancelSent.fulfill()
        return try self.reply(to: request, statusCode: 200)
      default:
        // Neither the chunk nor the query reports any bytes received.
        return try self.activeReply(to: request, receivedBytes: 0)
      }
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    let storage = self.storage()
    storage.maxUploadRetryTime = 0.2

    do {
      _ = try await storage.reference(withPath: "object").putDataAsync(Data("Hi".utf8))
      XCTFail("Expected an error")
    } catch {
      let error = error as NSError
      XCTAssertEqual(error.domain, StorageErrorDomain)
      XCTAssertEqual(error.code, StorageErrorCode.unknown.rawValue)
      XCTAssertEqual(error.userInfo["ResponseErrorDomain"] as? String, "com.google.HTTPStatus")
      XCTAssertEqual(error.userInfo["ResponseErrorCode"] as? Int, 501)
      XCTAssertGreaterThan(error.userInfo[StorageHTTPService.numberOfRetriesKey] as? Int ?? 0, 0)
    }
    await fulfillment(of: [cancelSent], timeout: 10)
  }

  func testUploadsFailWhenTheServerOnlyConfirmsBytesItAlreadyHad() async throws {
    // The server reports an offset that isn't a multiple of its granularity, so the next chunk
    // starts below it. The response to that chunk reports the same offset again.
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.001)
    let misalignedOffset = Int(granularity) + 100
    let cancelSent = expectation(description: "cancelSent")
    let uploadCount = UnfairLock(0)
    let transport = StorageTestTransport { request in
      switch Self.command(of: request) {
      case "start":
        return try self.sessionReply(to: request)
      case "cancel":
        cancelSent.fulfill()
        return try self.reply(to: request, statusCode: 200)
      case "query":
        return try self.activeReply(to: request, receivedBytes: misalignedOffset)
      default:
        let count = uploadCount.withLock { count -> Int in
          count += 1
          return count
        }
        return count == 1
          ? try self.reply(to: request, statusCode: 503)
          : try self.activeReply(to: request, receivedBytes: misalignedOffset)
      }
    }
    await StorageHTTPService.shared.updateTestTransport(transport)
    let storage = self.storage()
    storage.maxUploadRetryTime = 0.2
    storage.uploadChunkSizeBytes = 1
    let completed = expectation(description: "completed")

    storage.reference(withPath: "object")
      .putData(Data(count: Int(3 * granularity))) { _, error in
        XCTAssertEqual((error as NSError?)?.userInfo["ResponseErrorCode"] as? Int, 501)
        completed.fulfill()
      }

    await fulfillment(of: [completed, cancelSent], timeout: 10)
    let offsets = transport.requests.filter { Self.command(of: $0) == "upload" }
      .map { $0.value(forHTTPHeaderField: "X-Goog-Upload-Offset") }
    XCTAssertEqual(offsets.first, "0")
    XCTAssertEqual(Set(offsets.dropFirst()), ["\(granularity)"])
  }

  func testChunksThatTheServerDoesNotFindAreNotRetried() async throws {
    let cancelSent = expectation(description: "cancelSent")
    let transport = StorageTestTransport { request in
      switch Self.command(of: request) {
      case "start":
        return try self.sessionReply(to: request)
      case "cancel":
        cancelSent.fulfill()
        return try self.reply(to: request, statusCode: 200)
      default:
        // A 404 means that the session is gone, even with an active upload status.
        return try self.reply(to: request, statusCode: 404,
                              headers: ["X-Goog-Upload-Status": "active"])
      }
    }
    await StorageHTTPService.shared.updateTestTransport(transport)

    do {
      _ = try await storage().reference(withPath: "object").putDataAsync(Data("Hi".utf8))
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual((error as NSError).code, StorageErrorCode.objectNotFound.rawValue)
    }
    await fulfillment(of: [cancelSent], timeout: 10)
    XCTAssertEqual(transport.requests.map { Self.command(of: $0) },
                   ["start", "upload, finalize", "cancel"])
  }

  // MARK: - Helpers

  private func makeUpload(source: StorageResumableUpload.Source = .data(Data()),
                          length: Int64, chunkSize: Int64 = .max) -> StorageResumableUpload {
    StorageResumableUpload(
      startRequest: URLRequest(url: objectURL()),
      source: source,
      length: length,
      contentType: "application/octet-stream",
      chunkSize: chunkSize,
      storage: storage(),
      usesBackgroundSession: false
    )
  }

  private func assertLayout(of upload: StorageResumableUpload, at offset: Int64,
                            granularity: Int64,
                            equals expected: (offset: Int64, length: Int64, command: String),
                            file: StaticString = #filePath, line: UInt = #line) {
    let layout = upload.chunkLayout(at: offset, granularity: granularity)
    XCTAssertEqual(layout.offset, expected.offset, "offset", file: file, line: line)
    XCTAssertEqual(layout.length, expected.length, "length", file: file, line: line)
    XCTAssertEqual(layout.command, expected.command, "command", file: file, line: line)
  }

  /// Asserts the headers that every request to an upload session has, and that it carries no
  /// Firebase credentials.
  private func assertSessionRequestHeaders(of request: URLRequest,
                                           file: StaticString = #filePath,
                                           line: UInt = #line) {
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Goog-Upload-Protocol"), "resumable",
                   file: file, line: line)
    XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"),
                   "\(FirebaseUserAgent.standard) (GTMSUF/1)", file: file, line: line)
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"), file: file, line: line)
    XCTAssertNil(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"), file: file, line: line)
  }

  /// Returns a transport that opens an upload session, holds the first chunk until it's
  /// stopped, and answers `cancel`.
  private func holdingTransport(chunkStarted: XCTestExpectation,
                                cancelSent: XCTestExpectation) -> StorageTestTransport {
    StorageTestTransport { request in
      switch Self.command(of: request) {
      case "start":
        return try self.sessionReply(to: request)
      case "cancel":
        cancelSent.fulfill()
        return try self.reply(to: request, statusCode: 200,
                              headers: ["X-Goog-Upload-Status": "cancelled"])
      default:
        chunkStarted.fulfill()
        try await RetryBackoff.sleep(for: .infinity)
        throw CancellationError()
      }
    }
  }

  private static func command(of request: URLRequest) -> String {
    request.value(forHTTPHeaderField: "X-Goog-Upload-Command") ?? ""
  }

  private func sessionReply(to request: URLRequest) throws -> (Data, HTTPURLResponse) {
    try StorageTestHelpers.uploadResponse(to: request, finalBody: metadataJSON)
  }

  private func activeReply(to request: URLRequest,
                           receivedBytes: Int) throws -> (Data, HTTPURLResponse) {
    try reply(to: request, statusCode: 200, headers: [
      "X-Goog-Upload-Status": "active",
      "X-Goog-Upload-Size-Received": "\(receivedBytes)",
      "X-Goog-Upload-Chunk-Granularity": "\(granularity)",
    ])
  }

  private func finalReply(to request: URLRequest) throws -> (Data, HTTPURLResponse) {
    try (metadataJSON, StorageTestTransport.response(
      to: request, statusCode: 200, headers: ["X-Goog-Upload-Status": "final"]
    ))
  }

  private func reply(to request: URLRequest, statusCode: Int,
                     headers: [String: String]? = nil) throws -> (Data, HTTPURLResponse) {
    try (Data(), StorageTestTransport.response(to: request, statusCode: statusCode,
                                               headers: headers))
  }

  private func temporaryFileURL(function: String = #function) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let name = function.replacingOccurrences(of: "()", with: "")
    let fileURL = directory.appendingPathComponent("\(name)-\(UUID().uuidString).txt")
    addTeardownBlock {
      try? FileManager.default.removeItem(at: fileURL)
    }
    return fileURL
  }
}
