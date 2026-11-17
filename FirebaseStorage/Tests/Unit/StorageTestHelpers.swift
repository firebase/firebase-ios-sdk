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

import FirebaseCore
@_spi(FirebaseNetworking) import FirebaseCoreInternal
@testable import FirebaseStorage

import XCTest

/// Answers the requests of `StorageHTTPService` in unit tests instead of the network.
///
/// It gets each request after `StorageTokenAuthorizer` has added its headers. Downloads to a file
/// get the response written to a temporary file. Uploads get their body in the request's
/// `httpBody`.
final class StorageTestTransport: HTTPTransport, @unchecked Sendable {
  typealias Handler = (URLRequest) async throws -> (Data, HTTPURLResponse)
  typealias ProgressHandler = (URLRequest, @escaping @Sendable (HTTPTransferProgress) -> Void)
  async throws -> (Data, HTTPURLResponse)

  private let handler: ProgressHandler
  private let receivedRequests = UnfairLock<[URLRequest]>([])

  /// The requests that the transport got, in order.
  var requests: [URLRequest] {
    receivedRequests.value()
  }

  init(_ handler: @escaping Handler) {
    self.handler = { request, _ in try await handler(request) }
  }

  /// Creates a transport whose handler can report download progress before it responds.
  init(reportingProgress handler: @escaping ProgressHandler) {
    self.handler = handler
  }

  func data(for request: URLRequest,
            policy: HTTPRequestPolicy) async throws -> (Data, HTTPURLResponse) {
    receivedRequests.withLock { $0.append(request) }
    return try await handler(request) { _ in }
  }

  func data(for request: URLRequest,
            policy: HTTPRequestPolicy,
            progress: @escaping @Sendable (HTTPTransferProgress) -> Void) async throws
    -> (Data, HTTPURLResponse) {
    receivedRequests.withLock { $0.append(request) }
    return try await handler(request, progress)
  }

  /// Returns a response for `request` with `statusCode` and `headers`.
  static func response(to request: URLRequest, statusCode: Int,
                       headers: [String: String]? = nil) throws -> HTTPURLResponse {
    let url = try XCTUnwrap(request.url)
    return try XCTUnwrap(HTTPURLResponse(url: url, statusCode: statusCode,
                                         httpVersion: "HTTP/1.1", headerFields: headers))
  }
}

class StorageTestHelpers: XCTestCase {
  var app: FirebaseApp!

  static var uniqueApp = 0
  func storage() -> Storage {
    return Storage(app: app, bucket: "bucket")
  }

  override func setUp() {
    super.setUp()
    if app == nil {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.projectID = "myProjectID"
      StorageTestHelpers.uniqueApp += 1
      let appName = "test\(StorageTestHelpers.uniqueApp)"
      FirebaseApp.configure(name: appName, options: options)
      app = FirebaseApp.app(name: appName)
    }
    addTeardownBlock {
      await StorageHTTPService.shared.updateTestTransport(nil)
      await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(nil)
    }
  }

  func rootReference() -> StorageReference {
    let path = StoragePath(with: "bucket")
    return StorageReference(storage: storage(), path: path)
  }

  func waitForExpectation(test: XCTest) {
    waitForExpectations(timeout: 10) { error in
      if let error {
        print("Error \(error)")
      }
    }
  }

  func successBlock(withMetadata metadata: StorageMetadata? = nil) -> StorageTestTransport {
    return transport(forData: data(for: metadata), url: nil, statusCode: 200)
  }

  /// The URL of the upload session that `uploadSuccessTransport(withMetadata:)` opens.
  static let uploadSessionURL =
    "https://firebasestorage.googleapis.com/upload/storage-session?upload_id=session-id"

  /// Returns a transport that completes uploads. It answers the `start` request with an upload
  /// session, and the requests that upload bytes with `metadata`.
  func uploadSuccessTransport(withMetadata metadata: StorageMetadata? = nil)
    -> StorageTestTransport {
    let body = data(for: metadata) ?? Data()
    return StorageTestTransport { request in
      try StorageTestHelpers.uploadResponse(to: request, finalBody: body)
    }
  }

  /// Returns the response of a server that opens an upload session for the `start` request,
  /// and finishes the upload with `finalBody` for any other request.
  static func uploadResponse(to request: URLRequest,
                             finalBody: Data) throws -> (Data, HTTPURLResponse) {
    if request.value(forHTTPHeaderField: "X-Goog-Upload-Command") == "start" {
      return try (Data(), StorageTestTransport.response(to: request, statusCode: 200, headers: [
        "X-Goog-Upload-Status": "active",
        "X-Goog-Upload-URL": uploadSessionURL,
        "X-Goog-Upload-Chunk-Granularity": "262144",
      ]))
    }
    return try (finalBody, StorageTestTransport.response(
      to: request, statusCode: 200, headers: ["X-Goog-Upload-Status": "final"]
    ))
  }

  func successBlock(withURL url: URL) -> StorageTestTransport {
    let data = "{}".data(using: .utf8)
    return transport(forData: data, url: url, statusCode: 200)
  }

  func unauthenticatedBlock() -> StorageTestTransport {
    let unauthenticatedString =
      "<html><body><p>User not authenticated. Authentication via Authorization header required. " +
      "Authorization Header does not match expected format of 'Authorization: Firebase " +
      "<JWT>'.</p></body></html>"
    let data = unauthenticatedString.data(using: .utf8)
    return transport(forData: data, url: nil, statusCode: 401)
  }

  func unauthorizedBlock() -> StorageTestTransport {
    let unauthorizedString =
      "<html><body><p>User not authorized. Authentication via Authorization header required. " +
      "Authorization Header does not match expected format of 'Authorization: Firebase " +
      "<JWT>'.</p></body></html>"
    let data = unauthorizedString.data(using: .utf8)
    return transport(forData: data, url: nil, statusCode: 403)
  }

  func notFoundBlock() -> StorageTestTransport {
    let unauthenticatedString = "<html><body><p>Object not found.</p></body></html>"
    let data = unauthenticatedString.data(using: .utf8)
    return transport(forData: data, url: nil, statusCode: 404)
  }

  func invalidJSONBlock() -> StorageTestTransport {
    let string = "This is not a JSON object"
    let data = string.data(using: .utf8)
    return transport(forData: data, url: nil, statusCode: 200)
  }

  private func data(for metadata: StorageMetadata?) -> Data? {
    guard let metadata else {
      return nil
    }
    return try? JSONSerialization.data(withJSONObject: metadata.dictionaryRepresentation())
  }

  private func transport(forData data: Data?, url: URL?,
                         statusCode code: Int) -> StorageTestTransport {
    return StorageTestTransport { request in
      if let url {
        XCTAssertEqual(url, request.url)
      }
      let response = try StorageTestTransport.response(to: request, statusCode: code)
      return (data ?? Data(), response)
    }
  }

  private let objectString = "https://firebasestorage.googleapis.com:443/v0/b/bucket/o/object"

  func objectURL() -> URL {
    return URL(string: objectString)!
  }

  func objectPath() -> StoragePath {
    guard let path = try? StoragePath.path(string: objectString) else {
      fatalError("Failed to get StoragePath")
    }
    return path
  }
}
