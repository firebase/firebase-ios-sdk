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
import XCTest

/// A `URLProtocol` that records each request reaching the URL loading system and answers it with a
/// scripted reply.
///
/// The wire compatibility tests use it to pin what the SDKs send and how they interpret responses,
/// independently of the HTTP client that produces the requests (GTMSessionFetcher today, a native
/// `URLSession` client after the GTMSessionFetcher migration). Install it with `install(in:)` on
/// the configuration of the session under test instead of registering it globally, so that it
/// only sees that session's traffic.
///
/// SwiftPM test targets get it by depending on the `FirebaseWireCompatibilityTestingSupport`
/// target. CocoaPods test specs compile it by listing this file in their `source_files`.
public final class HTTPWireRecorder: URLProtocol, @unchecked Sendable {
  /// A request as observed by the URL loading system.
  public struct Request: Sendable {
    public let url: URL
    public let method: String
    public let headers: [String: String]
    public let body: Data
    public let timeoutInterval: TimeInterval

    /// Returns the value of the header `name`, which is matched case-insensitively.
    public func header(_ name: String) -> String? {
      headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    /// The URL's query items, keyed by name.
    public var queryItems: [String: String] {
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
      return Dictionary(items.map { ($0.name, $0.value ?? "") }) { first, _ in first }
    }
  }

  /// A scripted reply.
  public enum Reply: Sendable {
    /// An HTTP response.
    case http(status: Int, headers: [String: String] = [:], body: Data = Data())
    /// A transport failure, delivered as `URLError(code)`.
    case failure(URLError.Code)
    /// A redirect to `location`. The redirect request handed to the session is built the way the
    /// system builds one for a 301, 302, or 303 response: a `GET` without a body or the original
    /// request's headers.
    case redirect(status: Int, location: URL)

    /// An HTTP response with a UTF-8 JSON body. `headers` can override the JSON `Content-Type`.
    public static func json(status: Int, _ body: String,
                            headers: [String: String] = [:]) -> Reply {
      .http(
        status: status,
        headers: headers.merging(["Content-Type": "application/json; charset=UTF-8"]) { own, _ in
          own
        },
        body: Data(body.utf8)
      )
    }
  }

  public typealias Responder = (Request) -> Reply

  private static let lock = NSLock()
  private nonisolated(unsafe) static var recordedRequests: [Request] = []
  private nonisolated(unsafe) static var responder: Responder?
  private nonisolated(unsafe) static var queuedReplies: [Reply] = []

  /// The requests recorded since the last reset, in the order they started loading.
  public static var requests: [Request] {
    lock.withLock { recordedRequests }
  }

  /// Returns the only request recorded since the last reset. Fails the calling test if no request
  /// or more than one request was recorded.
  public static func singleRequest(file: StaticString = #filePath,
                                   line: UInt = #line) throws -> Request {
    let recorded = requests
    XCTAssertEqual(recorded.count, 1, "Expected exactly one request", file: file, line: line)
    return try XCTUnwrap(recorded.first, file: file, line: line)
  }

  /// Clears the recorded requests and answers later requests with `responder`.
  public static func reset(responder: Responder? = nil) {
    lock.withLock {
      recordedRequests = []
      self.responder = responder
      queuedReplies = []
    }
  }

  /// Clears the recorded requests and answers later requests with `replies`, in order. The last
  /// reply is repeated once the others are used up.
  public static func reset(replies: [Reply]) {
    lock.withLock {
      recordedRequests = []
      responder = nil
      queuedReplies = replies
    }
  }

  /// Routes the traffic of sessions created from `configuration` through the recorder.
  public static func install(in configuration: URLSessionConfiguration) {
    configuration.protocolClasses = [HTTPWireRecorder.self] + (configuration.protocolClasses ?? [])
  }

  // MARK: - URLProtocol

  override public class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override public func startLoading() {
    let recorded = Request(request)
    let (responder, queuedReply) = Self.lock.withLock { () -> (Responder?, Reply?) in
      Self.recordedRequests.append(recorded)
      if Self.queuedReplies.count > 1 {
        return (Self.responder, Self.queuedReplies.removeFirst())
      }
      return (Self.responder, Self.queuedReplies.first)
    }
    // Call the responder outside of the lock so that it can inspect `requests`.
    guard let reply = responder?(recorded) ?? queuedReply else {
      XCTFail("HTTPWireRecorder has no reply for \(recorded.method) \(recorded.url)")
      client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
      return
    }
    deliver(reply, for: recorded.url)
  }

  override public func stopLoading() {}

  private func deliver(_ reply: Reply, for url: URL) {
    guard let client else { return }
    switch reply {
    case let .http(status, headers, body):
      let response = HTTPURLResponse(
        url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
      )!
      client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      if !body.isEmpty {
        client.urlProtocol(self, didLoad: body)
      }
      client.urlProtocolDidFinishLoading(self)
    case let .failure(code):
      client.urlProtocol(self, didFailWithError: URLError(code))
    case let .redirect(status, location):
      let response = HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: ["Location": location.absoluteString]
      )!
      client.urlProtocol(self, wasRedirectedTo: URLRequest(url: location),
                         redirectResponse: response)
    }
  }
}

private extension HTTPWireRecorder.Request {
  init(_ request: URLRequest) {
    url = request.url!
    method = request.httpMethod ?? "GET"
    headers = request.allHTTPHeaderFields ?? [:]
    body = Self.body(of: request)
    timeoutInterval = request.timeoutInterval
  }

  /// Returns the request body. `URLSession` hands bodies to protocols as a stream, both for data
  /// tasks with an `httpBody` and for upload tasks.
  static func body(of request: URLRequest) -> Data {
    if let body = request.httpBody {
      return body
    }
    guard let stream = request.httpBodyStream else {
      return Data()
    }
    stream.open()
    defer { stream.close() }
    var body = Data()
    var buffer = [UInt8](repeating: 0, count: 16 * 1024)
    while true {
      let count = stream.read(&buffer, maxLength: buffer.count)
      guard count > 0 else { break }
      body.append(buffer, count: count)
    }
    return body
  }
}
