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

class RedirectPolicyTests: XCTestCase {
  private let body = Data(#"{"data":{"key":"value"}}"#.utf8)

  /// Headers that carry credentials, including ones that only match a credential suffix.
  private let credentialHeaders = [
    "Authorization": "Bearer token",
    "Proxy-Authorization": "Basic abc",
    "Cookie": "session=1",
    "Cookie2": "legacy=1",
    "X-Firebase-AppCheck": "app-check-token",
    "Firebase-Instance-ID-Token": "fcm-token",
    "Sec-Token-Binding": "binding",
    "Sec-Provided-Token-Binding-ID": "provided",
    "Sec-Referred-Token-Binding-ID": "referred",
    "X-Goog-Api-Key": "api-key",
    "X-Goog-AuthUser": "0",
    "X-Custom-Token": "custom",
  ]

  /// Headers that don't carry credentials.
  private let otherHeaders = [
    "Content-Type": "application/json",
    "User-Agent": "app/1.0 iPhone/18.3 hw/sim",
    "X-Client-Version": "iOS/FirebaseSDK/13.3.0/FirebaseCore-iOS",
    "X-Firebase-GMPID": "1:123:ios:abc",
    "X-Ios-Bundle-Identifier": "com.example.app",
  ]

  // MARK: - Request replay

  func testRedirectReplaysMethodBodyAndHeaders() throws {
    let request = postRequest("https://example.com/start")

    let redirect = try XCTUnwrap(follow(request, to: "https://example.com/moved"))

    XCTAssertEqual(redirect.url?.absoluteString, "https://example.com/moved")
    XCTAssertEqual(redirect.httpMethod, "POST")
    XCTAssertEqual(redirect.httpBody, body)
    XCTAssertEqual(redirect.timeoutInterval, request.timeoutInterval)
    XCTAssertEqual(redirect.allHTTPHeaderFields, request.allHTTPHeaderFields)
  }

  func testHeadersInTheProposedRequestReplaceHeaders() throws {
    var proposed = URLRequest(url: URL(string: "https://example.com/moved")!)
    proposed.setValue("text/plain", forHTTPHeaderField: "Content-Type")
    proposed.setValue("added", forHTTPHeaderField: "X-Added")

    let redirect = try XCTUnwrap(RedirectPolicy.request(
      redirecting: postRequest("https://example.com/start"), to: proposed,
      policy: HTTPRequestPolicy()
    ))

    XCTAssertEqual(redirect.value(forHTTPHeaderField: "Content-Type"), "text/plain")
    XCTAssertEqual(redirect.value(forHTTPHeaderField: "X-Added"), "added")
    XCTAssertEqual(redirect.value(forHTTPHeaderField: "Authorization"), "Bearer token")
  }

  // MARK: - Schemes

  func testHTTPSIsNeverDowngradedToHTTP() throws {
    let redirect = try XCTUnwrap(follow(postRequest("https://example.com/start"),
                                        to: "http://example.com/moved?x=1"))

    XCTAssertEqual(redirect.url?.absoluteString, "https://example.com/moved?x=1")
    // The target keeps the original origin, so it keeps the credentials.
    XCTAssertEqual(redirect.value(forHTTPHeaderField: "Authorization"), "Bearer token")
  }

  func testHTTPCanBeUpgradedToHTTPS() throws {
    let redirect = try XCTUnwrap(follow(postRequest("http://localhost:9099/start"),
                                        to: "https://localhost:9099/moved"))

    XCTAssertEqual(redirect.url?.absoluteString, "https://localhost:9099/moved")
  }

  // MARK: - Credentials

  func testSameOriginRedirectKeepsCredentials() throws {
    let redirect = try XCTUnwrap(follow(postRequest("https://Example.com/start"),
                                        to: "https://example.COM:443/moved"))

    assertHeaders(of: redirect, include: credentialHeaders.merging(otherHeaders) { $1 })
  }

  func testCrossOriginRedirectRemovesCredentialHeaders() throws {
    let redirect = try XCTUnwrap(follow(postRequest("https://example.com/start"),
                                        to: "https://other.example/moved"))

    for name in credentialHeaders.keys {
      XCTAssertNil(redirect.value(forHTTPHeaderField: name), "\(name) must be removed")
    }
    assertHeaders(of: redirect, include: otherHeaders)
    XCTAssertEqual(redirect.httpMethod, "POST")
    XCTAssertEqual(redirect.httpBody, body)
  }

  func testCredentialHeadersAddedByTheProposedRequestAreRemovedForAnotherOrigin() throws {
    var proposed = URLRequest(url: URL(string: "https://other.example/moved")!)
    proposed.setValue("Bearer token", forHTTPHeaderField: "authorization")

    let redirect = try XCTUnwrap(RedirectPolicy.request(
      redirecting: postRequest("https://example.com/start"), to: proposed,
      policy: HTTPRequestPolicy()
    ))

    XCTAssertNil(redirect.value(forHTTPHeaderField: "Authorization"))
  }

  func testDifferentPortIsADifferentOrigin() throws {
    let redirect = try XCTUnwrap(follow(postRequest("https://example.com/start"),
                                        to: "https://example.com:8443/moved"))

    XCTAssertNil(redirect.value(forHTTPHeaderField: "Authorization"))
  }

  func testDifferentSchemeIsADifferentOrigin() throws {
    let redirect = try XCTUnwrap(follow(postRequest("http://example.com/start"),
                                        to: "https://example.com/moved"))

    XCTAssertNil(redirect.value(forHTTPHeaderField: "Authorization"))
  }

  func testRedirectToDefaultTrustedHostKeepsCredentials() throws {
    for target in ["https://googleapis.com/v1", "https://www.googleapis.com/v1",
                   "https://accounts.google.com/v1"] {
      let redirect = try XCTUnwrap(follow(postRequest("https://example.com/start"), to: target))

      assertHeaders(of: redirect, include: credentialHeaders, target)
    }
  }

  func testLookalikeHostIsNotTrusted() throws {
    for target in ["https://evilgoogleapis.com/v1", "https://googleapis.com.evil.example/v1"] {
      let redirect = try XCTUnwrap(follow(postRequest("https://example.com/start"), to: target))

      XCTAssertNil(redirect.value(forHTTPHeaderField: "Authorization"), target)
    }
  }

  func testPolicyCanTrustOtherHosts() throws {
    let policy = HTTPRequestPolicy(trustedRedirectHosts: ["us-central1-project.cloudfunctions.net"])

    let trusted = try XCTUnwrap(follow(postRequest("https://example.com/start"),
                                       to: "https://us-central1-project.cloudfunctions.net/f",
                                       policy: policy))
    let defaultTrustedHost = try XCTUnwrap(follow(postRequest("https://example.com/start"),
                                                  to: "https://www.googleapis.com/v1",
                                                  policy: policy))

    XCTAssertEqual(trusted.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    XCTAssertNil(defaultTrustedHost.value(forHTTPHeaderField: "Authorization"),
                 "A policy's hosts replace the default trusted hosts")
  }

  func testCredentialHeaderNamesAreCaseInsensitive() {
    XCTAssertTrue(RedirectPolicy.isCredentialHeader("AUTHORIZATION"))
    XCTAssertTrue(RedirectPolicy.isCredentialHeader("x-firebase-appcheck"))
    XCTAssertTrue(RedirectPolicy.isCredentialHeader("X-GOOG-API-KEY"))
    XCTAssertFalse(RedirectPolicy.isCredentialHeader("X-Firebase-GMPID"))
    XCTAssertFalse(RedirectPolicy.isCredentialHeader("Keyboard"))
  }

  // MARK: - Helpers

  private func postRequest(_ url: String) -> URLRequest {
    var request = URLRequest(url: URL(string: url)!, timeoutInterval: 70)
    request.httpMethod = "POST"
    request.httpBody = body
    for (name, value) in credentialHeaders.merging(otherHeaders, uniquingKeysWith: { $1 }) {
      request.setValue(value, forHTTPHeaderField: name)
    }
    return request
  }

  /// Follows a redirect the way `URLSession` proposes it: a `GET` with no body or headers.
  private func follow(_ request: URLRequest, to target: String,
                      policy: HTTPRequestPolicy = HTTPRequestPolicy()) -> URLRequest? {
    RedirectPolicy.request(redirecting: request, to: URLRequest(url: URL(string: target)!),
                           policy: policy)
  }

  private func assertHeaders(of request: URLRequest, include headers: [String: String],
                             _ message: String = "",
                             file: StaticString = #filePath, line: UInt = #line) {
    for (name, value) in headers {
      XCTAssertEqual(request.value(forHTTPHeaderField: name), value, "\(name) \(message)",
                     file: file, line: line)
    }
  }
}
