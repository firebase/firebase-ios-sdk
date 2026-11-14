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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
@testable import FirebaseFunctions
import FirebaseMessagingInterop
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

  /// Pins the HTTP behavior of callable functions: what a call sends, and how responses and
  /// failures surface to the caller.
  ///
  /// The expectations describe the GTMSessionFetcher-based implementation, and they must keep
  /// passing after GTMSessionFetcher is replaced. Only `makeFunctions`, which routes the SDK's
  /// traffic through `HTTPWireRecorder`, should need to change. An intentional behavior change
  /// must update its expectation and explain why.
  class FunctionsWireCompatibilityTests: XCTestCase {
    private let functionURL = "https://us-central1-my-project.cloudfunctions.net/echo"

    override func setUp() {
      super.setUp()
      HTTPWireRecorder.reset()
    }

    override func tearDown() {
      HTTPWireRecorder.reset()
      super.tearDown()
    }

    // MARK: - Request format

    func testCallRequest() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, #"{"data":"ok"}"#)])
      let functions = makeFunctions(
        auth: FIRAuthInteropFake(token: "auth-token", userID: "user-id", error: nil),
        messaging: FIRMessagingInteropFake(),
        appCheck: FIRAppCheckFake()
      )

      _ = try await functions.httpsCallable("echo").call(["key": "value"])

      let request = try HTTPWireRecorder.singleRequest()
      XCTAssertEqual(request.method, "POST")
      XCTAssertEqual(request.url.absoluteString, functionURL)
      XCTAssertEqual(request.header("Content-Type"), "application/json")
      XCTAssertEqual(request.header("Authorization"), "Bearer auth-token")
      XCTAssertEqual(request.header("Firebase-Instance-ID-Token"), "fakeFCMToken")
      XCTAssertEqual(request.header("X-Firebase-AppCheck"), "fake_valid_token")
      XCTAssertEqual(request.header("User-Agent"), GTMFetcherStandardUserAgentString(nil))
      XCTAssertEqual(request.timeoutInterval, 70)
      let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? NSDictionary)
      XCTAssertEqual(body, ["data": ["key": "value"]])
    }

    func testCallWithoutTokensOrDataSendsNullData() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, #"{"data":null}"#)])

      _ = try await makeFunctions().httpsCallable("echo").call()

      let request = try HTTPWireRecorder.singleRequest()
      let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? NSDictionary)
      XCTAssertEqual(body, ["data": NSNull()])
      for header in ["Authorization", "Firebase-Instance-ID-Token", "X-Firebase-AppCheck"] {
        XCTAssertNil(request.header(header), "\(header) must not be sent")
      }
    }

    func testTimeoutIntervalIsSentAsRequestTimeout() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, #"{"data":"ok"}"#)])
      let callable = makeFunctions().httpsCallable("echo")
      callable.timeoutInterval = 12

      _ = try await callable.call()

      XCTAssertEqual(try HTTPWireRecorder.singleRequest().timeoutInterval, 12)
    }

    // MARK: - Responses

    func testSuccessfulResponseIsDecoded() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, #"{"data":{"answer":42}}"#)])

      let result = try await makeFunctions().httpsCallable("echo").call()

      XCTAssertEqual(result.data as? NSDictionary, ["answer": 42])
    }

    func testErrorBodyIsMappedToFunctionsError() async throws {
      HTTPWireRecorder.reset(replies: [.json(
        status: 400,
        #"{"error":{"status":"INVALID_ARGUMENT","message":"Bad input","details":{"field":"x"}}}"#
      )])

      do {
        _ = try await makeFunctions().httpsCallable("echo").call()
        XCTFail("Expected an error")
      } catch {
        let functionsError = error as NSError
        XCTAssertEqual(functionsError.domain, FunctionsErrorDomain)
        XCTAssertEqual(functionsError.code, FunctionsErrorCode.invalidArgument.rawValue)
        XCTAssertEqual(functionsError.localizedDescription, "Bad input")
        XCTAssertEqual(
          functionsError.userInfo[FunctionsErrorDetailsKey] as? NSDictionary, ["field": "x"]
        )
      }
    }

    func testHTTPStatusIsMappedWhenTheBodyHasNoError() async throws {
      let cases: [(status: Int, code: FunctionsErrorCode)] = [
        (400, .invalidArgument), (401, .unauthenticated), (403, .permissionDenied),
        (404, .notFound), (409, .alreadyExists), (429, .resourceExhausted), (500, .internal),
        (501, .unimplemented), (503, .unavailable), (504, .deadlineExceeded),
      ]
      let functions = makeFunctions()
      for (status, code) in cases {
        // Error pages that aren't JSON are mapped from the status code alone.
        HTTPWireRecorder.reset(replies: [
          .http(status: status, headers: ["Content-Type": "text/html"], body: Data("<html/>".utf8)),
        ])
        do {
          _ = try await functions.httpsCallable("echo").call()
          XCTFail("Expected an error for HTTP \(status)")
        } catch {
          let functionsError = error as NSError
          XCTAssertEqual(functionsError.domain, FunctionsErrorDomain, "HTTP \(status)")
          XCTAssertEqual(functionsError.code, code.rawValue, "HTTP \(status)")
        }
        XCTAssertEqual(HTTPWireRecorder.requests.count, 1, "HTTP \(status) must not be retried")
      }
    }

    func testTimedOutRequestThrowsDeadlineExceeded() async throws {
      HTTPWireRecorder.reset(replies: [.failure(.timedOut)])

      do {
        _ = try await makeFunctions().httpsCallable("echo").call()
        XCTFail("Expected an error")
      } catch {
        let functionsError = error as NSError
        XCTAssertEqual(functionsError.domain, FunctionsErrorDomain)
        XCTAssertEqual(functionsError.code, FunctionsErrorCode.deadlineExceeded.rawValue)
      }
      XCTAssertEqual(HTTPWireRecorder.requests.count, 1)
    }

    func testTransportErrorIsThrownUnchanged() async throws {
      HTTPWireRecorder.reset(replies: [.failure(.notConnectedToInternet)])

      do {
        _ = try await makeFunctions().httpsCallable("echo").call()
        XCTFail("Expected an error")
      } catch {
        let transportError = error as NSError
        XCTAssertEqual(transportError.domain, NSURLErrorDomain)
        XCTAssertEqual(transportError.code, NSURLErrorNotConnectedToInternet)
      }
      XCTAssertEqual(HTTPWireRecorder.requests.count, 1)
    }

    // MARK: - Emulator and redirects

    func testEmulatorRequestUsesHTTP() async throws {
      HTTPWireRecorder.reset(replies: [.json(status: 200, #"{"data":"ok"}"#)])
      let functions = makeFunctions()
      functions.useEmulator(withHost: "localhost", port: 5001)

      _ = try await functions.httpsCallable("echo").call()

      XCTAssertEqual(
        try HTTPWireRecorder.singleRequest().url.absoluteString,
        "http://localhost:5001/my-project/us-central1/echo"
      )
    }

    /// A redirect to the same host replays the original method, body, and headers, and keeps the
    /// original scheme instead of downgrading to HTTP.
    func testSameHostRedirectReplaysTheRequestWithoutDowngradingTheScheme() async throws {
      HTTPWireRecorder.reset { request in
        if request.url.path == "/echo" {
          return .redirect(status: 302, location: URL(string: "http://mydomain.com/moved")!)
        }
        return .json(status: 200, #"{"data":"ok"}"#)
      }
      let functions = makeFunctions(
        customDomain: "https://mydomain.com",
        auth: FIRAuthInteropFake(token: "auth-token", userID: "user-id", error: nil)
      )

      _ = try await functions.httpsCallable("echo").call(["key": "value"])

      let requests = HTTPWireRecorder.requests
      XCTAssertEqual(requests.count, 2)
      let original = try XCTUnwrap(requests.first)
      let replayed = try XCTUnwrap(requests.last)
      XCTAssertEqual(original.url.absoluteString, "https://mydomain.com/echo")
      XCTAssertEqual(replayed.url.absoluteString, "https://mydomain.com/moved")
      XCTAssertEqual(replayed.method, "POST")
      XCTAssertEqual(replayed.body, original.body)
      XCTAssertEqual(replayed.header("Content-Type"), "application/json")
      XCTAssertEqual(replayed.header("Authorization"), "Bearer auth-token")
    }

    // MARK: - Helpers

    /// Returns a `Functions` instance whose HTTP traffic goes through `HTTPWireRecorder`.
    private func makeFunctions(customDomain: String? = nil,
                               auth: AuthInterop? = nil,
                               messaging: MessagingInterop? = nil,
                               appCheck: AppCheckInterop? = nil) -> Functions {
      // GTMSessionFetcher-specific wiring. After the migration, install the recorder in the
      // replacement client's session configuration.
      let fetcherService = GTMSessionFetcherService()
      fetcherService.configurationBlock = { _, configuration in
        HTTPWireRecorder.install(in: configuration)
      }
      return Functions(
        projectID: "my-project",
        region: "us-central1",
        customDomain: customDomain,
        auth: auth,
        messaging: messaging,
        appCheck: appCheck,
        fetcherService: fetcherService
      )
    }
  }

#endif // (COCOAPODS || SWIFT_PACKAGE) && !os(watchOS)
