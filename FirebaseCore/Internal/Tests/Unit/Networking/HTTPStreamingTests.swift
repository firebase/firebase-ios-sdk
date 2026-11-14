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

  /// Tests `URLSessionTransport.bytes(for:policy:)` and `FirebaseHTTPClient.bytes(for:policy:)`.
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
  class HTTPStreamingTests: XCTestCase {
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

    // MARK: - URLSessionTransport

    func testStreamsTheBodyForAnyStatus() async throws {
      HTTPWireRecorder.reset(replies: [
        .http(status: 404, headers: ["Content-Type": "text/plain"],
              body: Data("first line\nsecond line\n".utf8)),
      ])

      let (bytes, response) = try await makeTransport().bytes(for: postRequest(startURL),
                                                              policy: HTTPRequestPolicy())
      var lines: [String] = []
      for try await line in bytes.lines {
        lines.append(line)
      }

      XCTAssertEqual(response.statusCode, 404)
      XCTAssertEqual(response.value(forHTTPHeaderField: "Content-Type"), "text/plain")
      XCTAssertEqual(lines, ["first line", "second line"])
      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(request.method, "POST")
      XCTAssertEqual(request.body, body)
      XCTAssertEqual(request.header("Authorization"), "Bearer token")
    }

    func testTransportErrorIsThrown() async {
      HTTPWireRecorder.reset(replies: [.failure(.cannotFindHost)])

      do {
        _ = try await makeTransport().bytes(for: postRequest(startURL),
                                            policy: HTTPRequestPolicy())
        XCTFail("Expected an error")
      } catch {
        XCTAssertEqual((error as? URLError)?.code, .cannotFindHost)
      }
    }

    func testCancellationThrowsCancellationError() async {
      let transport = URLSessionTransport {
        $0.protocolClasses = [UnansweredURLProtocol.self]
      }
      let url = startURL
      let task = Task {
        _ = try await transport.bytes(for: URLRequest(url: url), policy: HTTPRequestPolicy())
      }
      await UnansweredURLProtocol.waitForRequest()

      task.cancel()

      do {
        try await task.value
        XCTFail("Expected cancellation")
      } catch {
        XCTAssertTrue(error is CancellationError, "\(error)")
      }
    }

    func testCrossOriginRedirectReplaysTheRequestWithoutCredentials() async throws {
      let requests = try await followRedirect(to: "https://other.example/moved")

      let replayed = try XCTUnwrap(requests.last)
      XCTAssertEqual(replayed.url.absoluteString, "https://other.example/moved")
      XCTAssertEqual(replayed.method, "POST")
      XCTAssertEqual(replayed.body, body)
      XCTAssertEqual(replayed.header("Content-Type"), "application/json")
      XCTAssertNil(replayed.header("Authorization"))
      XCTAssertNil(replayed.header("X-Firebase-AppCheck"))
    }

    /// Redirects use the policy of the request, not the default policy.
    func testRedirectToTrustedHostKeepsCredentials() async throws {
      let requests = try await followRedirect(
        to: "https://other.example/moved",
        policy: HTTPRequestPolicy(trustedRedirectHosts: ["other.example"])
      )

      XCTAssertEqual(requests.last?.header("Authorization"), "Bearer token")
      XCTAssertEqual(requests.last?.header("X-Firebase-AppCheck"), "app-check-token")
    }

    func testRedirectNeverDowngradesHTTPS() async throws {
      let requests = try await followRedirect(to: "http://example.com/moved")

      XCTAssertEqual(requests.last?.url.absoluteString, "https://example.com/moved")
      XCTAssertEqual(requests.last?.header("Authorization"), "Bearer token")
    }

    // MARK: - FirebaseHTTPClient

    func testClientSendsTheStandardUserAgentWhenTheRequestHasNone() async throws {
      HTTPWireRecorder.reset(replies: [.http(status: 200)])

      _ = try await makeClient().bytes(for: URLRequest(url: startURL))

      XCTAssertEqual(try HTTPWireRecorder.singleRequest().header("User-Agent"),
                     FirebaseUserAgent.standard)
    }

    func testClientRejectsInsecureRequestsWhenTheAppAllowsArbitraryLoads() async {
      let client = makeClient(appAllowsArbitraryLoads: true)

      do {
        _ = try await client.bytes(for: URLRequest(url: URL(string: "http://example.com/api")!))
        XCTFail("Expected an error")
      } catch {
        XCTAssertEqual((error as? URLError)?.code, .appTransportSecurityRequiresSecureConnection)
      }
      XCTAssertTrue(HTTPWireRecorder.requests.isEmpty)
    }

    func testClientDoesNotHoldABackgroundTask() async throws {
      HTTPWireRecorder.reset(replies: [.http(status: 200)])
      let application = FakeBackgroundTaskApplication()

      _ = try await makeClient(application: application).bytes(for: URLRequest(url: startURL))

      XCTAssertTrue(application.begunIdentifiers.isEmpty)
    }

    func testClientNeedsAURLSessionTransport() async {
      let client = FirebaseHTTPClient(transport: DataOnlyTransport())

      do {
        _ = try await client.bytes(for: URLRequest(url: startURL))
        XCTFail("Expected an error")
      } catch {
        XCTAssertEqual((error as? URLError)?.code, .unsupportedURL)
      }
    }

    // MARK: - Helpers

    private func makeTransport() -> URLSessionTransport {
      URLSessionTransport { HTTPWireRecorder.install(in: $0) }
    }

    private func makeClient(application: (any BackgroundTaskApplication)? = nil,
                            appAllowsArbitraryLoads: Bool = false) -> FirebaseHTTPClient {
      FirebaseHTTPClient(transport: makeTransport(), backgroundTaskApplication: { application },
                         appAllowsArbitraryLoads: appAllowsArbitraryLoads)
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

    /// Streams a `POST` that is redirected once to `target`, and returns the recorded requests.
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

      let (bytes, response) = try await makeTransport().bytes(for: postRequest(startURL),
                                                              policy: policy)
      var responseBody = Data()
      for try await byte in bytes {
        responseBody.append(byte)
      }

      XCTAssertEqual(response.statusCode, 200)
      XCTAssertEqual(responseBody, Data(#"{"result":"ok"}"#.utf8))
      let requests = HTTPWireRecorder.requests
      XCTAssertEqual(requests.count, 2)
      return requests
    }
  }

  /// A transport that can't stream.
  private struct DataOnlyTransport: HTTPTransport {
    func data(for request: URLRequest,
              policy: HTTPRequestPolicy) async throws -> (Data, HTTPURLResponse) {
      XCTFail("Unexpected request to \(request.url?.absoluteString ?? "nil")")
      throw URLError(.unknown)
    }
  }

#endif // (COCOAPODS || SWIFT_PACKAGE) && !os(watchOS)
