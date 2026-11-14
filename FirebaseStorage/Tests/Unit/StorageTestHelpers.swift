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
import FirebaseCoreInternal
@testable import FirebaseStorage
import GTMSessionFetcherCore

import XCTest

/// Answers the requests of `StorageHTTPService` in unit tests instead of the network.
///
/// It gets each request after `StorageTokenAuthorizer` has added its headers, as
/// GTMSessionFetcher's test block did.
final class StorageTestTransport: HTTPTransport, @unchecked Sendable {
  typealias Handler = (URLRequest) async throws -> (Data, HTTPURLResponse)

  private let handler: Handler
  private let receivedRequests = UnfairLock<[URLRequest]>([])

  /// The requests that the transport got, in order.
  var requests: [URLRequest] {
    receivedRequests.value()
  }

  init(_ handler: @escaping Handler) {
    self.handler = handler
  }

  func data(for request: URLRequest,
            policy: HTTPRequestPolicy) async throws -> (Data, HTTPURLResponse) {
    receivedRequests.withLock { $0.append(request) }
    return try await handler(request)
  }

  /// Returns a response for `request` with `statusCode` and no headers.
  static func response(to request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
    let url = try XCTUnwrap(request.url)
    return try XCTUnwrap(HTTPURLResponse(url: url, statusCode: statusCode,
                                         httpVersion: "HTTP/1.1", headerFields: nil))
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
      await StorageFetcherService.shared.updateTestBlock(nil)
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

  /// For uploads, which still use GTMSessionFetcher.
  func successBlock(withMetadata metadata: StorageMetadata? = nil)
    -> GTMSessionFetcherTestBlock {
    return block(forData: data(for: metadata), url: nil, statusCode: 200)
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

  private func block(forData data: Data?, url: URL?,
                     statusCode code: Int) -> GTMSessionFetcherTestBlock {
    let block = { (fetcher: GTMSessionFetcher, response: GTMSessionFetcherTestResponse) in
      let fetcherURL = fetcher.request?.url!
      if let url {
        XCTAssertEqual(url, fetcherURL)
      }
      let httpResponse = HTTPURLResponse(
        url: fetcherURL!,
        statusCode: code,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )
      var error: NSError?
      if code >= 400 {
        var userInfo: [String: Any]?
        if let data {
          userInfo = ["data": data]
        }
        error = NSError(domain: "com.google.HTTPStatus", code: code, userInfo: userInfo)
      }
      response(httpResponse, data, error)
    }
    return block
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
