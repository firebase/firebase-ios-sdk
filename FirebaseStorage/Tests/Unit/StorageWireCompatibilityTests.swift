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
  /// The expectations were first checked against the previous networking implementation, so they
  /// pin the behavior that apps and the backend rely on. An intentional behavior change must
  /// update its expectation and explain why.
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

    func testDownloadHTTPErrorUserInfo() async throws {
      let body = "<html><body><p>Object not found.</p></body></html>"
      let contentType = "text/html; charset=UTF-8"
      let storage = await makeStorage()
      let reference = storage.reference(withPath: objectPath)
      let fileURL = try temporaryFileURL()
      let downloads: [(name: String, run: () async throws -> Void)] = [
        ("getData", { _ = try await reference.data(maxSize: 1024) }),
        ("write(toFile:)", { _ = try await reference.writeAsync(toFile: fileURL) }),
      ]
      for (name, download) in downloads {
        HTTPWireRecorder.reset(replies: [
          .http(status: 404, headers: ["Content-Type": contentType], body: Data(body.utf8)),
        ])
        do {
          try await download()
          XCTFail("Expected an error from \(name)")
        } catch {
          let storageError = error as NSError
          XCTAssertEqual(storageError.domain, StorageErrorDomain, name)
          XCTAssertEqual(storageError.code, StorageErrorCode.objectNotFound.rawValue, name)
          let userInfo = storageError.userInfo
          XCTAssertEqual(userInfo["ResponseErrorCode"] as? Int, 404, name)
          XCTAssertEqual(userInfo["ResponseBody"] as? String, body, name)
          XCTAssertEqual(userInfo["data"] as? Data, Data(body.utf8), name)
          XCTAssertEqual(userInfo["data_content_type"] as? String, contentType, name)
        }
        XCTAssertEqual(HTTPWireRecorder.requests.count, 1, "\(name) must not retry HTTP 404")
      }
      // The error body isn't written to the destination file.
      XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    /// `makeStorage` shortens the backoff delay, so each retry happens right away.
    func testDownloadRetryableFailuresAreRetried() async throws {
      let content = Data("Hello, retry!".utf8)
      let storage = await makeStorage()
      let reference = storage.reference(withPath: objectPath)
      let fileURL = try temporaryFileURL()
      let downloads: [(name: String, run: () async throws -> Data)] = [
        ("getData", { try await reference.data(maxSize: 1024) }),
        ("write(toFile:)", { try await Data(contentsOf: reference.writeAsync(toFile: fileURL)) }),
      ]
      for (name, download) in downloads {
        HTTPWireRecorder.reset(replies: [.http(status: 503), .http(status: 200, body: content)])

        let data = try await download()

        XCTAssertEqual(data, content, name)
        let requests = HTTPWireRecorder.requests
        XCTAssertEqual(requests.count, 2, "\(name) should retry HTTP 503 once")
        requests.forEach { assertAuthorizedHeaders(of: $0) }
      }
    }

    func testGetDataFailsForObjectsLargerThanMaxSize() async throws {
      let content = Data(count: 2048)
      HTTPWireRecorder.reset(replies: [
        .http(status: 200, headers: ["Content-Length": "\(content.count)"], body: content),
      ])
      let storage = await makeStorage()

      do {
        _ = try await storage.reference(withPath: objectPath).data(maxSize: 1024)
        XCTFail("Expected an error")
      } catch let StorageError.downloadSizeExceeded(total, maxSize) {
        XCTAssertEqual(total, 2048)
        XCTAssertEqual(maxSize, 1024)
      }
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

    func testPutDataSendsChunksOfTheServersGranularity() async throws {
      // A chunk size of 1 rounds up to the granularity. Two full chunks would leave fewer than
      // 2,500 bytes, so the second chunk takes the rest.
      let content = Data((0 ..< (2 * Self.granularity + 1000)).map { UInt8($0 % 251) })
      HTTPWireRecorder.reset { request in
        switch request.header("X-Goog-Upload-Command") {
        case "start":
          return Self.startReply
        case "upload":
          let offset = Int(request.header("X-Goog-Upload-Offset") ?? "") ?? 0
          return .http(status: 200, headers: [
            "X-Goog-Upload-Status": "active",
            "X-Goog-Upload-Size-Received": "\(offset + request.body.count)",
          ])
        default:
          return .json(status: 200, Self.metadataJSON, headers: ["X-Goog-Upload-Status": "final"])
        }
      }
      let storage = await makeStorage()
      storage.uploadChunkSizeBytes = 1

      let metadata = try await storage.reference(withPath: objectPath).putDataAsync(content)

      XCTAssertEqual(metadata.path, objectPath)
      let uploads = Array(HTTPWireRecorder.requests.dropFirst())
      XCTAssertEqual(uploads.map { $0.header("X-Goog-Upload-Command") },
                     ["upload", "upload, finalize"])
      XCTAssertEqual(uploads.map { $0.header("X-Goog-Upload-Offset") },
                     ["0", "\(Self.granularity)"])
      XCTAssertEqual(uploads.map { $0.header("Content-Length") },
                     ["\(Self.granularity)", "\(content.count - Self.granularity)"])
      XCTAssertEqual(uploads.map(\.body),
                     [content.prefix(Self.granularity), content.dropFirst(Self.granularity)])
    }

    /// `makeStorage` shortens the backoff delay, so each retry happens right away.
    func testUploadRetriesAskTheServerHowMuchItReceived() async throws {
      let content = Data("Hello, retried upload!".utf8)
      HTTPWireRecorder.reset(responder: Self.uploadResponder(firstUploadReply: .http(status: 503)))
      let storage = await makeStorage()

      let metadata = try await storage.reference(withPath: objectPath).putDataAsync(content)

      XCTAssertEqual(metadata.path, objectPath)
      let requests = HTTPWireRecorder.requests
      XCTAssertEqual(requests.map { $0.header("X-Goog-Upload-Command") },
                     ["start", "upload, finalize", "query", "upload, finalize"])
      let query = try XCTUnwrap(requests.dropFirst(2).first)
      XCTAssertEqual(query.method, "PUT")
      XCTAssertEqual(query.url.absoluteString, Self.uploadSessionURL)
      XCTAssertEqual(query.header("X-Goog-Upload-Protocol"), "resumable")
      XCTAssertTrue(query.body.isEmpty)
      XCTAssertNil(query.header("Authorization"))
      XCTAssertNil(query.header("X-Firebase-AppCheck"))
      XCTAssertEqual(query.header("User-Agent"), standardUserAgent)
      XCTAssertEqual(query.header("X-GUploader-Client-Info"), clientInfo)
      assertUploadRequest(requests[3], content: content, offset: 0, isFileUpload: false)
    }

    func testUploadsAreResentWhenTheServerRejectsTheOffset() async throws {
      // In the resumable upload protocol, a 4xx response with an active upload status means the
      // server expected a different offset.
      let content = Data("Hello, offset!".utf8)
      HTTPWireRecorder.reset(responder: Self.uploadResponder(
        firstUploadReply: .http(status: 400, headers: ["X-Goog-Upload-Status": "active"])
      ))
      let storage = await makeStorage()

      let metadata = try await storage.reference(withPath: objectPath).putDataAsync(content)

      XCTAssertEqual(metadata.path, objectPath)
      XCTAssertEqual(HTTPWireRecorder.requests.map { $0.header("X-Goog-Upload-Command") },
                     ["start", "upload, finalize", "query", "upload, finalize"])
    }

    func testUploadsFinishWhenTheQueryReportsTheUploadIsFinal() async throws {
      let content = Data("Hello, final query!".utf8)
      HTTPWireRecorder.reset(responder: Self.uploadResponder(
        firstUploadReply: .http(status: 503),
        queryReply: .json(
          status: 200,
          Self.metadataJSON,
          headers: ["X-Goog-Upload-Status": "final"]
        )
      ))
      let storage = await makeStorage()

      let metadata = try await storage.reference(withPath: objectPath).putDataAsync(content)

      XCTAssertEqual(metadata.path, objectPath)
      XCTAssertEqual(HTTPWireRecorder.requests.map { $0.header("X-Goog-Upload-Command") },
                     ["start", "upload, finalize", "query"])
    }

    func testUploadHTTPErrorUserInfo() async throws {
      let body = #"{"error":{"code":403,"message":"Permission denied."}}"#
      HTTPWireRecorder.reset(responder: Self.uploadResponder(
        firstUploadReply: .json(status: 403, body)
      ))
      let storage = await makeStorage()

      do {
        _ = try await storage.reference(withPath: objectPath).putDataAsync(Data("Hi".utf8))
        XCTFail("Expected an error")
      } catch {
        let storageError = error as NSError
        XCTAssertEqual(storageError.domain, StorageErrorDomain)
        XCTAssertEqual(storageError.code, StorageErrorCode.unauthorized.rawValue)
        let userInfo = storageError.userInfo
        XCTAssertEqual(userInfo["ResponseErrorDomain"] as? String, "com.google.HTTPStatus")
        XCTAssertEqual(userInfo["ResponseErrorCode"] as? Int, 403)
        XCTAssertEqual(userInfo["data"] as? Data, Data(body.utf8))
        XCTAssertEqual(userInfo["data_content_type"] as? String,
                       "application/json; charset=UTF-8")
      }
      // HTTP 403 isn't retried, and the upload session is cancelled.
      let requests = await recordedRequests(count: 3)
      XCTAssertEqual(requests.map { $0.header("X-Goog-Upload-Command") },
                     ["start", "upload, finalize", "cancel"])
      let cancel = try XCTUnwrap(requests.last)
      XCTAssertEqual(cancel.method, "PUT")
      XCTAssertEqual(cancel.url.absoluteString, Self.uploadSessionURL)
      XCTAssertTrue(cancel.body.isEmpty)
      let expectedHeaders: [String: String?] = [
        "X-Goog-Upload-Protocol": "resumable",
        "User-Agent": standardUserAgent,
        "X-GUploader-Client-Info": clientInfo,
        "Authorization": nil,
        "X-Firebase-AppCheck": nil,
      ]
      for (name, value) in expectedHeaders {
        assertHeader(name, of: cancel, equals: value)
      }
    }

    func testUploadsFailWhenTheStartResponseHasNoUploadURL() async throws {
      HTTPWireRecorder.reset(replies: [
        .http(status: 200, headers: ["X-Goog-Upload-Status": "active"]),
      ])
      let storage = await makeStorage()

      do {
        _ = try await storage.reference(withPath: objectPath).putDataAsync(Data("Hi".utf8))
        XCTFail("Expected an error")
      } catch {
        let userInfo = (error as NSError).userInfo
        XCTAssertEqual(userInfo["ResponseErrorDomain"] as? String, "com.google.HTTPStatus")
        XCTAssertEqual(userInfo["ResponseErrorCode"] as? Int, 501)
      }
      XCTAssertEqual(HTTPWireRecorder.requests.count, 1)
    }

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

    // MARK: - Helpers

    /// The User-Agent of every request, uploads included. Uploads used to append `(GTMSUF/1)`,
    /// which only named the networking library. `X-GUploader-Client-Info` now identifies the SDK
    /// in the upload server's logs.
    private var standardUserAgent: String {
      FirebaseUserAgent.standard
    }

    /// The `X-GUploader-Client-Info` header of every request of an upload session.
    private var clientInfo: String {
      "mechanism=firebase-ios-storage; clientVersion=\(FirebaseVersion())"
    }

    /// Returns the recorded requests once there are at least `count` of them, or after 10
    /// seconds. Requests that the SDK sends without waiting for them, such as `cancel`, can
    /// arrive after the operation finishes.
    private func recordedRequests(count: Int) async -> [HTTPWireRecorder.Request] {
      for _ in 0 ..< 1000 {
        let requests = HTTPWireRecorder.requests
        if requests.count >= count {
          return requests
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
      }
      return HTTPWireRecorder.requests
    }

    /// Answers the `start` request with an upload session URL and the upload request with the
    /// final object metadata.
    private static func resumableUploadResponder(_ request: HTTPWireRecorder.Request)
      -> HTTPWireRecorder.Reply {
      if request.header("X-Goog-Upload-Command") == "start" {
        return startReply
      }
      return .json(status: 200, metadataJSON, headers: ["X-Goog-Upload-Status": "final"])
    }

    /// Returns a responder that answers the first upload request with `firstUploadReply`, queries
    /// with `queryReply`, and later upload requests with the final object metadata.
    private static func uploadResponder(firstUploadReply: HTTPWireRecorder.Reply,
                                        queryReply: HTTPWireRecorder.Reply = .http(
                                          status: 200,
                                          headers: [
                                            "X-Goog-Upload-Status": "active",
                                            "X-Goog-Upload-Size-Received": "0",
                                          ]
                                        )) -> HTTPWireRecorder.Responder {
      let uploadCount = UnfairLock(0)
      return { request in
        switch request.header("X-Goog-Upload-Command") {
        case "start":
          return startReply
        case "query":
          return queryReply
        case "cancel":
          return .http(status: 200, headers: ["X-Goog-Upload-Status": "cancelled"])
        default:
          let count = uploadCount.withLock { count -> Int in
            count += 1
            return count
          }
          return count == 1
            ? firstUploadReply
            : .json(status: 200, metadataJSON, headers: ["X-Goog-Upload-Status": "final"])
        }
      }
    }

    /// The server's chunk granularity, 256 KiB.
    private static let granularity = 262_144

    /// The reply to a `start` request: an open upload session.
    private static let startReply = HTTPWireRecorder.Reply.http(status: 200, headers: [
      "X-Goog-Upload-Status": "active",
      "X-Goog-Upload-URL": uploadSessionURL,
      "X-Goog-Upload-Chunk-Granularity": "\(granularity)",
    ])

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
        "User-Agent": standardUserAgent,
        "X-GUploader-Client-Info": clientInfo,
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
    /// Upload requests send `X-Goog-Upload-Content-Length` only when the upload comes from a file.
    /// For in-memory data, only the `start` request has that header.
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
        "User-Agent": standardUserAgent,
        "X-GUploader-Client-Info": clientInfo,
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
