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
import Foundation
import XCTest

@testable import FirebaseAuth
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

// Custom `URLProtocol` classes can't intercept `URLSession` traffic on watchOS.
#if !os(watchOS)

  /// Pins the HTTP behavior of `AuthBackendRPCIssuer`: what it sends, and the `(Data?, Error?)`
  /// contract that `AuthBackend` relies on to decode responses and errors.
  ///
  /// The expectations describe the GTMSessionFetcher-based implementation, and they must keep
  /// passing after GTMSessionFetcher is replaced. Only `makeIssuer()`, which routes the issuer's
  /// traffic through `HTTPWireRecorder`, should need to change. An intentional behavior change
  /// must update its expectation and explain why.
  class AuthWireCompatibilityTests: XCTestCase {
    private let apiKey = "FAKE_API_KEY"
    private let appID = "1:123456789:ios:abcdef"
    private let projectConfigURL =
      "https://www.googleapis.com/identitytoolkit/v3/relyingparty/getProjectConfig?key=FAKE_API_KEY"

    override func setUp() {
      super.setUp()
      HTTPWireRecorder.reset()
    }

    override func tearDown() {
      HTTPWireRecorder.reset()
      super.tearDown()
    }

    // MARK: - Request format

    func testRequestWithBodyIsAPOST() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, "{}")])
      let configuration = makeConfiguration()
      configuration.languageCode = "fr"
      let body = Data(#"{"returnSecureToken":true}"#.utf8)

      _ = await call(configuration: configuration, body: body)

      let request = try singleRequest()
      XCTAssertEqual(request.method, "POST")
      XCTAssertEqual(request.url.absoluteString, projectConfigURL)
      XCTAssertEqual(request.body, body)
      let expectedHeaders = [
        "Content-Type": "application/json",
        "User-Agent": expectedUserAgent,
        "X-Client-Version": "iOS/FirebaseSDK/\(FirebaseVersion())/FirebaseCore-iOS",
        "X-Firebase-GMPID": appID,
        "X-Firebase-Locale": "fr",
        "X-Ios-Bundle-Identifier": Bundle.main.bundleIdentifier,
        "Accept-Language": Bundle.main.preferredLocalizations.first,
      ]
      for (name, value) in expectedHeaders {
        XCTAssertEqual(request.header(name), value, "\(name) header")
      }
    }

    func testRequestWithoutBodyIsAGET() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, "{}")])

      _ = await call(body: nil)

      let request = try singleRequest()
      XCTAssertEqual(request.method, "GET")
      XCTAssertEqual(request.url.absoluteString, projectConfigURL)
      XCTAssertTrue(request.body.isEmpty)
      XCTAssertEqual(request.header("User-Agent"), expectedUserAgent)
    }

    // MARK: - Response contract

    func testSuccessReturnsTheBodyWithoutAnError() async throws {
      let body = #"{"projectId":"my-project"}"#
      HTTPWireRecorder.reset(replies: [.json(status: 200, body)])

      let (data, error) = await call()

      XCTAssertEqual(data, Data(body.utf8))
      XCTAssertNil(error)
    }

    /// A successful response with an empty body produces empty data, not `nil`.
    func testSuccessWithAnEmptyBodyReturnsEmptyData() async throws {
      HTTPWireRecorder.reset(replies: [.http(status: 200)])

      let (data, error) = await call()

      XCTAssertEqual(data, Data())
      XCTAssertNil(error)
    }

    /// An HTTP error returns both the response body, which `AuthBackend` decodes for the server's
    /// error message, and an `NSError` in the `com.google.HTTPStatus` domain.
    func testHTTPErrorReturnsTheBodyAndAStatusError() async throws {
      let body = #"{"error":{"code":400,"message":"INVALID_EMAIL"}}"#
      HTTPWireRecorder.reset(replies: [.json(status: 400, body)])

      let (data, error) = await call()

      XCTAssertEqual(data, Data(body.utf8))
      let statusError = try XCTUnwrap(error as NSError?)
      XCTAssertEqual(statusError.domain, "com.google.HTTPStatus")
      XCTAssertEqual(statusError.code, 400)
      XCTAssertEqual(statusError.userInfo["data"] as? Data, Data(body.utf8))
      XCTAssertEqual(
        statusError.userInfo["data_content_type"] as? String, "application/json; charset=UTF-8"
      )
    }

    /// An HTTP error with an empty body returns no data, which `AuthBackend` reports as a network
    /// error.
    func testHTTPErrorWithAnEmptyBodyReturnsNoData() async throws {
      HTTPWireRecorder.reset(replies: [.http(status: 503)])

      let (data, error) = await call()

      XCTAssertNil(data)
      let statusError = try XCTUnwrap(error as NSError?)
      XCTAssertEqual(statusError.domain, "com.google.HTTPStatus")
      XCTAssertEqual(statusError.code, 503)
      XCTAssertNil(statusError.userInfo["data"])
      XCTAssertNil(statusError.userInfo["data_content_type"])
      XCTAssertEqual(HTTPWireRecorder.requests.count, 1, "Auth requests are never retried")
    }

    func testTransportErrorReturnsTheURLErrorWithoutData() async throws {
      HTTPWireRecorder.reset(replies: [.failure(.notConnectedToInternet)])

      let (data, error) = await call()

      XCTAssertNil(data)
      let transportError = try XCTUnwrap(error as NSError?)
      XCTAssertEqual(transportError.domain, NSURLErrorDomain)
      XCTAssertEqual(transportError.code, NSURLErrorNotConnectedToInternet)
      XCTAssertEqual(HTTPWireRecorder.requests.count, 1, "Auth requests are never retried")
    }

    // MARK: - Emulator and redirects

    func testEmulatorRequestUsesHTTP() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, "{}")])
      let configuration = makeConfiguration()
      configuration.emulatorHostAndPort = "localhost:9099"

      let (_, error) = await call(configuration: configuration)

      XCTAssertNil(error)
      XCTAssertEqual(
        try singleRequest().url.absoluteString,
        "http://localhost:9099/www.googleapis.com/identitytoolkit/v3/relyingparty/" +
          "getProjectConfig?key=FAKE_API_KEY"
      )
    }

    /// A redirect to the same host replays the original method, body, and headers, and keeps the
    /// original scheme instead of downgrading to HTTP.
    func testSameHostRedirectReplaysTheRequestWithoutDowngradingTheScheme() async throws {
      HTTPWireRecorder.reset { request in
        if request.url.path.hasSuffix("/getProjectConfig") {
          return .redirect(
            status: 302,
            location: URL(string: "http://www.googleapis.com/identitytoolkit/v3/moved")!
          )
        }
        return .json(status: 200, "{}")
      }
      let body = Data(#"{"returnSecureToken":true}"#.utf8)

      let (_, error) = await call(body: body)

      XCTAssertNil(error)
      let requests = HTTPWireRecorder.requests
      XCTAssertEqual(requests.count, 2)
      let replayed = try XCTUnwrap(requests.last)
      XCTAssertEqual(
        replayed.url.absoluteString, "https://www.googleapis.com/identitytoolkit/v3/moved"
      )
      XCTAssertEqual(replayed.method, "POST")
      XCTAssertEqual(replayed.body, body)
      XCTAssertEqual(replayed.header("X-Firebase-GMPID"), appID)
      XCTAssertEqual(replayed.header("User-Agent"), expectedUserAgent)
    }

    // MARK: - Helpers

    /// Auth's prefix followed by GTMSessionFetcher's standard User-Agent.
    private var expectedUserAgent: String {
      "FirebaseAuth.iOS/\(FirebaseVersion()) \(GTMFetcherStandardUserAgentString(nil))"
    }

    private func makeConfiguration() -> AuthRequestConfiguration {
      AuthRequestConfiguration(apiKey: apiKey, appID: appID)
    }

    private func call(configuration: AuthRequestConfiguration? = nil,
                      body: Data? = nil) async -> (Data?, Error?) {
      let request = GetProjectConfigRequest(
        requestConfiguration: configuration ?? makeConfiguration()
      )
      return await makeIssuer().asyncCallToURL(
        with: request, body: body, contentType: "application/json"
      )
    }

    private func singleRequest(file: StaticString = #filePath,
                               line: UInt = #line) throws -> HTTPWireRecorder.Request {
      let requests = HTTPWireRecorder.requests
      XCTAssertEqual(requests.count, 1, "Expected exactly one request", file: file, line: line)
      return try XCTUnwrap(requests.first, file: file, line: line)
    }

    /// Returns an issuer whose HTTP traffic goes through `HTTPWireRecorder`.
    private func makeIssuer() -> AuthBackendRPCIssuer {
      // GTMSessionFetcher-specific wiring. After the migration, install the recorder in the
      // replacement client's session configuration.
      let issuer = AuthBackendRPCIssuer()
      issuer.fetcherService.configurationBlock = { _, configuration in
        HTTPWireRecorder.install(in: configuration)
      }
      return issuer
    }
  }

#endif // !os(watchOS)
