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
import XCTest

class FirebaseHTTPClientTests: XCTestCase {
  private let url = URL(string: "https://example.com/api")!

  // MARK: - Requests

  func testReturnsTheTransportResult() async throws {
    let transport = RecordingTransport(status: 404, body: Data("missing".utf8))
    let client = makeClient(transport: transport)

    let (body, response) = try await client.data(for: URLRequest(url: url))

    XCTAssertEqual(body, Data("missing".utf8))
    XCTAssertEqual(response.statusCode, 404)
  }

  func testSendsTheStandardUserAgentWhenTheRequestHasNone() async throws {
    let transport = RecordingTransport()

    _ = try await makeClient(transport: transport).data(for: URLRequest(url: url))

    XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "User-Agent"),
                   FirebaseUserAgent.standard)
  }

  func testKeepsTheRequestUserAgent() async throws {
    let transport = RecordingTransport()
    var request = URLRequest(url: url)
    request.setValue("FirebaseAuth.iOS/13.3.0 app/1.0", forHTTPHeaderField: "User-Agent")

    _ = try await makeClient(transport: transport).data(for: request)

    XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "User-Agent"),
                   "FirebaseAuth.iOS/13.3.0 app/1.0")
  }

  func testPassesThePolicyToTheTransport() async throws {
    let transport = RecordingTransport()
    let policy = HTTPRequestPolicy(trustedRedirectHosts: ["example.com"])

    _ = try await makeClient(transport: transport).data(for: URLRequest(url: url), policy: policy)

    XCTAssertEqual(transport.policies.first?.trustedRedirectHosts, ["example.com"])
  }

  func testTransportErrorsAreThrownUnchanged() async {
    let transport = RecordingTransport(error: URLError(.notConnectedToInternet))

    do {
      _ = try await makeClient(transport: transport).data(for: URLRequest(url: url))
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
    }
  }

  // MARK: - Insecure requests

  func testInsecureRequestsAreRejectedWhenTheAppAllowsArbitraryLoads() async {
    let transport = RecordingTransport()
    let client = makeClient(transport: transport, appAllowsArbitraryLoads: true)

    do {
      _ = try await client.data(for: URLRequest(url: URL(string: "http://example.com/api")!))
      XCTFail("Expected an error")
    } catch {
      let urlError = error as? URLError
      XCTAssertEqual(urlError?.code, .appTransportSecurityRequiresSecureConnection)
      XCTAssertEqual(urlError?.failingURL?.absoluteString, "http://example.com/api")
    }
    XCTAssertTrue(transport.requests.isEmpty)
  }

  func testSchemeRules() {
    let strict = HTTPRequestPolicy()
    let insecure = HTTPRequestPolicy(allowsInsecureHTTP: true)
    let loopback = HTTPRequestPolicy(allowsLoopbackHTTP: true)
    let rows: [(url: String, policy: HTTPRequestPolicy, allowsArbitraryLoads: Bool,
                isAllowed: Bool)] = [
      ("https://example.com", strict, true, true),
      ("HTTPS://example.com", strict, true, true),
      ("http://example.com", strict, true, false),
      ("http://example.com", insecure, true, true),
      ("ftp://example.com", insecure, true, false),
      ("http://localhost:9199", strict, true, false),
      ("http://localhost:9199", loopback, true, true),
      ("http://LOCALHOST", loopback, true, true),
      ("http://127.0.0.1:9199", loopback, true, true),
      ("http://[::1]:9199", loopback, true, true),
      ("http://10.0.2.2:9199", loopback, true, false),
      // App Transport Security enforces https when the app doesn't allow arbitrary loads.
      ("http://example.com", strict, false, true),
    ]
    for row in rows {
      XCTAssertEqual(
        FirebaseHTTPClient.allowsScheme(of: URL(string: row.url)!, policy: row.policy,
                                        appAllowsArbitraryLoads: row.allowsArbitraryLoads),
        row.isAllowed,
        "\(row.url), arbitrary loads: \(row.allowsArbitraryLoads)"
      )
    }
  }

  // MARK: - Background tasks

  func testHoldsABackgroundTaskWhileTheRequestIsInFlight() async throws {
    let application = FakeBackgroundTaskApplication()
    let transport = RecordingTransport { _ in
      XCTAssertEqual(application.begunIdentifiers, [1])
      XCTAssertTrue(
        application.endedIdentifiers.isEmpty,
        "The task must be held during the request"
      )
    }

    _ = try await makeClient(transport: transport, application: application)
      .data(for: URLRequest(url: url))

    XCTAssertEqual(application.endedIdentifiers, [1])
  }

  func testEndsTheBackgroundTaskWhenTheRequestFails() async {
    let application = FakeBackgroundTaskApplication()
    let transport = RecordingTransport(error: URLError(.timedOut))

    _ = try? await makeClient(transport: transport, application: application)
      .data(for: URLRequest(url: url))

    XCTAssertEqual(application.endedIdentifiers, [1])
  }

  func testDoesNotHoldABackgroundTaskWhenThePolicyDisablesIt() async throws {
    let application = FakeBackgroundTaskApplication()

    _ = try await makeClient(transport: RecordingTransport(), application: application)
      .data(for: URLRequest(url: url), policy: HTTPRequestPolicy(holdsBackgroundTask: false))

    XCTAssertTrue(application.begunIdentifiers.isEmpty)
  }

  func testExpiredBackgroundTaskIsEndedOnce() async throws {
    let application = FakeBackgroundTaskApplication()
    let transport = RecordingTransport { _ in
      application.expireTasks()
      XCTAssertEqual(application.endedIdentifiers, [1], "Expiration ends the task")
    }

    _ = try await makeClient(transport: transport, application: application)
      .data(for: URLRequest(url: url))

    XCTAssertEqual(application.endedIdentifiers, [1], "The task is only ended once")
  }

  func testInvalidBackgroundTaskIsNotEnded() async throws {
    let application = FakeBackgroundTaskApplication(grantsTasks: false)

    _ = try await makeClient(transport: RecordingTransport(), application: application)
      .data(for: URLRequest(url: url))

    XCTAssertEqual(application.begunIdentifiers.count, 1)
    XCTAssertTrue(application.endedIdentifiers.isEmpty)
  }

  func testOnlyIOSTVOSAndMacCatalystHaveBackgroundTasks() {
    #if !os(iOS) && !os(tvOS)
      XCTAssertNil(SystemBackgroundTaskApplication.current())
    #endif
  }

  // MARK: - Helpers

  private func makeClient(transport: any HTTPTransport,
                          application: (any BackgroundTaskApplication)? = nil,
                          appAllowsArbitraryLoads: Bool = false) -> FirebaseHTTPClient {
    FirebaseHTTPClient(transport: transport, backgroundTaskApplication: { application },
                       appAllowsArbitraryLoads: appAllowsArbitraryLoads)
  }
}

/// Records each request and returns a canned result.
private final class RecordingTransport: HTTPTransport, @unchecked Sendable {
  private let lock = NSLock()
  private var recordedRequests: [URLRequest] = []
  private var recordedPolicies: [HTTPRequestPolicy] = []
  private let result: Result<(Data, Int), Error>
  private let onRequest: @Sendable (URLRequest) -> Void

  init(status: Int = 200, body: Data = Data(),
       onRequest: @escaping @Sendable (URLRequest) -> Void = { _ in }) {
    result = .success((body, status))
    self.onRequest = onRequest
  }

  init(error: Error) {
    result = .failure(error)
    onRequest = { _ in }
  }

  var requests: [URLRequest] {
    lock.withLock { recordedRequests }
  }

  var policies: [HTTPRequestPolicy] {
    lock.withLock { recordedPolicies }
  }

  func data(for request: URLRequest,
            policy: HTTPRequestPolicy) async throws -> (Data, HTTPURLResponse) {
    lock.withLock {
      recordedRequests.append(request)
      recordedPolicies.append(policy)
    }
    onRequest(request)
    let (body, status) = try result.get()
    let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                   headerFields: nil)!
    return (body, response)
  }
}

/// Grants background tasks with increasing identifiers and records which ones end.
private final class FakeBackgroundTaskApplication: BackgroundTaskApplication,
  @unchecked Sendable {
  private let lock = NSLock()
  private let grantsTasks: Bool
  private var nextIdentifier = 1
  private var begun: [Int] = []
  private var ended: [Int] = []
  private var expirationHandlers: [@Sendable () -> Void] = []

  init(grantsTasks: Bool = true) {
    self.grantsTasks = grantsTasks
  }

  var begunIdentifiers: [Int] {
    lock.withLock { begun }
  }

  var endedIdentifiers: [Int] {
    lock.withLock { ended }
  }

  func beginBackgroundTask(withName name: String,
                           expirationHandler: @escaping @Sendable () -> Void) -> Int {
    lock.withLock {
      let identifier = grantsTasks ? nextIdentifier : invalidBackgroundTaskIdentifier
      nextIdentifier += 1
      begun.append(identifier)
      expirationHandlers.append(expirationHandler)
      return identifier
    }
  }

  func endBackgroundTask(_ identifier: Int) {
    lock.withLock { ended.append(identifier) }
  }

  /// Calls the expiration handlers, as the system does when background time runs out.
  func expireTasks() {
    let handlers = lock.withLock { expirationHandlers }
    handlers.forEach { $0() }
  }
}
