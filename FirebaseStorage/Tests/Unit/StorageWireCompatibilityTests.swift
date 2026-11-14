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

import FirebaseCore
import FirebaseCoreInternal
@testable import FirebaseStorage
import Foundation
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif
#if SWIFT_PACKAGE
  import FirebaseWireCompatibilityTestingSupport
#endif
import SharedTestUtilities
import XCTest

// Custom `URLProtocol` classes can't intercept `URLSession` traffic on watchOS. `HTTPWireRecorder`
// lives in FirebaseTestingSupport, which only the SwiftPM and CocoaPods builds include.
#if (COCOAPODS || SWIFT_PACKAGE) && !os(watchOS)

  /// Pins the HTTP behavior of FirebaseStorage: what each operation sends, how the resumable upload
  /// protocol is spoken, which failures are retried, and the shape of the resulting errors.
  ///
  /// The expectations describe the GTMSessionFetcher-based implementation, and they must keep
  /// passing after GTMSessionFetcher is replaced. Only `makeStorage(emulatorPort:)`, which routes
  /// the SDK's traffic through `HTTPWireRecorder`, should need to change. An intentional behavior
  /// change must update its expectation and explain why.
  class StorageWireCompatibilityTests: StorageTestHelpers {
    private let authToken = "auth-token"
    private let objectPath = "path/to/object"
    private let objectURL =
      "https://firebasestorage.googleapis.com:443/v0/b/bucket/o/path%2Fto%2Fobject"

    private static let metadataJSON = #"""
    {"bucket":"bucket","name":"path/to/object","contentType":"text/plain","size":"14",
     "generation":"1","metageneration":"1","downloadTokens":"token1,token2"}
    """#

    override func setUp() {
      super.setUp()
      HTTPWireRecorder.reset()
    }

    override func tearDown() {
      HTTPWireRecorder.reset()
      super.tearDown()
    }

    // MARK: - Control-plane requests

    func testGetMetadataRequest() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, Self.metadataJSON)])
      let storage = await makeStorage()

      let metadata = try await storage.reference(withPath: objectPath).getMetadata()

      XCTAssertEqual(metadata.path, objectPath)
      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(request.method, "GET")
      XCTAssertEqual(request.url.absoluteString, objectURL)
      XCTAssertTrue(request.body.isEmpty)
      XCTAssertEqual(request.timeoutInterval, storage.maxOperationRetryTime)
      XCTAssertEqual(request.header("User-Agent"), standardUserAgent)
      assertAuthorizedHeaders(of: request)
    }

    func testUpdateMetadataRequest() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, Self.metadataJSON)])
      let storage = await makeStorage()
      let update = StorageMetadata()
      update.contentType = "text/plain"
      update.customMetadata = ["key": "value"]

      _ = try await storage.reference(withPath: objectPath).updateMetadata(update)

      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(request.method, "PATCH")
      XCTAssertEqual(request.url.absoluteString, objectURL)
      XCTAssertEqual(request.header("Content-Type"), "application/json; charset=UTF-8")
      XCTAssertEqual(request.header("Content-Length"), "\(request.body.count)")
      let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? NSDictionary)
      XCTAssertEqual(body["contentType"] as? String, "text/plain")
      XCTAssertEqual(body["metadata"] as? NSDictionary, ["key": "value"])
      XCTAssertEqual(request.timeoutInterval, storage.maxOperationRetryTime)
      XCTAssertEqual(request.header("User-Agent"), standardUserAgent)
      assertAuthorizedHeaders(of: request)
    }

    func testDeleteRequest() async throws {
      HTTPWireRecorder.reset(replies: [.http(status: 204)])
      let storage = await makeStorage()

      try await storage.reference(withPath: objectPath).delete()

      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(request.method, "DELETE")
      XCTAssertEqual(request.url.absoluteString, objectURL)
      XCTAssertEqual(request.timeoutInterval, storage.maxOperationRetryTime)
      XCTAssertEqual(request.header("User-Agent"), standardUserAgent)
      assertAuthorizedHeaders(of: request)
    }

    func testListRequest() async throws {
      HTTPWireRecorder.reset(replies: [.json(
        status: 200,
        #"{"prefixes":["path/to/dir/"],"items":[{"name":"path/to/file"}],"nextPageToken":"next"}"#
      )])
      let storage = await makeStorage()

      let result = try await storage.reference(withPath: "path/to")
        .list(maxResults: 10, pageToken: "token")

      XCTAssertEqual(result.pageToken, "next")
      XCTAssertEqual(result.prefixes.map(\.fullPath), ["path/to/dir"])
      XCTAssertEqual(result.items.map(\.fullPath), ["path/to/file"])
      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(request.method, "GET")
      XCTAssertEqual(request.url.host, "firebasestorage.googleapis.com")
      XCTAssertEqual(request.url.path, "/v0/b/bucket/o")
      XCTAssertEqual(
        request.queryItems,
        ["prefix": "path/to/", "delimiter": "/", "maxResults": "10", "pageToken": "token"]
      )
      XCTAssertEqual(request.timeoutInterval, storage.maxOperationRetryTime)
      assertAuthorizedHeaders(of: request)
    }

    func testDownloadURLRequest() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, Self.metadataJSON)])
      let storage = await makeStorage()

      let downloadURL = try await storage.reference(withPath: objectPath).downloadURL()

      XCTAssertEqual(downloadURL.absoluteString, "\(objectURL)?alt=media&token=token1")
      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(request.method, "GET")
      XCTAssertEqual(request.url.absoluteString, objectURL)
      assertAuthorizedHeaders(of: request)
    }

    // MARK: - Downloads

    func testGetDataRequest() async throws {
      let content = Data("Hello, Storage!".utf8)
      HTTPWireRecorder.reset(replies: [
        .http(status: 200, headers: ["Content-Type": "text/plain"], body: content),
      ])
      let storage = await makeStorage()

      let data = try await storage.reference(withPath: objectPath).data(maxSize: 1024)

      XCTAssertEqual(data, content)
      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(request.method, "GET")
      XCTAssertEqual(request.url.absoluteString, "\(objectURL)?alt=media")
      XCTAssertEqual(request.timeoutInterval, storage.maxDownloadRetryTime)
      XCTAssertEqual(request.header("User-Agent"), standardUserAgent)
      assertAuthorizedHeaders(of: request)
    }

    func testWriteToFileRequest() async throws {
      let content = Data("Hello, file!".utf8)
      HTTPWireRecorder.reset(replies: [
        .http(status: 200, headers: ["Content-Type": "text/plain"], body: content),
      ])
      let storage = await makeStorage()
      let fileURL = try temporaryFileURL()

      let writtenURL = try await storage.reference(withPath: objectPath).writeAsync(toFile: fileURL)

      XCTAssertEqual(writtenURL, fileURL)
      XCTAssertEqual(try Data(contentsOf: fileURL), content)
      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(request.method, "GET")
      XCTAssertEqual(request.url.absoluteString, "\(objectURL)?alt=media")
      XCTAssertEqual(request.timeoutInterval, storage.maxDownloadRetryTime)
      XCTAssertEqual(request.header("User-Agent"), standardUserAgent)
      assertAuthorizedHeaders(of: request)
    }

    // MARK: - Resumable uploads

    func testPutDataUsesResumableUploadProtocol() async throws {
      let content = Data("Hello, upload!".utf8)
      HTTPWireRecorder.reset(responder: Self.resumableUploadResponder)
      let storage = await makeStorage()

      let metadata = try await storage.reference(withPath: objectPath).putDataAsync(content)

      XCTAssertEqual(metadata.path, objectPath)
      let requests = HTTPWireRecorder.requests
      XCTAssertEqual(requests.count, 2)
      let start = try XCTUnwrap(requests.first)
      assertStartRequest(start, contentType: "application/octet-stream", length: content.count)
      XCTAssertEqual(start.timeoutInterval, storage.maxUploadRetryTime)
      let upload = try XCTUnwrap(requests.last)
      assertUploadRequest(upload, content: content, offset: 0, isFileUpload: false)
      XCTAssertEqual(upload.timeoutInterval, storage.maxUploadRetryTime)
    }

    #if targetEnvironment(simulator)
      // On devices and macOS, file uploads use a background `URLSession`, which ignores custom
      // `URLProtocol` classes. Simulators use a foreground session.
      func testPutFileUsesResumableUploadProtocol() async throws {
        let content = Data("Hello, file upload!".utf8)
        let fileURL = try temporaryFileURL()
        try content.write(to: fileURL)
        HTTPWireRecorder.reset(responder: Self.resumableUploadResponder)
        let storage = await makeStorage()

        let metadata = try await storage.reference(withPath: objectPath).putFileAsync(from: fileURL)

        XCTAssertEqual(metadata.path, objectPath)
        let requests = HTTPWireRecorder.requests
        XCTAssertEqual(requests.count, 2)
        let start = try XCTUnwrap(requests.first)
        assertStartRequest(start, contentType: "text/plain", length: content.count)
        let upload = try XCTUnwrap(requests.last)
        assertUploadRequest(upload, content: content, offset: 0, isFileUpload: true)
      }
    #endif // targetEnvironment(simulator)

    // MARK: - Errors

    func testHTTPErrorUserInfo() async throws {
      let body = "<html><body><p>Object not found.</p></body></html>"
      let contentType = "text/html; charset=UTF-8"
      HTTPWireRecorder.reset(replies: [
        .http(status: 404, headers: ["Content-Type": contentType], body: Data(body.utf8)),
      ])
      let storage = await makeStorage()

      do {
        _ = try await storage.reference(withPath: objectPath).getMetadata()
        XCTFail("Expected an error")
      } catch {
        let storageError = error as NSError
        XCTAssertEqual(storageError.domain, StorageErrorDomain)
        XCTAssertEqual(storageError.code, StorageErrorCode.objectNotFound.rawValue)
        let userInfo = storageError.userInfo
        XCTAssertEqual(userInfo["ResponseErrorDomain"] as? String, "com.google.HTTPStatus")
        XCTAssertEqual(userInfo["ResponseErrorCode"] as? Int, 404)
        XCTAssertEqual(userInfo["ResponseBody"] as? String, body)
        XCTAssertEqual(userInfo["data"] as? Data, Data(body.utf8))
        XCTAssertEqual(userInfo["data_content_type"] as? String, contentType)
        XCTAssertEqual(userInfo["bucket"] as? String, "bucket")
        XCTAssertEqual(userInfo["object"] as? String, objectPath)
        let underlying = try XCTUnwrap(userInfo[NSUnderlyingErrorKey] as? NSError)
        XCTAssertEqual(underlying.domain, "com.google.HTTPStatus")
        XCTAssertEqual(underlying.code, 404)
        XCTAssertEqual(underlying.userInfo["data"] as? Data, Data(body.utf8))
        XCTAssertEqual(underlying.userInfo["data_content_type"] as? String, contentType)
      }
    }

    func testHTTPStatusMapsToStorageErrorCodeWithoutRetrying() async throws {
      let cases: [(status: Int, code: StorageErrorCode)] = [
        (400, .unknown), (401, .unauthenticated), (402, .quotaExceeded), (403, .unauthorized),
        (404, .objectNotFound), (500, .unknown),
      ]
      let storage = await makeStorage()
      for (status, code) in cases {
        HTTPWireRecorder.reset(replies: [.http(status: status)])
        do {
          _ = try await storage.reference(withPath: objectPath).getMetadata()
          XCTFail("Expected an error for HTTP \(status)")
        } catch {
          let storageError = error as NSError
          XCTAssertEqual(storageError.code, code.rawValue, "HTTP \(status)")
          XCTAssertEqual(storageError.userInfo["ResponseErrorCode"] as? Int, status)
          XCTAssertNil(storageError.userInfo["data"], "HTTP \(status) with an empty body")
        }
        XCTAssertEqual(HTTPWireRecorder.requests.count, 1, "HTTP \(status) must not be retried")
      }
    }

    func testTransportErrorUserInfo() async throws {
      HTTPWireRecorder.reset(replies: [.failure(.cannotFindHost)])
      let storage = await makeStorage()

      do {
        _ = try await storage.reference(withPath: objectPath).getMetadata()
        XCTFail("Expected an error")
      } catch {
        let storageError = error as NSError
        XCTAssertEqual(storageError.domain, StorageErrorDomain)
        XCTAssertEqual(storageError.code, StorageErrorCode.unknown.rawValue)
        XCTAssertEqual(storageError.userInfo["ResponseErrorDomain"] as? String, NSURLErrorDomain)
        XCTAssertEqual(
          storageError.userInfo["ResponseErrorCode"] as? Int, NSURLErrorCannotFindHost
        )
        let underlying = try XCTUnwrap(storageError.userInfo[NSUnderlyingErrorKey] as? NSError)
        XCTAssertEqual(underlying.domain, NSURLErrorDomain)
        XCTAssertEqual(underlying.code, NSURLErrorCannotFindHost)
      }
      XCTAssertEqual(HTTPWireRecorder.requests.count, 1, "cannotFindHost must not be retried")
    }

    // MARK: - Retries

    /// `makeStorage` shortens the backoff delay, so each retry happens right away.
    func testRetryableFailuresAreRetried() async throws {
      let retryableFailures: [HTTPWireRecorder.Reply] = [
        .http(status: 408), .http(status: 502), .http(status: 503), .http(status: 504),
        .failure(.timedOut), .failure(.networkConnectionLost), .failure(.notConnectedToInternet),
      ]
      let storage = await makeStorage()
      for failure in retryableFailures {
        HTTPWireRecorder.reset(replies: [failure, .json(status: 200, Self.metadataJSON)])

        let metadata = try await storage.reference(withPath: objectPath).getMetadata()

        XCTAssertEqual(metadata.path, objectPath, "\(failure)")
        let requests = HTTPWireRecorder.requests
        XCTAssertEqual(requests.count, 2, "\(failure) should be retried once")
        // Retried attempts carry credentials too. Every attempt is authorized again, so a token
        // that expires while the request is retried gets replaced.
        requests.forEach { assertAuthorizedHeaders(of: $0) }
      }
    }

    // MARK: - Emulator

    func testEmulatorRequestsUseHTTP() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, Self.metadataJSON)])
      let storage = await makeStorage(emulatorPort: 9199)

      _ = try await storage.reference(withPath: objectPath).getMetadata()

      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(
        request.url.absoluteString, "http://localhost:9199/v0/b/bucket/o/path%2Fto%2Fobject"
      )
      // Tokens are still attached because the emulator host is a loopback address.
      assertAuthorizedHeaders(of: request)
    }

    // MARK: - User-Agent

    /// The User-Agent that FirebaseCoreInternal builds for the SDKs that no longer use
    /// GTMSessionFetcher must match GTMSessionFetcher's on every platform. Remove this test when
    /// Storage stops depending on GTMSessionFetcher.
    func testFirebaseUserAgentMatchesGTMSessionFetcher() {
      XCTAssertEqual(FirebaseUserAgent.standard, standardUserAgent)
    }

    // MARK: - Helpers

    /// The User-Agent that GTMSessionFetcher sends by default.
    private var standardUserAgent: String {
      GTMFetcherStandardUserAgentString(nil)
    }

    /// The User-Agent of resumable upload requests. GTMSessionUploadFetcher appends `(GTMSUF/1)`
    /// to identify itself in upload server logs. Its replacement won't send that suffix, so this
    /// expectation changes when uploads move off GTMSessionFetcher.
    private var uploadUserAgent: String {
      "\(standardUserAgent) (GTMSUF/1)"
    }

    /// Answers the `start` request with an upload session URL and the upload request with the
    /// final object metadata.
    private static func resumableUploadResponder(_ request: HTTPWireRecorder.Request)
      -> HTTPWireRecorder.Reply {
      if request.header("X-Goog-Upload-Command") == "start" {
        return .http(status: 200, headers: [
          "X-Goog-Upload-Status": "active",
          "X-Goog-Upload-URL": uploadSessionURL,
          "X-Goog-Upload-Chunk-Granularity": "262144",
        ])
      }
      return .json(status: 200, metadataJSON, headers: ["X-Goog-Upload-Status": "final"])
    }

    private static let uploadSessionURL =
      "https://firebasestorage.googleapis.com/upload/storage-session?upload_id=session-id"

    /// Asserts the request that opens a resumable upload session.
    private func assertStartRequest(_ request: HTTPWireRecorder.Request, contentType: String,
                                    length: Int,
                                    file: StaticString = #filePath, line: UInt = #line) {
      XCTAssertEqual(request.method, "POST", file: file, line: line)
      XCTAssertEqual(
        request.url.absoluteString,
        "\(objectURL)?uploadType=resumable&name=path%2Fto%2Fobject",
        file: file, line: line
      )
      let expectedHeaders = [
        "X-Goog-Upload-Protocol": "resumable",
        "X-Goog-Upload-Command": "start",
        "X-Goog-Upload-Content-Type": contentType,
        "X-Goog-Upload-Content-Length": "\(length)",
        "Content-Type": "application/json; charset=UTF-8",
        "Content-Length": "\(request.body.count)",
        "User-Agent": uploadUserAgent,
      ]
      for (name, value) in expectedHeaders {
        assertHeader(name, of: request, equals: value, file: file, line: line)
      }
      assertAuthorizedHeaders(of: request, file: file, line: line)
      let body = (try? JSONSerialization.jsonObject(with: request.body)) as? NSDictionary
      XCTAssertEqual(body?["name"] as? String, objectPath, file: file, line: line)
      XCTAssertEqual(body?["contentType"] as? String, contentType, file: file, line: line)
    }

    /// Asserts a request that uploads bytes to an open upload session. These requests carry no
    /// Firebase credentials: the session URL itself authorizes the upload.
    ///
    /// GTMSessionFetcher sends `X-Goog-Upload-Content-Length` with upload requests only when the
    /// upload comes from a file. For in-memory data, only the `start` request has that header.
    private func assertUploadRequest(_ request: HTTPWireRecorder.Request, content: Data,
                                     offset: Int, isFileUpload: Bool,
                                     file: StaticString = #filePath, line: UInt = #line) {
      XCTAssertEqual(request.method, "PUT", file: file, line: line)
      XCTAssertEqual(request.url.absoluteString, Self.uploadSessionURL, file: file, line: line)
      XCTAssertEqual(request.body, content.subdata(in: offset ..< content.count),
                     file: file, line: line)
      let expectedHeaders: [String: String?] = [
        "X-Goog-Upload-Protocol": "resumable",
        "X-Goog-Upload-Command": "upload, finalize",
        "X-Goog-Upload-Offset": "\(offset)",
        "X-Goog-Upload-Content-Length": isFileUpload ? "\(content.count)" : nil,
        "Content-Length": "\(content.count - offset)",
        "User-Agent": uploadUserAgent,
        "Authorization": nil,
        "X-Firebase-AppCheck": nil,
        "x-firebase-gmpid": nil,
        "x-firebase-storage-version": nil,
      ]
      for (name, value) in expectedHeaders {
        assertHeader(name, of: request, equals: value, file: file, line: line)
      }
    }

    /// Asserts the headers that `StorageTokenAuthorizer` adds to each authorized request.
    private func assertAuthorizedHeaders(of request: HTTPWireRecorder.Request,
                                         file: StaticString = #filePath, line: UInt = #line) {
      let expectedHeaders = [
        "Authorization": "Firebase \(authToken)",
        "X-Firebase-AppCheck": "fake_valid_token",
        "x-firebase-gmpid": app.options.googleAppID,
        "x-firebase-storage-version": "ios/\(FirebaseVersion())",
      ]
      for (name, value) in expectedHeaders {
        assertHeader(name, of: request, equals: value, file: file, line: line)
      }
    }

    /// Asserts the value of the header `name`. An expected value of `nil` means the header must
    /// be absent.
    private func assertHeader(_ name: String, of request: HTTPWireRecorder.Request,
                              equals expected: String?,
                              file: StaticString = #filePath, line: UInt = #line) {
      XCTAssertEqual(request.header(name), expected,
                     "\(name) header of \(request.method) \(request.url)", file: file, line: line)
    }

    /// Returns a `Storage` instance whose HTTP traffic goes through `HTTPWireRecorder`, using fake
    /// Auth and App Check providers that supply tokens.
    private func makeStorage(emulatorPort: Int? = nil) async -> Storage {
      let storage = Storage(
        app: app,
        bucket: "bucket",
        auth: FIRAuthInteropFake(token: authToken, userID: nil, error: nil),
        appCheck: FIRAppCheckFake()
      )
      if let emulatorPort {
        storage.useEmulator(withHost: "localhost", port: emulatorPort)
      }
      // Retry after 1 ms instead of the default 1 to 2 seconds. The interval doesn't change which
      // failures are retried.
      await StorageHTTPService.shared.updateTestTransport(
        URLSessionTransport { HTTPWireRecorder.install(in: $0) }
      )
      await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.001)

      // Uploads and downloads still use GTMSessionFetcher. When they move, route them through
      // the recorder and shorten their retry delay the same way.
      await StorageFetcherService.shared.updateTestBlock(nil)
      let fetcherService = await StorageFetcherService.shared.service(storage)
      fetcherService.configurationBlock = { _, configuration in
        HTTPWireRecorder.install(in: configuration)
      }
      // Set the retry delay on the service, which copies it to every fetcher it creates. The
      // service shares one session between fetchers, so `configurationBlock` only runs for the
      // first one.
      fetcherService.minRetryInterval = 0.001
      return storage
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

#endif // (COCOAPODS || SWIFT_PACKAGE) && !os(watchOS)
