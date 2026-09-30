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

package import Foundation
package import GeminiAPIClient
import Synchronization

#if canImport(FoundationNetworking)
  package import FoundationNetworking
#endif

// MARK: - Recording URL Protocol

/// A `URLProtocol` that records outbound requests and replays scripted responses.
///
/// Every request the OrcaRouter code makes is recorded with its URL, headers, and body, so tests can
/// assert which origin a request went to and what it carried.
package final class OrcaRouterRecordingURLProtocol: URLProtocol {
  /// A scripted response.
  package struct Stub: Sendable {
    /// The HTTP status to return.
    package var status: Int
    /// The response headers.
    package var headers: [String: String]
    /// The response body.
    package var body: Data
    /// An error to fail the request with instead of responding.
    package var failure: (any Error)?

    /// A JSON response.
    package static func json(_ object: Any, status: Int = 200) -> Stub {
      Stub(
        status: status,
        headers: ["Content-Type": "application/json"],
        body: (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
      )
    }

    /// A server-sent-events response.
    package static func sse(_ events: [String], status: Int = 200) -> Stub {
      let payload = events.map { "data: \($0)\n\n" }.joined() + "data: [DONE]\n\n"
      return Stub(
        status: status,
        headers: ["Content-Type": "text/event-stream"],
        body: Data(payload.utf8)
      )
    }

    /// A raw error response.
    package static func raw(_ body: String, status: Int) -> Stub {
      Stub(
        status: status,
        headers: ["Content-Type": "application/json"],
        body: Data(body.utf8)
      )
    }

    /// A transport failure.
    package static func failing(_ error: any Error) -> Stub {
      Stub(status: 0, headers: [:], body: Data(), failure: error)
    }
  }

  /// A recorded outbound request.
  package struct Recorded: Sendable {
    /// The request URL.
    package let url: URL
    /// The HTTP method.
    package let method: String
    /// The headers, lower-cased.
    package let headers: [String: String]
    /// The body.
    package let body: Data

    /// The body decoded as JSON.
    package var json: [String: Any]? {
      (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
    }
  }

  private struct State: Sendable {
    var stubs: [String: Stub] = [:]
    var requests: [Recorded] = []
  }

  private static let state = Mutex(State())

  /// Registers a stub for URLs whose string starts with a prefix.
  ///
  /// - Parameters:
  ///   - prefix: The URL prefix to match.
  ///   - stub: The response to replay.
  package static func stub(matching prefix: String, _ stub: Stub) {
    state.withLock { $0.stubs[prefix] = stub }
  }

  /// Registers a stub for an exact URL string.
  ///
  /// - Parameters:
  ///   - urlString: The URL to match.
  ///   - stub: The response to replay.
  package static func stub(urlString: String, _ stub: Stub) {
    state.withLock { $0.stubs[urlString] = stub }
  }

  /// Clears all stubs and recorded requests.
  package static func reset() {
    state.withLock { $0 = State() }
  }

  /// Every request recorded so far, in order.
  package static var recordedRequests: [Recorded] {
    state.withLock { $0.requests }
  }

  /// The most recent recorded request whose URL path ends with a suffix.
  ///
  /// - Parameter suffix: The path suffix to match.
  package static func lastRequest(withPathSuffix suffix: String) -> Recorded? {
    recordedRequests.last { $0.url.path.hasSuffix(suffix) }
  }

  /// The most recent recorded request to one host with a path suffix.
  ///
  /// Suites run concurrently and share this registry, so each suite works against its own host and
  /// scopes its assertions with this method rather than with a global reset.
  ///
  /// - Parameters:
  ///   - host: The host the request must have been sent to.
  ///   - suffix: The path suffix to match.
  package static func lastRequest(host: String, pathSuffix suffix: String) -> Recorded? {
    recordedRequests.last { $0.url.host == host && $0.url.path.hasSuffix(suffix) }
  }

  /// Every recorded request sent to one host.
  ///
  /// - Parameter host: The host to filter on.
  package static func requests(toHost host: String) -> [Recorded] {
    recordedRequests.filter { $0.url.host == host }
  }

  /// A session configuration for real loopback traffic, with proxying disabled.
  ///
  /// The OAuth flow is exercised against a genuine loopback HTTP server rather than a stubbed
  /// protocol, so an ambient proxy configuration that intercepted `127.0.0.1` would make the test
  /// assert against the wrong thing.
  package static var loopbackSessionConfiguration: URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.connectionProxyDictionary = [
      "HTTPEnable": 0,
      "HTTPSEnable": 0,
      "ProxyAutoConfigEnable": 0,
      "ProxyAutoDiscoveryEnable": 0,
    ]
    configuration.timeoutIntervalForRequest = 15
    return configuration
  }

  /// A session configuration wired to this protocol.
  package static var sessionConfiguration: URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [OrcaRouterRecordingURLProtocol.self]
    return configuration
  }

  override package class func canInit(with request: URLRequest) -> Bool { true }

  override package class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override package func startLoading() {
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    let recorded = Recorded(
      url: url,
      method: request.httpMethod ?? "GET",
      headers: request.allHTTPHeaderFields?.reduce(into: [String: String]()) { result, entry in
        result[entry.key.lowercased()] = entry.value
      } ?? [:],
      body: request.httpBodyData ?? Data()
    )

    let stub: Stub? = OrcaRouterRecordingURLProtocol.state.withLock { state in
      state.requests.append(recorded)
      if let exact = state.stubs[url.absoluteString] { return exact }
      return state.stubs.first { url.absoluteString.hasPrefix($0.key) }?.value
    }

    guard let stub else {
      client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
      return
    }

    if let failure = stub.failure {
      client?.urlProtocol(self, didFailWithError: failure)
      return
    }

    let response = HTTPURLResponse(
      url: url,
      statusCode: stub.status,
      httpVersion: "HTTP/1.1",
      headerFields: stub.headers
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    if !stub.body.isEmpty {
      client?.urlProtocol(self, didLoad: stub.body)
    }
    client?.urlProtocolDidFinishLoading(self)
  }

  override package func stopLoading() {}
}

// MARK: - Test Credential Sources

/// A credential source that returns a fixed credential.
package struct OrcaRouterStaticCredentialSource: OrcaRouterCredentialSource {
  /// The credential to return.
  package let credential: OrcaRouterCredential

  /// Creates a source around a credential.
  package init(credential: OrcaRouterCredential) {
    self.credential = credential
  }

  /// Creates a source around a raw key.
  ///
  /// - Parameters:
  ///   - apiKey: The key to return.
  ///   - acquisition: How to label it.
  ///   - generation: The generation to stamp.
  package init(
    apiKey: String,
    acquisition: OrcaRouterCredential.Acquisition = .apiKey,
    generation: UInt64 = 1
  ) {
    self.credential = OrcaRouterCredential(
      apiKey: apiKey,
      acquisition: acquisition,
      generation: generation
    )
  }

  package func acquire() async throws -> OrcaRouterCredential { credential }
}

/// A credential source that fails.
package struct OrcaRouterFailingCredentialSource: OrcaRouterCredentialSource {
  /// The error to throw.
  package let error: any Error

  /// Creates a failing source.
  package init(error: any Error = OrcaRouterCredentialError.emptyAPIKey) {
    self.error = error
  }

  package func acquire() async throws -> OrcaRouterCredential { throw error }
}

// MARK: - Test Constants

/// Canonical test origins and keys.
package enum OrcaRouterTestConstants {
  /// A fake authentication origin. Not a real key, not a real host.
  package static let authBaseURL = "https://auth.example.test"

  /// A fake inference origin, used by the catalog suite.
  package static let apiBaseURL = "https://catalog.example.test/v1"

  /// A separate fake inference origin, used by the credential suite.
  package static let credentialAPIBaseURL = "https://cred.example.test/v1"

  /// A separate fake inference origin, used by the client suite.
  package static let chatAPIBaseURL = "https://chat.example.test/v1"

  /// A host no OrcaRouter code path is ever expected to contact, used to prove that a code path made
  /// no network call without observing other suites' concurrent traffic.
  package static let probeHost = "probe.example.test"

  /// A fake API key. Never a real credential.
  package static let fakeAPIKey = "sk-orca-test-not-a-real-key-0000"

  /// A fake authorization code.
  package static let fakeAuthorizationCode = "orca-test-code-0000"

  /// The hosts a request is expected to reach. Each suite keeps its own so concurrent suites cannot
  /// observe each other's requests.
  package static let authHost = "auth.example.test"
  package static let apiHost = "catalog.example.test"
  package static let credentialAPIHost = "cred.example.test"
  package static let chatAPIHost = "chat.example.test"
}

// MARK: - Credential Capture

/// Captures everything a failing operation printed, to prove a secret never appears in output.
package final class OrcaRouterOutputCapture: @unchecked Sendable {
  private let lock = NSLock()
  private var captured: [String] = []

  /// Creates a capture sink.
  package init() {}

  /// Records a value.
  ///
  /// - Parameter value: The text to record.
  package func record(_ value: String) {
    lock.lock()
    defer { lock.unlock() }
    captured.append(value)
  }

  /// Everything recorded so far, joined.
  package var text: String {
    lock.lock()
    defer { lock.unlock() }
    return captured.joined(separator: "\n")
  }

  /// Whether any recorded value contains a substring.
  ///
  /// - Parameter needle: The substring to look for.
  package func contains(_ needle: String) -> Bool {
    text.contains(needle)
  }
}
