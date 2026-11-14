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

@testable import FirebaseCoreInternal
#if SWIFT_PACKAGE
  import FirebaseWireCompatibilityTestingSupport
#endif
import XCTest

// Custom `URLProtocol` classes can't intercept `URLSession` traffic on watchOS. `HTTPWireRecorder`
// lives in FirebaseTestingSupport, which only the SwiftPM and CocoaPods builds include.
#if (COCOAPODS || SWIFT_PACKAGE) && !os(watchOS)

  class URLSessionTransportTests: XCTestCase {
    private let startURL = URL(string: "https://example.com/start")!
    private let body = Data(#"{"data":{"key":"value"}}"#.utf8)

    override func setUp() {
      super.setUp()
      HTTPWireRecorder.reset()
    }

    override func tearDown() {
      HTTPWireRecorder.reset()
      super.tearDown()
    }

    // MARK: - Session

    func testSessionIsEphemeralAndRequiresTLS12() {
      let configuration = URLSessionTransport().session.configuration

      XCTAssertEqual(configuration.tlsMinimumSupportedProtocolVersion, .TLSv12)
      XCTAssertNotNil(configuration.httpCookieStorage)
      XCTAssertFalse(configuration.httpCookieStorage === HTTPCookieStorage.shared)
      XCTAssertFalse(configuration.urlCredentialStorage === URLCredentialStorage.shared)
    }

    func testConfigureAdjustsTheSessionConfiguration() {
      let transport = URLSessionTransport { $0.timeoutIntervalForResource = 42 }

      XCTAssertEqual(transport.session.configuration.timeoutIntervalForResource, 42)
      XCTAssertEqual(transport.session.configuration.tlsMinimumSupportedProtocolVersion, .TLSv12)
    }

    // MARK: - Responses

    func testReturnsTheBodyAndResponseForAnyStatus() async throws {
      HTTPWireRecorder.reset(replies: [
        .http(status: 404, headers: ["Content-Type": "text/plain"], body: Data("missing".utf8)),
      ])

      let (responseBody, response) = try await makeTransport().data(
        for: postRequest(startURL), policy: HTTPRequestPolicy()
      )

      XCTAssertEqual(responseBody, Data("missing".utf8))
      XCTAssertEqual(response.statusCode, 404)
      XCTAssertEqual(response.value(forHTTPHeaderField: "Content-Type"), "text/plain")
      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(request.method, "POST")
      XCTAssertEqual(request.body, body)
      XCTAssertEqual(request.header("Authorization"), "Bearer token")
    }

    func testEmptyBodyIsEmptyData() async throws {
      HTTPWireRecorder.reset(replies: [.http(status: 204)])

      let (responseBody, _) = try await makeTransport().data(for: postRequest(startURL),
                                                             policy: HTTPRequestPolicy())

      XCTAssertTrue(responseBody.isEmpty)
    }

    func testTransportErrorIsThrown() async {
      HTTPWireRecorder.reset(replies: [.failure(.cannotFindHost)])

      do {
        _ = try await makeTransport().data(for: postRequest(startURL), policy: HTTPRequestPolicy())
        XCTFail("Expected an error")
      } catch {
        XCTAssertEqual((error as? URLError)?.code, .cannotFindHost)
      }
    }

    // MARK: - Cancellation

    func testCancellationThrowsCancellationError() async {
      let transport = URLSessionTransport {
        $0.protocolClasses = [UnansweredURLProtocol.self]
      }
      let url = startURL
      let task = Task {
        try await transport.data(for: URLRequest(url: url), policy: HTTPRequestPolicy())
      }
      await UnansweredURLProtocol.waitForRequest()

      task.cancel()

      do {
        _ = try await task.value
        XCTFail("Expected cancellation")
      } catch {
        XCTAssertTrue(error is CancellationError, "\(error)")
      }
    }

    func testCancelledTaskDoesNotSendTheRequest() async {
      let transport = makeTransport()
      let url = startURL
      let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await transport.data(for: URLRequest(url: url),
                                        policy: HTTPRequestPolicy())
      }

      do {
        _ = try await task.value
        XCTFail("Expected cancellation")
      } catch {
        XCTAssertTrue(error is CancellationError, "\(error)")
      }
      XCTAssertTrue(HTTPWireRecorder.requests.isEmpty)
    }

    // MARK: - Redirects

    func testSameOriginRedirectReplaysTheRequestWithCredentials() async throws {
      let requests = try await followRedirect(to: "https://example.com/moved")

      let replayed = try XCTUnwrap(requests.last)
      XCTAssertEqual(replayed.url.absoluteString, "https://example.com/moved")
      XCTAssertEqual(replayed.method, "POST")
      XCTAssertEqual(replayed.body, body)
      XCTAssertEqual(replayed.header("Authorization"), "Bearer token")
      XCTAssertEqual(replayed.header("X-Firebase-AppCheck"), "app-check-token")
      XCTAssertEqual(replayed.header("Content-Type"), "application/json")
    }

    func testCrossOriginRedirectRemovesCredentials() async throws {
      let requests = try await followRedirect(to: "https://other.example/moved")

      let replayed = try XCTUnwrap(requests.last)
      XCTAssertEqual(replayed.url.absoluteString, "https://other.example/moved")
      XCTAssertEqual(replayed.method, "POST")
      XCTAssertEqual(replayed.body, body)
      XCTAssertNil(replayed.header("Authorization"))
      XCTAssertNil(replayed.header("X-Firebase-AppCheck"))
      XCTAssertEqual(replayed.header("Content-Type"), "application/json")
    }

    func testRedirectToTrustedHostKeepsCredentials() async throws {
      let requests = try await followRedirect(
        to: "https://other.example/moved",
        policy: HTTPRequestPolicy(trustedRedirectHosts: ["other.example"])
      )

      XCTAssertEqual(requests.last?.header("Authorization"), "Bearer token")
    }

    func testRedirectNeverDowngradesHTTPS() async throws {
      let requests = try await followRedirect(to: "http://example.com/moved")

      XCTAssertEqual(requests.last?.url.absoluteString, "https://example.com/moved")
    }

    func testChainedRedirectsKeepTheRemovedCredentialsRemoved() async throws {
      let start = startURL.absoluteString
      HTTPWireRecorder.reset { request in
        switch request.url.absoluteString {
        case start:
          return .redirect(status: 307, location: URL(string: "https://other.example/hop")!)
        case "https://other.example/hop":
          return .redirect(status: 307, location: URL(string: "https://example.com/end")!)
        default:
          return .json(status: 200, "{}")
        }
      }

      _ = try await makeTransport().data(for: postRequest(startURL), policy: HTTPRequestPolicy())

      let requests = HTTPWireRecorder.requests
      XCTAssertEqual(requests.map(\.url.absoluteString), [
        "https://example.com/start", "https://other.example/hop", "https://example.com/end",
      ])
      XCTAssertNil(requests[1].header("Authorization"))
      XCTAssertNil(requests[2].header("Authorization"),
                   "Credentials removed for one hop stay removed")
      XCTAssertEqual(requests[2].body, body)
    }

    // MARK: - Helpers

    private func makeTransport() -> URLSessionTransport {
      URLSessionTransport { HTTPWireRecorder.install(in: $0) }
    }

    private func postRequest(_ url: URL) -> URLRequest {
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
      request.setValue("app-check-token", forHTTPHeaderField: "X-Firebase-AppCheck")
      return request
    }

    /// Sends a `POST` that is redirected once to `target`, and returns the recorded requests.
    private func followRedirect(to target: String,
                                policy: HTTPRequestPolicy = HTTPRequestPolicy()) async throws
      -> [HTTPWireRecorder.Request] {
      let startURL = self.startURL
      HTTPWireRecorder.reset { request in
        if request.url == startURL {
          return .redirect(status: 302, location: URL(string: target)!)
        }
        return .json(status: 200, #"{"result":"ok"}"#)
      }

      let (responseBody, response) = try await makeTransport().data(for: postRequest(startURL),
                                                                    policy: policy)

      XCTAssertEqual(response.statusCode, 200)
      XCTAssertEqual(responseBody, Data(#"{"result":"ok"}"#.utf8))
      let requests = HTTPWireRecorder.requests
      XCTAssertEqual(requests.count, 2)
      return requests
    }
  }

  /// Never answers, so that a request stays in flight until it's cancelled.
  private final class UnansweredURLProtocol: URLProtocol, @unchecked Sendable {
    private static let started = AsyncStream<Void>.makeStream()

    /// Waits until a request starts loading.
    static func waitForRequest() async {
      for await _ in started.stream {
        return
      }
    }

    override class func canInit(with request: URLRequest) -> Bool {
      true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
      request
    }

    override func startLoading() {
      Self.started.continuation.yield()
    }

    override func stopLoading() {}
  }

#endif // (COCOAPODS || SWIFT_PACKAGE) && !os(watchOS)
