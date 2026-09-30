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

/// Verifies the provider definition, the two authentication entries, and the origin policy.
@Suite("OrcaRouter Provider Tests")
struct OrcaRouterProviderTests {
  @Test
  func authenticationEntriesAreDistinctAndBothSelectable() {
    let all = OrcaRouterProvider.Authentication.allCases
    #expect(all.count == 2)
    #expect(Set(all.map(\.identifier)) == ["orcarouter", "orcarouter-oauth"])
    #expect(OrcaRouterProvider.Authentication.apiKey.displayName == "OrcaRouter - API")
    #expect(OrcaRouterProvider.Authentication.account.displayName == "OrcaRouter - Auth")
    // The two labels must stay distinguishable wherever they can appear together.
    #expect(
      OrcaRouterProvider.Authentication.apiKey.displayName
        != OrcaRouterProvider.Authentication.account.displayName
    )
  }

  @Test
  func publicDefaultsUseSeparateOrigins() throws {
    let provider = try OrcaRouterProvider(authentication: .apiKey, environment: [:])
    #expect(provider.authBaseURL.absoluteString == "https://www.orcarouter.ai")
    #expect(provider.apiBaseURL.absoluteString == "https://api.orcarouter.ai/v1")
  }

  @Test
  func authenticationOriginNeverDerivesFromInferenceOrigin() throws {
    // The single most common integration mistake is building the auth path off the relay origin.
    let provider = try OrcaRouterProvider(authentication: .account, environment: [:])
    let exchange = try provider.makeAuthURL(path: OrcaRouterProvider.exchangePath)
    #expect(exchange.absoluteString == "https://www.orcarouter.ai/api/v1/auth/keys")
    #expect(exchange.host == "www.orcarouter.ai")
    #expect(!exchange.absoluteString.contains("api.orcarouter.ai"))
    #expect(!exchange.absoluteString.contains("/v1/auth/keys") || exchange.path.hasPrefix("/api/"))
  }

  @Test
  func authorizeEndpointIsFixedAtAuthRoot() throws {
    let provider = try OrcaRouterProvider(authentication: .account, environment: [:])
    let authorize = try provider.makeAuthURL(path: OrcaRouterProvider.authorizePath)
    #expect(authorize.absoluteString == "https://www.orcarouter.ai/auth")
  }

  @Test
  func inferenceAndCatalogUseTheAPIVersionPath() throws {
    let provider = try OrcaRouterProvider(authentication: .apiKey, environment: [:])
    let models = try provider.makeAPIURL(path: OrcaRouterProvider.modelsPath)
    let completions = try provider.makeAPIURL(path: OrcaRouterProvider.chatCompletionsPath)
    #expect(models.absoluteString == "https://api.orcarouter.ai/v1/models")
    #expect(completions.absoluteString == "https://api.orcarouter.ai/v1/chat/completions")
  }

  @Test
  func sharedBaseAppliesToBothOrigins() throws {
    let environment = [OrcaRouterProvider.sharedBaseURLEnvironmentKey: "https://gateway.example.test"]
    let provider = try OrcaRouterProvider(authentication: .apiKey, environment: environment)
    #expect(provider.authBaseURL.absoluteString == "https://gateway.example.test")
    #expect(provider.apiBaseURL.absoluteString == "https://gateway.example.test/v1")
  }

  @Test
  func sharedBaseDoesNotDoubleAppendTheVersion() throws {
    let environment = [
      OrcaRouterProvider.sharedBaseURLEnvironmentKey: "https://gateway.example.test/v1"
    ]
    let provider = try OrcaRouterProvider(authentication: .apiKey, environment: environment)
    #expect(provider.apiBaseURL.absoluteString == "https://gateway.example.test/v1")
  }

  @Test
  func explicitOverridesTakePrecedenceOverSharedBase() throws {
    let environment = [
      OrcaRouterProvider.sharedBaseURLEnvironmentKey: "https://shared.example.test",
      OrcaRouterProvider.authBaseURLEnvironmentKey: "https://auth.example.test",
      OrcaRouterProvider.apiBaseURLEnvironmentKey: "https://relay.example.test/v1",
    ]
    let provider = try OrcaRouterProvider(authentication: .account, environment: environment)
    #expect(provider.authBaseURL.absoluteString == "https://auth.example.test")
    #expect(provider.apiBaseURL.absoluteString == "https://relay.example.test/v1")
  }

  @Test
  func separateSelfHostedOriginsAreHonoured() throws {
    let provider = try OrcaRouterProvider(
      authentication: .account,
      authBaseURL: OrcaRouterTestConstants.authBaseURL,
      apiBaseURL: OrcaRouterTestConstants.apiBaseURL
    )
    #expect(try provider.makeAuthURL(path: "/auth").host == OrcaRouterTestConstants.authHost)
    #expect(try provider.makeAPIURL(path: "/models").host == OrcaRouterTestConstants.apiHost)
  }

  @Test
  func plainHTTPIsRejectedForRemoteHosts() {
    #expect(throws: OrcaRouterOriginError.self) {
      try OrcaRouterOriginPolicy.validate("http://orcarouter.example.test", role: .inference)
    }
  }

  @Test
  func plainHTTPIsPermittedForLoopback() throws {
    for host in ["localhost", "127.0.0.1", "[::1]"] {
      let url = try OrcaRouterOriginPolicy.validate("http://\(host):8080", role: .authentication)
      #expect(url.host != nil)
    }
  }

  @Test
  func userInfoAndFragmentsAreRejected() {
    #expect(throws: OrcaRouterOriginError.self) {
      try OrcaRouterOriginPolicy.validate("https://user:pass@example.test", role: .authentication)
    }
    #expect(throws: OrcaRouterOriginError.self) {
      try OrcaRouterOriginPolicy.validate("https://example.test/#fragment", role: .inference)
    }
  }

  @Test
  func unsupportedSchemesAreRejected() {
    #expect(throws: OrcaRouterOriginError.self) {
      try OrcaRouterOriginPolicy.validate("ftp://example.test", role: .inference)
    }
  }

  @Test
  func endpointConfigurationMirrorsTheInferenceOrigin() throws {
    let provider = try OrcaRouterProvider(authentication: .apiKey, environment: [:])
    let configuration = provider.apiEndpointConfiguration
    #expect(configuration.host == "api.orcarouter.ai")
    #expect(configuration.scheme == "https")
    #expect(configuration.apiVersion == "v1")
  }

  @Test
  func dashboardAndRevocationLinksAreAdvertised() {
    #expect(OrcaRouterProvider.keyManagementURLString.hasPrefix("https://www.orcarouter.ai/"))
    #expect(OrcaRouterProvider.authorizedAppsURLString.hasPrefix("https://www.orcarouter.ai/"))
    #expect(OrcaRouterProvider.discoveryURLString.contains(".well-known/openid-configuration"))
  }

  @Test
  func scopeIsTheApiScope() {
    #expect(OrcaRouterProvider.scope == "api")
  }
}
