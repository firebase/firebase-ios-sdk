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
import GeminiTestUtilities
import Testing

@testable import GeminiAPIClient

/// Verifies the PKCE primitives against the RFC and against the properties the flow depends on.
@Suite("OrcaRouter PKCE Tests")
struct OrcaRouterPKCETests {
  @Test
  func challengeMatchesRFC7636AppendixBVector() {
    // RFC 7636 Appendix B: a published verifier and its expected challenge.
    let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    #expect(OrcaRouterPKCE.challenge(forVerifier: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
  }

  @Test
  func challengeIsUnpaddedBase64URL() {
    let challenge = OrcaRouterPKCE.challenge(forVerifier: "some-verifier")
    #expect(!challenge.contains("="))
    #expect(!challenge.contains("+"))
    #expect(!challenge.contains("/"))
  }

  @Test
  func challengeMethodIsAlwaysS256() {
    // `plain` is never acceptable: a redirect-flow user may still choose to be shown a code.
    #expect(OrcaRouterPKCE.challengeMethod == "S256")
  }

  @Test
  func verifierIsFreshForEveryAttempt() throws {
    let first = try OrcaRouterPKCE.makeVerifier()
    let second = try OrcaRouterPKCE.makeVerifier()
    #expect(first != second)
    // A 32-byte value in base64url is 43 characters with no padding.
    #expect(first.count == 43)
  }

  @Test
  func stateIsFreshForEveryAttempt() throws {
    let states = try (0..<64).map { _ in try OrcaRouterPKCE.makeState() }
    #expect(Set(states).count == states.count)
  }

  @Test
  func verifierIsHighEntropy() throws {
    // A guessable verifier would defeat the point of PKCE.
    var seen = Set<String>()
    for _ in 0..<256 {
      let verifier = try OrcaRouterPKCE.makeVerifier()
      #expect(!seen.contains(verifier))
      seen.insert(verifier)
    }
  }

  @Test
  func constantTimeCompareMatchesEquality() {
    #expect(OrcaRouterPKCE.constantTimeEquals("abc", "abc"))
    #expect(!OrcaRouterPKCE.constantTimeEquals("abc", "abd"))
    #expect(!OrcaRouterPKCE.constantTimeEquals("abc", "ab"))
    #expect(!OrcaRouterPKCE.constantTimeEquals("", "a"))
    #expect(OrcaRouterPKCE.constantTimeEquals("", ""))
  }

  @Test
  func eachAttemptDrawsItsOwnStateAndVerifier() throws {
    let provider = try OrcaRouterProvider(
      authentication: .account,
      authBaseURL: OrcaRouterTestConstants.authBaseURL,
      apiBaseURL: OrcaRouterTestConstants.apiBaseURL
    )
    let client = OrcaRouterAuthClient(provider: provider, appName: "Test App")

    let first = try client.beginAttempt()
    let second = try client.beginAttempt()

    #expect(first.state != second.state)
    #expect(first.challenge != second.challenge)
    #expect(first.codeVerifierForExchange != second.codeVerifierForExchange)
    #expect(first.identifier != second.identifier)
  }

  @Test
  func verifierIsNeverDerivedFromTheChallenge() throws {
    let attempt = try OrcaRouterAuthorizationAttempt(identifier: 1)
    #expect(attempt.challenge != attempt.codeVerifierForExchange)
    #expect(OrcaRouterPKCE.challenge(forVerifier: attempt.codeVerifierForExchange) == attempt.challenge)
  }

  @Test
  func challengeAndVerifierNeverAppearInTheAuthorizeURL() throws {
    let provider = try OrcaRouterProvider(
      authentication: .account,
      authBaseURL: OrcaRouterTestConstants.authBaseURL,
      apiBaseURL: OrcaRouterTestConstants.apiBaseURL
    )
    let client = OrcaRouterAuthClient(provider: provider, appName: "Test App")
    let attempt = try client.beginAttempt()
    let url = try client.authorizationURL(for: attempt)

    // Only the derived challenge may travel; the verifier must stay in the process.
    #expect(url.absoluteString.contains(attempt.challenge))
    #expect(!url.absoluteString.contains(attempt.codeVerifierForExchange))
  }

  @Test
  func authorizeURLUsesOnlyUnderstoodParameters() throws {
    let provider = try OrcaRouterProvider(
      authentication: .account,
      authBaseURL: OrcaRouterTestConstants.authBaseURL,
      apiBaseURL: OrcaRouterTestConstants.apiBaseURL
    )
    let client = OrcaRouterAuthClient(provider: provider, appName: "Orca Test")
    let attempt = try client.beginAttempt()
    let url = try client.authorizationURL(for: attempt)

    #expect(url.host == OrcaRouterTestConstants.authHost)
    #expect(url.path == "/auth")

    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let values: [String: String] = items.reduce(into: [:]) { result, item in
      result[item.name] = item.value ?? ""
    }

    #expect(values["callback_url"] == "oob")
    #expect(values["code_challenge_method"] == "S256")
    #expect(values["state"] == attempt.state)
    #expect(values["app_name"] == "Orca Test")
    #expect(values["scope"] == "api")
    #expect(values["code_challenge"] == attempt.challenge)
    // Nothing may preselect or suppress the "show me a code" delivery choice.
    #expect(values["delivery"] == nil)
  }

  @Test
  func authorizePathIsNotDerivedFromTheInferencePath() throws {
    let provider = try OrcaRouterProvider(authentication: .account, environment: [:])
    let url = try provider.makeAuthURL(path: OrcaRouterProvider.authorizePath)
    #expect(url.absoluteString == "https://www.orcarouter.ai/auth")
    #expect(!url.absoluteString.contains("api.orcarouter.ai"))
  }
}
