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

import FirebaseAuthInterop
import FirebaseCoreInternal
@testable import FirebaseStorage
import Foundation
import XCTest

/// Tests the retry and authorization behavior of `StorageHTTPService`. The wire compatibility
/// tests cover which failures are retried.
class StorageHTTPServiceTests: StorageTestHelpers {
  private let metadataJSON = Data(#"{"bucket":"bucket","name":"object"}"#.utf8)

  // MARK: - Authorization

  func testEveryAttemptGetsFreshTokens() async throws {
    let storage = Storage(app: app, bucket: "bucket", auth: CountingAuthFake(), appCheck: nil)
    let transport = scriptedTransport([.http(status: 503), .http(status: 200, body: metadataJSON)])
    await StorageHTTPService.shared.updateTestTransport(transport)
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.001)

    _ = try await send(for: storage)

    XCTAssertEqual(
      transport.requests.map { $0.value(forHTTPHeaderField: "Authorization") },
      ["Firebase token-1", "Firebase token-2"]
    )
  }

  func testAuthorizationErrorsAreReportedWithoutSendingTheRequest() async throws {
    let authError = NSError(domain: "AuthErrorDomain", code: 17020)
    let auth = FailingAuthFake(error: authError)
    let storage = Storage(app: app, bucket: "bucket", auth: auth, appCheck: nil)
    let transport = scriptedTransport([.http(status: 200, body: metadataJSON)])
    await StorageHTTPService.shared.updateTestTransport(transport)

    do {
      _ = try await send(for: storage)
      XCTFail("Expected an error")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, StorageErrorDomain)
      XCTAssertEqual(nsError.code, StorageErrorCode.unauthenticated.rawValue)
      XCTAssertEqual(nsError.userInfo["ResponseErrorDomain"] as? String, "AuthErrorDomain")
      XCTAssertEqual(nsError.userInfo["ResponseErrorCode"] as? Int, 17020)
    }
    XCTAssertEqual(transport.requests.count, 0)
  }

  // MARK: - Retry limits

  func testNoRetriesWhenTheRetryTimeIsZero() async throws {
    let transport = scriptedTransport([.http(status: 503), .http(status: 200, body: metadataJSON)])
    await StorageHTTPService.shared.updateTestTransport(transport)
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.001)

    do {
      _ = try await send(for: storage(), maxRetryTime: 0)
      XCTFail("Expected an error")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, HTTPStatusError.domain)
      XCTAssertEqual(nsError.code, 503)
      XCTAssertNil(nsError.userInfo[StorageHTTPService.numberOfRetriesKey])
      XCTAssertNil(nsError.userInfo[StorageHTTPService.elapsedTimeKey])
    }
    XCTAssertEqual(transport.requests.count, 1)
  }

  func testRetriesStopAtTheRetryTimeAndAreReportedInTheError() async throws {
    let transport = scriptedTransport([.http(status: 503)])
    await StorageHTTPService.shared.updateTestTransport(transport)
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.001)
    let storage = storage()
    storage.maxOperationRetryTime = 0.05

    do {
      _ = try await storage.reference(withPath: "object").getMetadata()
      XCTFail("Expected an error")
    } catch {
      let userInfo = (error as NSError).userInfo
      XCTAssertEqual(userInfo["ResponseErrorDomain"] as? String, HTTPStatusError.domain)
      XCTAssertEqual(userInfo["ResponseErrorCode"] as? Int, 503)
      let retryCount = try XCTUnwrap(userInfo[StorageHTTPService.numberOfRetriesKey] as? Int)
      XCTAssertGreaterThan(retryCount, 0)
      XCTAssertEqual(retryCount, transport.requests.count - 1)
      let elapsedTime = try XCTUnwrap(userInfo[StorageHTTPService.elapsedTimeKey] as? Double)
      XCTAssertGreaterThan(elapsedTime, 0)
      // The last retry starts within the retry time.
      XCTAssertLessThan(elapsedTime, 5)
    }
  }

  func testRetryAfterReplacesTheBackoffDelay() async throws {
    let transport = scriptedTransport([
      .http(status: 503, headers: ["Retry-After": "0"]),
      .http(status: 200, body: metadataJSON),
    ])
    await StorageHTTPService.shared.updateTestTransport(transport)
    // Without the Retry-After header, the retry would wait a minute.
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(60)
    let start = Date()

    _ = try await send(for: storage())

    XCTAssertEqual(transport.requests.count, 2)
    XCTAssertLessThan(Date().timeIntervalSince(start), 30)
  }

  func testOfflineErrorsAreRetriedInAnyDomain() async throws {
    let offline = NSError(domain: "kCFErrorDomainCFNetwork",
                          code: NSURLErrorNotConnectedToInternet)
    let transport = scriptedTransport([.failure(offline), .http(status: 200, body: metadataJSON)])
    await StorageHTTPService.shared.updateTestTransport(transport)
    await StorageHTTPService.shared.updateInitialRetryIntervalForTesting(0.001)

    let body = try await send(for: storage())

    XCTAssertEqual(body, metadataJSON)
    XCTAssertEqual(transport.requests.count, 2)
  }

  // MARK: - Helpers

  private func send(for storage: Storage, maxRetryTime: TimeInterval = 120) async throws -> Data {
    try await StorageHTTPService.shared.data(
      for: URLRequest(url: objectURL()), storage: storage, maxRetryTime: maxRetryTime
    )
  }

  private enum Reply {
    case http(status: Int, headers: [String: String]? = nil, body: Data = Data())
    case failure(Error)
  }

  /// Returns a transport that answers each request with the next reply, and repeats the last reply
  /// once it runs out.
  private func scriptedTransport(_ replies: [Reply]) -> StorageTestTransport {
    let nextReply = UnfairLock(0)
    return StorageTestTransport { request in
      let index = nextReply.withLock { index -> Int in
        defer { index += 1 }
        return min(index, replies.count - 1)
      }
      switch replies[index] {
      case let .http(status, headers, body):
        let url = try XCTUnwrap(request.url)
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status,
                                                     httpVersion: "HTTP/1.1",
                                                     headerFields: headers))
        return (body, response)
      case let .failure(error):
        throw error
      }
    }
  }
}

/// Returns `token-1`, `token-2`, and so on, a new token for each call.
private final class CountingAuthFake: NSObject, AuthInterop, @unchecked Sendable {
  private let tokenCount = UnfairLock(0)

  func getToken(forcingRefresh: Bool, completion handler: @escaping (String?, Error?) -> Void) {
    let count = tokenCount.withLock { count -> Int in
      count += 1
      return count
    }
    handler("token-\(count)", nil)
  }

  func getUserID() -> String? { nil }
}

/// Fails every token request with `error`.
private final class FailingAuthFake: NSObject, AuthInterop, @unchecked Sendable {
  private let error: Error

  init(error: Error) {
    self.error = error
  }

  func getToken(forcingRefresh: Bool, completion handler: @escaping (String?, Error?) -> Void) {
    handler(nil, error)
  }

  func getUserID() -> String? { nil }
}
