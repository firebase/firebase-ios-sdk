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

import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
#if canImport(FirebaseNetworkingInternal)
  @_spi(FirebaseNetworking) @testable import FirebaseNetworkingInternal
#else
  @_spi(FirebaseNetworking) @testable import FirebaseCoreInternal
#endif
#if SWIFT_PACKAGE
  import FirebaseWireCompatibilityTestingSupport
#endif
import XCTest

// Custom `URLProtocol` classes can't intercept `URLSession` traffic on watchOS. `HTTPWireRecorder`
// lives in FirebaseTestingSupport, which only the SwiftPM and CocoaPods builds include.
// `linuxURLProtocolLimitations`: on Linux, FoundationNetworking can't serve redirects from a
// `URLProtocol` (it calls `fatalError`), crashes when a `URLProtocol` answers a download task,
// doesn't pass upload bodies to a `URLProtocol`, and reports no expected length. The tests that
// need those run on Apple platforms only.
#if (COCOAPODS || SWIFT_PACKAGE) && !os(watchOS)

  /// Tests data transfers with progress and downloads, in `URLSessionTransport`,
  /// `FirebaseHTTPClient`, and the default implementations of `HTTPTransport`.
  class HTTPTransferTests: XCTestCase {
    private let url = URL(string: "https://example.com/object")!
    private let body = Data("Hello, transfer!".utf8)

    override func setUp() {
      super.setUp()
      HTTPWireRecorder.reset()
    }

    override func tearDown() {
      HTTPWireRecorder.reset()
      super.tearDown()
    }

    // MARK: - Data with progress

    // Apple platforms only: FoundationNetworking's URLProtocol support can't run this test on
    // Linux (see `linuxURLProtocolLimitations`).
    #if canImport(Darwin)
      func testDataReportsProgressAndReturnsTheBody() async throws {
        HTTPWireRecorder.reset(replies: [.http(status: 200, headers: lengthHeader, body: body)])
        let transport = makeTransport()
        let progress = ProgressRecorder()

        let (data, response) = try await transport.data(
          for: URLRequest(url: url), policy: HTTPRequestPolicy(), progress: { progress.record($0) }
        )

        XCTAssertEqual(data, body)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(progress.values.last, completeProgress)
        XCTAssertEqual(transport.trackedTaskCount, 0)
      }
    #endif

    func testDataReturnsTheBodyOfAnHTTPError() async throws {
      HTTPWireRecorder.reset(replies: [.http(status: 404, body: body)])

      let (data, response) = try await makeTransport().data(
        for: URLRequest(url: url), policy: HTTPRequestPolicy(), progress: { _ in }
      )

      XCTAssertEqual(data, body)
      XCTAssertEqual(response.statusCode, 404)
    }

    func testDataThrowsTransportErrors() async {
      HTTPWireRecorder.reset(replies: [.failure(.cannotFindHost)])

      do {
        _ = try await makeTransport().data(
          for: URLRequest(url: url), policy: HTTPRequestPolicy(), progress: { _ in }
        )
        XCTFail("Expected an error")
      } catch {
        XCTAssertEqual((error as? URLError)?.code, .cannotFindHost)
      }
    }

    func testDataCancellationThrowsCancellationError() async {
      let transport = URLSessionTransport { $0.protocolClasses = [UnansweredURLProtocol.self] }
      let url = self.url
      let task = Task {
        try await transport.data(for: URLRequest(url: url), policy: HTTPRequestPolicy(),
                                 progress: { _ in })
      }
      await UnansweredURLProtocol.waitForRequest()

      task.cancel()

      do {
        _ = try await task.value
        XCTFail("Expected cancellation")
      } catch {
        XCTAssertTrue(error is CancellationError, "\(error)")
      }
      await assertNoTrackedTasks(transport)
    }

    // MARK: - Downloads

    // Apple platforms only: FoundationNetworking's URLProtocol support can't run this test on
    // Linux (see `linuxURLProtocolLimitations`).
    #if canImport(Darwin)
      func testDownloadWritesTheBodyToATemporaryFile() async throws {
        HTTPWireRecorder.reset(replies: [.http(status: 200, headers: lengthHeader, body: body)])
        let transport = makeTransport()
        let progress = ProgressRecorder()

        let (fileURL, response) = try await transport.download(
          .request(URLRequest(url: url)), policy: HTTPRequestPolicy(),
          progress: { progress.record($0) }
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        XCTAssertEqual(try Data(contentsOf: fileURL), body)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(progress.values.last, completeProgress)
        XCTAssertEqual(transport.trackedTaskCount, 0)
      }
    #endif

    // Apple platforms only: FoundationNetworking's URLProtocol support can't run this test on
    // Linux (see `linuxURLProtocolLimitations`).
    #if canImport(Darwin)
      func testDownloadWritesTheBodyOfAnHTTPErrorToTheFile() async throws {
        HTTPWireRecorder.reset(replies: [.http(status: 404, body: body)])

        let (fileURL, response) = try await makeTransport().download(
          .request(URLRequest(url: url)), policy: HTTPRequestPolicy(), progress: { _ in }
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        XCTAssertEqual(try Data(contentsOf: fileURL), body)
        XCTAssertEqual(response.statusCode, 404)
      }
    #endif

    func testDownloadThrowsTransportErrors() async {
      HTTPWireRecorder.reset(replies: [.failure(.cannotFindHost)])

      do {
        _ = try await makeTransport().download(
          .request(URLRequest(url: url)), policy: HTTPRequestPolicy(), progress: { _ in }
        )
        XCTFail("Expected an error")
      } catch {
        XCTAssertEqual((error as? URLError)?.code, .cannotFindHost)
      }
    }

    func testDownloadCancellationThrowsHTTPDownloadCancellation() async {
      let transport = URLSessionTransport { $0.protocolClasses = [UnansweredURLProtocol.self] }
      let url = self.url
      let task = Task {
        try await transport.download(.request(URLRequest(url: url)), policy: HTTPRequestPolicy(),
                                     progress: { _ in })
      }
      await UnansweredURLProtocol.waitForRequest()

      task.cancel()

      do {
        _ = try await task.value
        XCTFail("Expected cancellation")
      } catch {
        XCTAssertTrue(error is HTTPDownloadCancellation, "\(error)")
      }
      await assertNoTrackedTasks(transport)
    }

    func testCancelledDownloadDoesNotSendTheRequest() async {
      let transport = makeTransport()
      let url = self.url
      let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await transport.download(.request(URLRequest(url: url)),
                                            policy: HTTPRequestPolicy(), progress: { _ in })
      }

      do {
        _ = try await task.value
        XCTFail("Expected cancellation")
      } catch {
        XCTAssertTrue(error is HTTPDownloadCancellation, "\(error)")
      }
      XCTAssertTrue(HTTPWireRecorder.requests.isEmpty)
    }

    // Apple platforms only: FoundationNetworking's URLProtocol support can't run this test on
    // Linux (see `linuxURLProtocolLimitations`).
    #if canImport(Darwin)
      func testDownloadRedirectsFollowTheRedirectPolicy() async throws {
        let url = self.url
        let body = self.body
        HTTPWireRecorder.reset { request in
          if request.url == url {
            return .redirect(status: 302, location: URL(string: "https://other.example/object")!)
          }
          return .http(status: 200, body: body)
        }
        var request = URLRequest(url: url)
        request.setValue("Firebase token", forHTTPHeaderField: "Authorization")
        request.setValue("app-check-token", forHTTPHeaderField: "X-Firebase-AppCheck")

        let (fileURL, _) = try await makeTransport().download(
          .request(request), policy: HTTPRequestPolicy(), progress: { _ in }
        )
        try? FileManager.default.removeItem(at: fileURL)

        let requests = HTTPWireRecorder.requests
        XCTAssertEqual(requests.map(\.url.absoluteString),
                       [url.absoluteString, "https://other.example/object"])
        XCTAssertEqual(requests.first?.header("Authorization"), "Firebase token")
        XCTAssertNil(requests.last?.header("Authorization"))
        XCTAssertNil(requests.last?.header("X-Firebase-AppCheck"))
      }
    #endif

    // MARK: - Resuming downloads

    // Apple platforms only: FoundationNetworking's URLProtocol support can't run this test on
    // Linux (see `linuxURLProtocolLimitations`).
    #if canImport(Darwin)
      func testCancelledDownloadResumesFromWhereItStopped() async throws {
        let transport = URLSessionTransport { $0.protocolClasses = [PartialContentURLProtocol.self]
        }
        var request = URLRequest(url: url)
        request.setValue("Firebase token", forHTTPHeaderField: "Authorization")
        let firstPartLength = Int64(PartialContentURLProtocol.firstPartLength)
        let firstPartWritten = expectation(description: "The first part of the body was written")
        firstPartWritten.assertForOverFulfill = false
        let download = Task {
          try await transport.download(.request(request), policy: HTTPRequestPolicy()) { progress in
            if progress.completedBytes == firstPartLength {
              firstPartWritten.fulfill()
            }
          }
        }
        await fulfillment(of: [firstPartWritten], timeout: 10)

        download.cancel()

        let resumeData: Data
        do {
          _ = try await download.value
          XCTFail("Expected cancellation")
          return
        } catch let cancellation as HTTPDownloadCancellation {
          resumeData = try XCTUnwrap(cancellation.resumeData)
        }
        let progress = ProgressRecorder()
        let (fileURL, response) = try await transport.download(
          .resumeData(resumeData), policy: HTTPRequestPolicy(), progress: { progress.record($0) }
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        XCTAssertEqual(response.statusCode, 206)
        XCTAssertEqual(try Data(contentsOf: fileURL), PartialContentURLProtocol.body)
        XCTAssertEqual(progress.values.last?.completedBytes,
                       Int64(PartialContentURLProtocol.body.count))
        let resumedRequest = try XCTUnwrap(PartialContentURLProtocol.requests.last)
        XCTAssertEqual(
          resumedRequest.value(forHTTPHeaderField: "Range"),
          "bytes=\(firstPartLength)-"
        )
        XCTAssertEqual(resumedRequest.value(forHTTPHeaderField: "Authorization"), "Firebase token")
        await assertNoTrackedTasks(transport)
      }
    #endif

    func testDownloadCancelledBeforeItStartsHandsBackItsResumeData() async {
      let transport = makeTransport()
      let resumeData = Data("resume data".utf8)
      let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await transport.download(.resumeData(resumeData),
                                            policy: HTTPRequestPolicy(), progress: { _ in })
      }

      do {
        _ = try await task.value
        XCTFail("Expected cancellation")
      } catch {
        XCTAssertEqual((error as? HTTPDownloadCancellation)?.resumeData, resumeData, "\(error)")
      }
      XCTAssertEqual(transport.trackedTaskCount, 0)
    }

    // MARK: - Files that the caller doesn't receive

    // These tests replay orders of `URLSession` callbacks on a `TaskTransfer`, because a
    // `URLProtocol` can't make a task end with an error after its download finished.

    func testDownloadedFileIsDeletedWhenTheTaskFailsAfterTheBodyArrives() async throws {
      let transfer = TaskTransfer(kind: .download(resumeData: nil), progress: { _ in })
      let fileURL = try finishDownloading(transfer)

      do {
        let _: (TaskTransfer.Body, HTTPURLResponse) = try await withCheckedThrowingContinuation {
          continuation in
          transfer.setContinuation(continuation)
          transfer.didComplete(response: nil, error: URLError(.networkConnectionLost))
        }
        XCTFail("Expected an error")
      } catch {
        XCTAssertEqual((error as? URLError)?.code, .networkConnectionLost)
      }
      XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testDownloadedFileIsDeletedWhenTheCancellationCompletesFirst() async throws {
      let session = URLSession(configuration: .ephemeral)
      defer { session.invalidateAndCancel() }
      let transfer = TaskTransfer(kind: .download(resumeData: nil), progress: { _ in })
      transfer.cancel()

      do {
        let _: (TaskTransfer.Body, HTTPURLResponse) = try await withCheckedThrowingContinuation {
          continuation in
          transfer.setContinuation(continuation)
          // The transfer is already cancelled, so this asks the task for resume data instead of
          // resuming it. The resume data completes the continuation.
          transfer.start(session.downloadTask(with: url))
        }
        XCTFail("Expected cancellation")
      } catch {
        XCTAssertTrue(error is HTTPDownloadCancellation, "\(error)")
      }
      // The task can still report a finished download before its last callback.
      let fileURL = try finishDownloading(transfer)
      transfer.didComplete(response: nil, error: URLError(.cancelled))

      XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Uploads

    // Apple platforms only: FoundationNetworking's URLProtocol support can't run this test on
    // Linux (see `linuxURLProtocolLimitations`).
    #if canImport(Darwin)
      func testUploadSendsTheBodyAndReturnsTheResponse() async throws {
        let responseBody = Data("Uploaded".utf8)
        HTTPWireRecorder.reset(replies: [.http(status: 200, body: responseBody)])
        let transport = makeTransport()
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        let (data, response) = try await transport.upload(
          request, from: .data(body), policy: HTTPRequestPolicy(), progress: { _ in }
        )

        XCTAssertEqual(data, responseBody)
        XCTAssertEqual(response.statusCode, 200)
        let recorded = try HTTPWireRecorder.singleRequest()
        XCTAssertEqual(recorded.method, "PUT")
        XCTAssertEqual(recorded.body, body)
        await assertNoTrackedTasks(transport)
      }
    #endif

    // Apple platforms only: FoundationNetworking's URLProtocol support can't run this test on
    // Linux (see `linuxURLProtocolLimitations`).
    #if canImport(Darwin)
      func testUploadFromAFileSendsTheFile() async throws {
        HTTPWireRecorder.reset(replies: [.http(status: 200)])
        let fileURL = FileManager.default.temporaryDirectory
          .appendingPathComponent("HTTPTransferTests-\(UUID().uuidString)")
        try body.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        _ = try await makeTransport().upload(request, from: .file(fileURL),
                                             policy: HTTPRequestPolicy(), progress: { _ in })

        XCTAssertEqual(try HTTPWireRecorder.singleRequest().body, body)
      }
    #endif

    func testUploadReturnsTheBodyOfAnHTTPError() async throws {
      HTTPWireRecorder.reset(replies: [.http(status: 403, body: body)])

      let (data, response) = try await makeTransport().upload(
        URLRequest(url: url), from: .data(Data("x".utf8)), policy: HTTPRequestPolicy(),
        progress: { _ in }
      )

      XCTAssertEqual(data, body)
      XCTAssertEqual(response.statusCode, 403)
    }

    func testUploadCancellationThrowsCancellationError() async {
      let transport = URLSessionTransport { $0.protocolClasses = [UnansweredURLProtocol.self] }
      let url = self.url
      let body = self.body
      let task = Task {
        try await transport.upload(URLRequest(url: url), from: .data(body),
                                   policy: HTTPRequestPolicy(), progress: { _ in })
      }
      await UnansweredURLProtocol.waitForRequest()

      task.cancel()

      do {
        _ = try await task.value
        XCTFail("Expected cancellation")
      } catch {
        XCTAssertTrue(error is CancellationError, "\(error)")
      }
      await assertNoTrackedTasks(transport)
    }

    // Apple platforms only: FoundationNetworking's URLProtocol support can't run this test on
    // Linux (see `linuxURLProtocolLimitations`).
    #if canImport(Darwin)
      func testUploadRedirectsDropCredentialsForOtherOrigins() async throws {
        let url = self.url
        HTTPWireRecorder.reset { request in
          if request.url == url {
            return .redirect(status: 307, location: URL(string: "https://other.example/object")!)
          }
          return .http(status: 200)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Firebase token", forHTTPHeaderField: "Authorization")

        _ = try await makeTransport().upload(request, from: .data(body),
                                             policy: HTTPRequestPolicy(), progress: { _ in })

        let requests = HTTPWireRecorder.requests
        XCTAssertEqual(requests.map(\.url.absoluteString),
                       [url.absoluteString, "https://other.example/object"])
        XCTAssertEqual(requests.first?.header("Authorization"), "Firebase token")
        XCTAssertNil(requests.last?.header("Authorization"))
      }
    #endif

    func testDefaultUploadSendsTheBodyAndReportsProgressOnce() async throws {
      let transport = WholeResponseTransport(body: Data())
      let progress = ProgressRecorder()

      _ = try await transport.upload(URLRequest(url: url), from: .data(body),
                                     policy: HTTPRequestPolicy(),
                                     progress: { progress.record($0) })

      XCTAssertEqual(transport.requests.map(\.httpBody), [body])
      XCTAssertEqual(progress.values, [completeProgress])
    }

    func testDefaultUploadFromAFileSendsItsContents() async throws {
      let transport = WholeResponseTransport(body: Data())
      let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("HTTPTransferTests-\(UUID().uuidString)")
      try body.write(to: fileURL)
      defer { try? FileManager.default.removeItem(at: fileURL) }

      _ = try await transport.upload(URLRequest(url: url), from: .file(fileURL),
                                     policy: HTTPRequestPolicy(), progress: { _ in })

      XCTAssertEqual(transport.requests.map(\.httpBody), [body])
    }

    // MARK: - Background session

    // Background sessions only exist on Apple platforms.
    #if canImport(Darwin)
      func testOnlyUploadsFromFilesWithoutCredentialsUseTheBackgroundSession() {
        let fileURL = URL(fileURLWithPath: "/tmp/upload")
        let background = HTTPRequestPolicy(usesBackgroundSession: true)
        let request = URLRequest(url: url)
        func usesBackgroundSession(_ request: URLRequest, _ body: HTTPUploadBody,
                                   _ policy: HTTPRequestPolicy) -> Bool {
          URLSessionTransport.usesBackgroundSession(for: request, body: body, policy: policy)
        }

        XCTAssertTrue(usesBackgroundSession(request, .file(fileURL), background))
        XCTAssertFalse(usesBackgroundSession(request, .file(fileURL), HTTPRequestPolicy()))
        XCTAssertFalse(usesBackgroundSession(request, .data(body), background))
        for credentialHeader in ["Authorization", "x-firebase-appcheck", "X-Goog-Api-Key"] {
          var credentialed = request
          credentialed.setValue("secret", forHTTPHeaderField: credentialHeader)
          XCTAssertFalse(usesBackgroundSession(credentialed, .file(fileURL), background),
                         credentialHeader)
        }
      }

      func testBackgroundConfigurationRequiresTLS12AndStoresNothing() {
        let configuration = URLSessionTransport.backgroundConfiguration(identifier: "test")

        XCTAssertEqual(configuration.identifier, "test")
        XCTAssertEqual(configuration.tlsMinimumSupportedProtocolVersion, .TLSv12)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertNil(configuration.urlCache)
      }

    #else
      func testNoUploadsUseABackgroundSession() {
        let fileURL = URL(fileURLWithPath: "/tmp/upload")
        let request = URLRequest(url: url)

        let usesBackgroundSession = URLSessionTransport.usesBackgroundSession(
          for: request, body: .file(fileURL), policy: HTTPRequestPolicy(usesBackgroundSession: true)
        )

        XCTAssertFalse(usesBackgroundSession,
                       "FoundationNetworking on Linux has no background sessions")
      }
    #endif

    // MARK: - FirebaseHTTPClient

    func testClientUploadAddsTheUserAgent() async throws {
      HTTPWireRecorder.reset(replies: [.http(status: 200)])
      let client = FirebaseHTTPClient(transport: makeTransport())

      _ = try await client.upload(URLRequest(url: url), from: .data(body), progress: { _ in })

      XCTAssertEqual(try HTTPWireRecorder.singleRequest().header("User-Agent"),
                     FirebaseUserAgent.standard)
    }

    // Apple platforms only: FoundationNetworking's URLProtocol support can't run this test on
    // Linux (see `linuxURLProtocolLimitations`).
    #if canImport(Darwin)
      func testClientDownloadAddsTheUserAgentAndHoldsABackgroundTask() async throws {
        HTTPWireRecorder.reset(replies: [.http(status: 200, body: body)])
        let application = FakeBackgroundTaskApplication()
        let client = FirebaseHTTPClient(transport: makeTransport(),
                                        backgroundTaskApplication: { application },
                                        appAllowsArbitraryLoads: false)

        let (fileURL, _) = try await client.download(.request(URLRequest(url: url)),
                                                     progress: { _ in })
        try? FileManager.default.removeItem(at: fileURL)

        XCTAssertEqual(try HTTPWireRecorder.singleRequest().header("User-Agent"),
                       FirebaseUserAgent.standard)
        XCTAssertEqual(application.begunIdentifiers, [1])
        XCTAssertEqual(application.endedIdentifiers, [1])
      }
    #endif

    func testClientDataWithProgressAddsTheUserAgent() async throws {
      HTTPWireRecorder.reset(replies: [.http(status: 200, body: body)])
      let client = FirebaseHTTPClient(transport: makeTransport())

      let (data, _) = try await client.data(for: URLRequest(url: url), progress: { _ in })

      XCTAssertEqual(data, body)
      XCTAssertEqual(try HTTPWireRecorder.singleRequest().header("User-Agent"),
                     FirebaseUserAgent.standard)
    }

    func testClientRejectsInsecureDownloads() async {
      let client = FirebaseHTTPClient(transport: makeTransport(),
                                      backgroundTaskApplication: { nil },
                                      appAllowsArbitraryLoads: true)
      let insecureURL = URL(string: "http://example.com/object")!

      do {
        _ = try await client.download(.request(URLRequest(url: insecureURL)), progress: { _ in })
        XCTFail("Expected an error")
      } catch {
        XCTAssertEqual((error as? URLError)?.code, .appTransportSecurityRequiresSecureConnection)
      }
      XCTAssertTrue(HTTPWireRecorder.requests.isEmpty)
    }

    // MARK: - Default implementations

    func testDefaultDataWithProgressReportsTheWholeBodyOnce() async throws {
      let transport = WholeResponseTransport(body: body)
      let progress = ProgressRecorder()

      let (data, _) = try await transport.data(
        for: URLRequest(url: url), policy: HTTPRequestPolicy(), progress: { progress.record($0) }
      )

      XCTAssertEqual(data, body)
      XCTAssertEqual(progress.values, [completeProgress])
    }

    func testDefaultDownloadWritesATemporaryFile() async throws {
      let transport = WholeResponseTransport(body: body)

      let (fileURL, response) = try await transport.download(
        .request(URLRequest(url: url)), policy: HTTPRequestPolicy(), progress: { _ in }
      )
      defer { try? FileManager.default.removeItem(at: fileURL) }

      XCTAssertEqual(try Data(contentsOf: fileURL), body)
      XCTAssertEqual(response.statusCode, 200)
    }

    func testDefaultDownloadCannotResume() async {
      do {
        _ = try await WholeResponseTransport(body: body).download(
          .resumeData(Data()), policy: HTTPRequestPolicy(), progress: { _ in }
        )
        XCTFail("Expected an error")
      } catch {
        XCTAssertEqual((error as? URLError)?.code, .unsupportedURL)
      }
    }

    func testDefaultDownloadTurnsCancellationIntoHTTPDownloadCancellation() async {
      let transport = WholeResponseTransport(body: body, error: CancellationError())

      do {
        _ = try await transport.download(.request(URLRequest(url: url)),
                                         policy: HTTPRequestPolicy(), progress: { _ in })
        XCTFail("Expected an error")
      } catch {
        XCTAssertNil((error as? HTTPDownloadCancellation)?.resumeData)
        XCTAssertTrue(error is HTTPDownloadCancellation, "\(error)")
      }
    }

    // MARK: - Helpers

    private var lengthHeader: [String: String] {
      ["Content-Length": "\(body.count)"]
    }

    private var completeProgress: HTTPTransferProgress {
      HTTPTransferProgress(completedBytes: Int64(body.count), expectedBytes: Int64(body.count))
    }

    private func makeTransport() -> URLSessionTransport {
      URLSessionTransport { HTTPWireRecorder.install(in: $0) }
    }

    /// Hands `transfer` a finished download, as `URLSession` does, and returns the file that
    /// `transfer` moved it to.
    private func finishDownloading(_ transfer: TaskTransfer) throws -> URL {
      let location = FileManager.default.temporaryDirectory
        .appendingPathComponent("HTTPTransferTests-\(UUID().uuidString)")
      try body.write(to: location)
      transfer.didFinishDownloading(to: location)
      let fileURL = try XCTUnwrap(transfer.downloadedFileURL)
      XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
      return fileURL
    }

    /// Waits up to a second for the session delegate to drop the task's registrations. A
    /// cancelled download can complete its caller before `URLSession` reports the cancellation.
    private func assertNoTrackedTasks(_ transport: URLSessionTransport,
                                      file: StaticString = #filePath,
                                      line: UInt = #line) async {
      for _ in 0 ..< 100 where transport.trackedTaskCount > 0 {
        try? await Task.sleep(nanoseconds: 10_000_000)
      }
      XCTAssertEqual(transport.trackedTaskCount, 0, file: file, line: line)
    }
  }

  /// Records the progress values it receives.
  private final class ProgressRecorder: Sendable {
    private let recorded = LockedValue<[HTTPTransferProgress]>([])

    var values: [HTTPTransferProgress] {
      recorded.value()
    }

    func record(_ progress: HTTPTransferProgress) {
      recorded.withLock { $0.append(progress) }
    }
  }

  /// Implements only `data(for:policy:)`, so it uses the default transfers.
  private final class WholeResponseTransport: HTTPTransport, @unchecked Sendable {
    private let body: Data
    private let error: (any Error)?
    private let recordedRequests = LockedValue<[URLRequest]>([])

    /// The requests that the transport got, in order.
    var requests: [URLRequest] {
      recordedRequests.value()
    }

    init(body: Data, error: (any Error)? = nil) {
      self.body = body
      self.error = error
    }

    func data(for request: URLRequest,
              policy: HTTPRequestPolicy) async throws -> (Data, HTTPURLResponse) {
      recordedRequests.withLock { $0.append(request) }
      if let error {
        throw error
      }
      let response = try XCTUnwrap(HTTPURLResponse(
        url: XCTUnwrap(request.url), statusCode: 200, httpVersion: "HTTP/1.1",
        headerFields: ["Content-Length": "\(body.count)"]
      ))
      return (body, response)
    }
  }

  /// Answers a request with the first part of `body` and then stalls, so that the download stays
  /// in flight until it's cancelled. Answers a request for a range, as a resumed download sends,
  /// with the rest of `body`.
  private final class PartialContentURLProtocol: URLProtocol {
    static let body = Data((0 ..< 50000).map { UInt8($0 % 251) })
    static let firstPartLength = 20000
    private static let etag = "\"version-1\""
    private static let receivedRequests = LockedValue<[URLRequest]>([])

    /// The requests that started loading, in order.
    static var requests: [URLRequest] {
      receivedRequests.value()
    }

    override class func canInit(with request: URLRequest) -> Bool {
      true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
      request
    }

    override func startLoading() {
      Self.receivedRequests.withLock { $0.append(request) }
      let body = Self.body
      guard let url = request.url else {
        client?.urlProtocol(self, didFailWithError: URLError(.badURL))
        return
      }
      if let range = request.value(forHTTPHeaderField: "Range"),
         let start = Int(range.dropFirst("bytes=".count).dropLast()) {
        let rest = body.subdata(in: start ..< body.count)
        let response = HTTPURLResponse(url: url, statusCode: 206, httpVersion: "HTTP/1.1",
                                       headerFields: [
                                         "Content-Length": "\(rest.count)",
                                         "Content-Range": "bytes \(start)-\(body.count - 1)/\(body.count)",
                                         "ETag": Self.etag,
                                       ])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: rest)
        client?.urlProtocolDidFinishLoading(self)
        return
      }
      let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                     headerFields: [
                                       "Content-Length": "\(body.count)",
                                       "Accept-Ranges": "bytes",
                                       "ETag": Self.etag,
                                     ])!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: body.prefix(Self.firstPartLength))
    }

    override func stopLoading() {}
  }

#endif // (COCOAPODS || SWIFT_PACKAGE) && !os(watchOS)
