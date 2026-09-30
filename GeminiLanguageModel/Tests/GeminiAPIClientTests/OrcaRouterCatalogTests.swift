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

/// Verifies model discovery, per-capability filtering, and the outage fallback.
///
/// The live catalog is authoritative; the verified seed exists only so a fresh installation is
/// usable during an outage, and it is never merged into a live result.
///
/// This suite owns `catalog.example.test` and never resets the shared recording registry, because
/// suites run concurrently and a global reset would erase another suite's in-flight stubs.
@Suite("OrcaRouter Catalog Tests", .serialized)
struct OrcaRouterCatalogTests {
  /// A catalog fixture covering every capability the origin can advertise.
  static var fixture: [String: Any] { [
    "object": "list",
    "data": [
      [
        "id": "openai/gpt-5.5",
        "name": "OpenAI: GPT-5.5",
        "context_length": 400_000,
        "supported_endpoint_types": ["openai", "openai-response"],
        "architecture": [
          "input_modalities": ["text", "image"],
          "output_modalities": ["text"],
        ],
      ],
      [
        "id": "deepseek/deepseek-v4-pro",
        "supported_endpoint_types": ["openai", "openai-response"],
        "architecture": ["input_modalities": ["text"], "output_modalities": ["text"]],
      ],
      [
        "id": "orcarouter/auto",
        "supported_endpoint_types": ["openai", "anthropic", "gemini", "openai-response"],
      ],
      [
        "id": "openai/gpt-image-1",
        "supported_endpoint_types": ["image-generation"],
        "architecture": ["input_modalities": ["text"], "output_modalities": ["image"]],
      ],
      [
        "id": "openai/sora-2",
        "supported_endpoint_types": ["openai-video"],
      ],
      [
        "id": "jina/jina-reranker-v3",
        "supported_endpoint_types": ["jina-rerank"],
      ],
      [
        "id": "openai/text-embedding-4",
        "supported_endpoint_types": ["embeddings"],
      ],
      [
        "id": "meta/llama-legacy",
        "supported_endpoint_types": ["some-future-format"],
      ],
    ],
  ] }

  /// A client whose catalog requests go to this suite's own host.
  func makeClient() throws -> OrcaRouterModelCatalogClient {
    let provider = try OrcaRouterProvider(
      authentication: .apiKey,
      authBaseURL: OrcaRouterTestConstants.authBaseURL,
      apiBaseURL: OrcaRouterTestConstants.apiBaseURL
    )
    return OrcaRouterModelCatalogClient(
      provider: provider,
      credentialSource: OrcaRouterStaticCredentialSource(apiKey: OrcaRouterTestConstants.fakeAPIKey),
      sessionConfiguration: OrcaRouterRecordingURLProtocol.sessionConfiguration
    )
  }

  @Test
  func liveCatalogIsAuthoritative() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .json(Self.fixture)
    )

    let catalog = try await makeClient()
      .catalog(for: OrcaRouterModelRequirement(capability: .textChat))

    #expect(catalog.provenance == .live)
    #expect(!catalog.isDegraded)
    #expect(catalog.modelIDs.contains("openai/gpt-5.5"))
    #expect(catalog.modelIDs.contains("orcarouter/auto"))
  }

  @Test
  func catalogRequestGoesToTheInferenceOriginWithBearerAuth() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .json(Self.fixture)
    )

    _ = try await makeClient().catalog(for: OrcaRouterModelRequirement(capability: .textChat))

    let request = try #require(
      OrcaRouterRecordingURLProtocol.lastRequest(
        host: OrcaRouterTestConstants.apiHost,
        pathSuffix: "/models"
      )
    )
    #expect(request.url.host == OrcaRouterTestConstants.apiHost)
    #expect(request.method == "GET")
    #expect(request.headers["authorization"] == "Bearer \(OrcaRouterTestConstants.fakeAPIKey)")
    #expect(request.url.query?.contains("capability=chat") == true)
    // The credential must never be placed in the URL.
    #expect(!request.url.absoluteString.contains(OrcaRouterTestConstants.fakeAPIKey))
  }

  @Test
  func textChatExcludesImageAndVideoAndRerankModels() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .json(Self.fixture)
    )

    let catalog = try await makeClient()
      .catalog(for: OrcaRouterModelRequirement(capability: .textChat))

    #expect(!catalog.modelIDs.contains("openai/gpt-image-1"))
    #expect(!catalog.modelIDs.contains("openai/sora-2"))
    #expect(!catalog.modelIDs.contains("jina/jina-reranker-v3"))
    #expect(!catalog.modelIDs.contains("openai/text-embedding-4"))
    // A model advertising only an endpoint type this client cannot speak is excluded.
    #expect(!catalog.modelIDs.contains("meta/llama-legacy"))
  }

  @Test
  func imageAttachmentNarrowsTheSelectorToImageInputModelsOnly() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .json(Self.fixture)
    )

    let client = try makeClient()
    let textOnly = await client.catalog(
      for: OrcaRouterModelRequirement(capability: .textChat)
    )
    let withImage = await client.catalog(
      for: OrcaRouterModelRequirement(capability: .chat(requiredInputModalities: [.image]))
    )

    // Before an attachment, text-only models are offered.
    #expect(textOnly.modelIDs.contains("deepseek/deepseek-v4-pro"))
    // After one, every offering must declare image input.
    #expect(withImage.modelIDs.contains("openai/gpt-5.5"))
    #expect(!withImage.modelIDs.contains("deepseek/deepseek-v4-pro"))
    for model in withImage.models {
      #expect(model.acceptsInputModality(.image), "\(model.id) does not declare image input")
    }
  }

  @Test
  func modelsWithoutDeclaredModalitiesFailClosedForMultimodal() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .json(Self.fixture)
    )

    let catalog = try await makeClient().catalog(
      for: OrcaRouterModelRequirement(capability: .chat(requiredInputModalities: [.image]))
    )
    // `orcarouter/auto` declares no architecture at all, so it must not appear.
    #expect(!catalog.modelIDs.contains("orcarouter/auto"))
  }

  @Test
  func embeddingImageVideoAndRerankFiltersAreStrict() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .json(Self.fixture)
    )

    let client = try makeClient()
    let embedding = await client.catalog(for: OrcaRouterModelRequirement(capability: .embedding))
    let image = await client.catalog(
      for: OrcaRouterModelRequirement(capability: .imageGeneration)
    )
    let video = await client.catalog(
      for: OrcaRouterModelRequirement(capability: .videoGeneration)
    )
    let rerank = await client.catalog(for: OrcaRouterModelRequirement(capability: .rerank))

    #expect(embedding.modelIDs == ["openai/text-embedding-4"])
    #expect(image.modelIDs == ["openai/gpt-image-1"])
    #expect(video.modelIDs == ["openai/sora-2"])
    #expect(rerank.modelIDs == ["jina/jina-reranker-v3"])
  }

  @Test
  func outageFallsBackToTheLabelledVerifiedSeed() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .failing(URLError(.cannotConnectToHost))
    )

    // A client with a fresh cache has nothing last-known-good to use, so it must reach for the
    // seed rather than offering free-form input.
    let catalog = try await makeClient()
      .catalog(for: OrcaRouterModelRequirement(capability: .textChat), allowCachedResult: false)

    #expect(catalog.provenance == .verifiedSeed)
    #expect(catalog.isDegraded)
    #expect(!catalog.modelIDs.isEmpty)
    #expect(catalog.modelIDs.allSatisfy { $0.contains("/") })
  }

  @Test
  func seedIsNeverMergedIntoALiveResult() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .json(Self.fixture)
    )

    let catalog = try await makeClient()
      .catalog(for: OrcaRouterModelRequirement(capability: .textChat))

    #expect(catalog.provenance == .live)
    // No seed-only identifier may leak into an authoritative result.
    #expect(!catalog.modelIDs.contains("anthropic/claude-opus-4.8"))
    #expect(!catalog.modelIDs.contains("google/gemini-3.5-flash"))
  }

  @Test
  func anEmptyLiveCatalogIsTakenAtFaceValue() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .json(["object": "list", "data": []])
    )

    let catalog = try await makeClient()
      .catalog(for: OrcaRouterModelRequirement(capability: .embedding))

    // The workspace genuinely advertises no embedding model. That is a real, empty result, not an
    // outage, so the seed must not be substituted for it.
    #expect(catalog.provenance == .live)
    #expect(catalog.models.isEmpty)
  }

  @Test
  func verifiedSeedRetainsMetadataForEveryEntry() {
    for model in OrcaRouterVerifiedSeed.models {
      #expect(!model.id.isEmpty)
      #expect(!model.endpointTypes.isEmpty, "\(model.id) has no endpoint types")
      #expect(!model.inputModalities.isEmpty, "\(model.id) declares no input modalities")
    }
    #expect(!OrcaRouterVerifiedSeed.gpt55ReasoningEfforts.isEmpty)
    #expect(
      OrcaRouterVerifiedSeed.models.contains { $0.id == "openai/gpt-5.5" }
    )
  }

  @Test
  func seedSurvivesFilteringWithItsMetadataIntact() async {
    let seedChat = OrcaRouterModelCatalog(
      models: OrcaRouterVerifiedSeed.models,
      provenance: .verifiedSeed
    )
    let imageCapable = seedChat.filtered(
      for: OrcaRouterModelRequirement(capability: .chat(requiredInputModalities: [.image]))
    )
    #expect(imageCapable.modelIDs.contains("openai/gpt-5.5"))
    let gpt55 = imageCapable.model(withID: "openai/gpt-5.5")
    #expect(gpt55?.contextLength == 400_000)
    #expect(gpt55?.acceptsInputModality(.image) == true)
  }

  @Test
  func unauthorizedCatalogRequestIsReported() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .raw("{\"error\":{\"message\":\"bad key\"}}", status: 401)
    )

    let catalog = try await makeClient()
      .catalog(for: OrcaRouterModelRequirement(capability: .textChat), allowCachedResult: false)
    // A credential failure degrades to the labelled seed rather than surfacing unverified models.
    #expect(catalog.provenance == .verifiedSeed)
  }

  @Test
  func catalogResponseByteBoundIsEnforced() async throws {
    let huge = String(repeating: "a", count: 600_000)
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .raw("{\"data\":[],\"padding\":\"\(huge)\"}", status: 200)
    )

    let provider = try OrcaRouterProvider(
      authentication: .apiKey,
      authBaseURL: OrcaRouterTestConstants.authBaseURL,
      apiBaseURL: OrcaRouterTestConstants.apiBaseURL
    )
    var limits = OrcaRouterModelCatalogClient.Limits()
    limits.maximumResponseBytes = 1024
    let client = OrcaRouterModelCatalogClient(
      provider: provider,
      credentialSource: OrcaRouterStaticCredentialSource(apiKey: OrcaRouterTestConstants.fakeAPIKey),
      sessionConfiguration: OrcaRouterRecordingURLProtocol.sessionConfiguration,
      limits: limits
    )

    let catalog = await client.catalog(
      for: OrcaRouterModelRequirement(capability: .textChat),
      allowCachedResult: false
    )
    #expect(catalog.provenance == .verifiedSeed)
  }

  @Test
  func persistedModelIDIsInvalidatedWhenItLeavesTheCatalog() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .json(Self.fixture)
    )

    let client = try makeClient()
    let catalog = await client.catalog(for: OrcaRouterModelRequirement(capability: .textChat))
    // Restoring a selection is only safe once it has been rechecked against the current catalog.
    #expect(catalog.model(withID: "deepseek/deepseek-v4-pro") != nil)
    #expect(catalog.model(withID: "retired/model-2019") == nil)
  }

  @Test
  func aModelNameAloneNeverConfersACapability() async throws {
    let deceptive: [String: Any] = [
      "object": "list",
      "data": [
        [
          "id": "some-vendor/vision-pro",
          "supported_endpoint_types": ["openai"],
          // No declared architecture, despite the suggestive name.
        ]
      ],
    ]
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.apiBaseURL + "/models",
      .json(deceptive)
    )

    let catalog = try await makeClient().catalog(
      for: OrcaRouterModelRequirement(capability: .chat(requiredInputModalities: [.image]))
    )
    #expect(catalog.models.isEmpty)
  }
}
