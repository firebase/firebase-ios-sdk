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
import GeminiAPIDataModels
import GeminiTestUtilities
import Synchronization
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@testable import GeminiAPIClient

/// Verifies that an OrcaRouter provider composes into the transport the SDK already uses, so the
/// provider is first-class rather than a parallel code path.
///
/// The suite owns `wiring.example.test`.
@Suite("OrcaRouter Wiring Tests", .serialized)
struct OrcaRouterWiringTests {
  static let host = "wiring.example.test"
  static let base = "https://wiring.example.test/v1"

  func makeProvider() throws -> OrcaRouterProvider {
    try OrcaRouterProvider(
      authentication: .apiKey,
      authBaseURL: OrcaRouterTestConstants.authBaseURL,
      apiBaseURL: Self.base
    )
  }

  @Test
  func theProviderYieldsTheInferenceEndpointConfiguration() throws {
    let configuration = try makeProvider().endpointConfigurationForTransport
    #expect(configuration.scheme == "https")
    #expect(configuration.host == Self.host)
    #expect(configuration.apiVersion == "v1")
    #expect(configuration.port == nil)
  }

  @Test
  func theModelResourceKeepsTheVendorNamespaceVerbatim() throws {
    let provider = try makeProvider()
    let resource = provider.modelResource(forModelIdentifier: "deepseek/deepseek-v4-pro")
    // OrcaRouter is not resource-oriented: no `models/` prefix is added, and the namespace survives.
    #expect(resource.modelID == "deepseek/deepseek-v4-pro")
    #expect(resource.urlResourceName == "deepseek/deepseek-v4-pro")
    #expect(resource.payloadResourceName == "deepseek/deepseek-v4-pro")
  }

  @Test
  func theHeaderProviderSendsTheCredentialAsABearerToken() async throws {
    let source = OrcaRouterStaticCredentialSource(apiKey: OrcaRouterTestConstants.fakeAPIKey)
    let headers = try await makeProvider().headerProvider(credentialSource: source).callAsFunction()
    #expect(headers["Authorization"] == "Bearer \(OrcaRouterTestConstants.fakeAPIKey)")
    #expect(headers.count == 1)
  }

  @Test
  func aRotatedCredentialIsPickedUpWithoutRebuildingTheProvider() async throws {
    let holder = RotatingCredentialSource(initial: "sk-orca-first")
    let headerProvider = try makeProvider().headerProvider(credentialSource: holder)

    let before = try await headerProvider.callAsFunction()
    #expect(before["Authorization"] == "Bearer sk-orca-first")

    // A reauthorization replaced the credential. The header is read per request, so it follows.
    holder.rotate(to: "sk-orca-second")
    let after = try await headerProvider.callAsFunction()
    #expect(after["Authorization"] == "Bearer sk-orca-second")
  }

  @Test
  func theWiringDrivesTheSDKsOwnClientToTheInferenceOrigin() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: Self.base + "/",
      .sse([#"{"candidates":[{"content":{"parts":[{"text":"hi"}]}}]}"#])
    )

    // The standard Gemini transport, configured exactly as the Foundation Models executor
    // configures it, reaches OrcaRouter with the provider's own values.
    let provider = try makeProvider()
    let client = GeminiAPIClient(
      modelResource: provider.modelResource(forModelIdentifier: "orcarouter/auto"),
      endpointConfiguration: provider.endpointConfigurationForTransport,
      headerProvider: provider.headerProvider(
        credentialSource: OrcaRouterStaticCredentialSource(apiKey: OrcaRouterTestConstants.fakeAPIKey)
      ),
      sessionConfiguration: OrcaRouterRecordingURLProtocol.sessionConfiguration
    )

    _ = try? await client.generateContentStream(
      for: GenerateContentRequest(
        model: "orcarouter/auto",
        contents: [Content(parts: [Part(data: .text("hi"))], role: "user")]
      )
    )

    let request = try #require(
      OrcaRouterRecordingURLProtocol.lastRequest(host: Self.host, pathSuffix: "/orcarouter/auto:streamGenerateContent")
    )
    #expect(request.headers["authorization"] == "Bearer \(OrcaRouterTestConstants.fakeAPIKey)")
  }
}

/// A credential source whose value can be replaced, standing in for a reauthorization.
final class RotatingCredentialSource: OrcaRouterCredentialSource, @unchecked Sendable {
  private let key = Mutex<String>("")

  init(initial: String) { key.withLock { $0 = initial } }

  func rotate(to newKey: String) {
    key.withLock { $0 = newKey }
  }

  func acquire() async throws -> OrcaRouterCredential {
    let value = key.withLock { $0 }
    return OrcaRouterCredential(apiKey: value, acquisition: .account)
  }
}
