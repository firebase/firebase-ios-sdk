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
import Synchronization

#if canImport(Darwin)
  package import Foundation
#else
  package import FoundationNetworking
#endif

// MARK: - Model Catalog

/// The set of OrcaRouter models usable for a particular capability.
package struct OrcaRouterModelCatalog: Sendable, Equatable {
  /// Where the entries came from.
  package enum Provenance: String, Sendable, Equatable {
    /// A live, authenticated call to the configured inference origin.
    case live
    /// A previously successful live result, retained because the origin is unreachable.
    case lastKnownGood
    /// The small verified seed shipped with the SDK.
    case verifiedSeed
  }

  /// The entries in the catalog.
  package let models: [OrcaRouterModel]

  /// Where the entries came from.
  package let provenance: Provenance

  /// Whether the catalog is a degraded substitute for a live result.
  package var isDegraded: Bool {
    provenance != .live
  }

  /// The catalog is only ever a subset of what the origin advertises for one capability.
  ///
  /// - Parameters:
  ///   - models: The entries.
  ///   - provenance: Where the entries came from.
  package init(models: [OrcaRouterModel], provenance: Provenance) {
    self.models = models
    self.provenance = provenance
  }

  /// The model identifiers, in catalog order.
  package var modelIDs: [String] { models.map(\.id) }

  /// Looks up a model by its identifier.
  ///
  /// Used before restoring a persisted selection so a model that disappeared from the catalog is
  /// not silently kept.
  ///
  /// - Parameter id: The model identifier.
  package func model(withID id: String) -> OrcaRouterModel? {
    models.first { $0.id == id }
  }

  /// Returns this catalog filtered to models compatible with the given requirement.
  ///
  /// - Parameter requirement: The capability requirement to filter on.
  package func filtered(for requirement: OrcaRouterModelRequirement) -> OrcaRouterModelCatalog {
    OrcaRouterModelCatalog(
      models: models.filter { requirement.isSatisfied(by: $0) },
      provenance: provenance
    )
  }
}

// MARK: - Model

/// One model advertised by OrcaRouter's model catalog.
package struct OrcaRouterModel: Sendable, Equatable, Hashable {
  /// The model identifier, kept exactly as the origin reports it, including its
  /// `vendor/model` namespace.
  package let id: String

  /// A human-readable name, when the origin supplies one.
  package let displayName: String?

  /// The context window in tokens, when advertised.
  package let contextLength: Int?

  /// The maximum completion length in tokens, when advertised.
  package let maxCompletionTokens: Int?

  /// The request/response wire formats the model can speak, mirroring
  /// `supported_endpoint_types`.
  package let endpointTypes: [String]

  /// The input modalities the model declares, mirroring `architecture.input_modalities`.
  ///
  /// An absent or empty value means the origin did not declare any. Models are failed closed on
  /// this: a model that does not declare image input never appears in a multimodal selector.
  package let inputModalities: [String]

  /// The output modalities the model declares, when advertised.
  package let outputModalities: [String]?

  /// Creates a model entry.
  package init(
    id: String,
    displayName: String? = nil,
    contextLength: Int? = nil,
    maxCompletionTokens: Int? = nil,
    endpointTypes: [String] = [],
    inputModalities: [String] = [],
    outputModalities: [String]? = nil
  ) {
    self.id = id
    self.displayName = displayName
    self.contextLength = contextLength
    self.maxCompletionTokens = maxCompletionTokens
    self.endpointTypes = endpointTypes
    self.inputModalities = inputModalities
    self.outputModalities = outputModalities
  }

  /// The vendor namespace, the segment before the first `/`.
  package var vendor: String? {
    guard let separator = id.firstIndex(of: "/") else { return nil }
    return String(id[id.startIndex..<separator])
  }

  /// Whether the model declares that it accepts an input modality.
  ///
  /// - Parameter modality: The modality to test, for example `image`.
  package func acceptsInputModality(_ modality: OrcaRouterModelModality) -> Bool {
    inputModalities.contains { $0.lowercased() == modality.rawValue }
  }
}

/// An input modality a model may accept.
package enum OrcaRouterModelModality: String, Sendable, CaseIterable {
  case text
  case image
  case audio
  case video
  case file
}

// MARK: - Wire Format

/// A request/response wire format a model can speak.
package enum OrcaRouterEndpointType: String, Sendable, CaseIterable {
  case openAI = "openai"
  case openAIResponses = "openai-response"
  case anthropic = "anthropic"
  case gemini = "gemini"
  case embeddings = "embeddings"
  case imageGeneration = "image-generation"
  case openAIVideo = "openai-video"
  case jinaRerank = "jina-rerank"

  /// The formats this client can actually speak when generating content.
  static let conversational: Set<OrcaRouterEndpointType> = [
    .openAI, .openAIResponses, .anthropic, .gemini,
  ]

  /// Formats that are conversational but never text-only.
  static let nonTextConversational: Set<OrcaRouterEndpointType> = [
    .imageGeneration, .openAIVideo, .jinaRerank,
  ]
}

// MARK: - Capability

/// What a caller intends to do with a model.
package enum OrcaRouterCapability: Sendable, Equatable, Hashable {
  /// Text or multimodal content generation.
  ///
  /// - Parameter requiredInputModalities: Non-text modalities the caller will actually send.
  ///   A model that does not declare every one of them is excluded.
  case chat(requiredInputModalities: Set<OrcaRouterModelModality>)

  /// Text generation with no attachment attached.
  package static var textChat: OrcaRouterCapability {
    .chat(requiredInputModalities: [])
  }

  /// Text embeddings.
  case embedding

  /// Image generation.
  case imageGeneration

  /// Video generation.
  case videoGeneration

  /// Document reranking.
  case rerank

  /// The `capability` query value to send for this capability, if the origin accepts one.
  package var queryValue: String? {
    switch self {
    case .chat: return "chat"
    case .embedding: return "embedding"
    case .imageGeneration: return "image"
    case .videoGeneration: return "video"
    case .rerank: return "rerank"
    }
  }
}

/// A capability requirement that a catalog can be filtered by.
package struct OrcaRouterModelRequirement: Sendable, Equatable {
  /// The capability being requested.
  package let capability: OrcaRouterCapability

  /// The wire formats the client can speak for this capability.
  package let acceptedEndpointTypes: Set<OrcaRouterEndpointType>

  /// Non-text input modalities the caller will actually send.
  package let requiredInputModalities: Set<OrcaRouterModelModality>

  /// Creates a requirement for a capability.
  ///
  /// - Parameter capability: The capability being requested.
  package init(capability: OrcaRouterCapability) {
    self.capability = capability
    switch capability {
    case .chat(let required):
      self.acceptedEndpointTypes = OrcaRouterEndpointType.conversational
      self.requiredInputModalities = required
    case .embedding:
      self.acceptedEndpointTypes = [.embeddings]
      self.requiredInputModalities = []
    case .imageGeneration:
      self.acceptedEndpointTypes = [.imageGeneration]
      self.requiredInputModalities = []
    case .videoGeneration:
      self.acceptedEndpointTypes = [.openAIVideo]
      self.requiredInputModalities = []
    case .rerank:
      self.acceptedEndpointTypes = [.jinaRerank]
      self.requiredInputModalities = []
    }
  }

  /// Whether a model satisfies this requirement.
  ///
  /// Capability is decided from declared metadata only. A model is never assumed to support
  /// something because its name suggests it, and a model that declares no input modalities never
  /// satisfies a requirement for a non-text modality.
  ///
  /// - Parameter model: The model to test.
  package func isSatisfied(by model: OrcaRouterModel) -> Bool {
    let declared = Set(model.endpointTypes.map { $0.lowercased() })
    let modelTypes = Set(declared.compactMap { OrcaRouterEndpointType(rawValue: $0) })

    guard !modelTypes.isDisjoint(with: acceptedEndpointTypes) else { return false }

    if case .chat = capability {
      // A conversational request must not be routed to a model that exists only to make images,
      // video, or reranking results.
      if !modelTypes.isDisjoint(with: OrcaRouterEndpointType.nonTextConversational) {
        return false
      }
    }

    for modality in requiredInputModalities where model.acceptsInputModality(modality) == false {
      return false
    }
    return true
  }
}

// MARK: - Catalog Client

/// Fetches OrcaRouter model catalogs and applies capability filtering.
///
/// Live discovery is authoritative. When it fails, the most recent successful result is retained;
/// failing that, the small verified seed keeps a fresh installation usable. The client never falls
/// back to free-form model input, and a live result is never mixed with seed entries.
package final class OrcaRouterModelCatalogClient: Sendable {
  /// The bounds applied to a single catalog response.
  package struct Limits: Sendable, Equatable {
    /// The request timeout.
    package var timeout: TimeInterval = 15
    /// The maximum number of response bytes read.
    package var maximumResponseBytes = 2 * 1024 * 1024
    /// The maximum number of entries accepted.
    package var maximumModelCount = 2000
  }

  private let provider: OrcaRouterProvider
  private let credentialSource: any OrcaRouterCredentialSource
  private let sessionConfiguration: URLSessionConfiguration
  private let limits: Limits
  private let cache = Mutex<[String: OrcaRouterModelCatalog]>([:])

  /// Creates a catalog client.
  ///
  /// - Parameters:
  ///   - provider: The provider whose inference origin and authentication entry to use.
  ///   - credentialSource: The adapter that supplies the credential.
  ///   - sessionConfiguration: The session configuration to use. Defaults to `.ephemeral`.
  ///   - limits: The response bounds.
  package init(
    provider: OrcaRouterProvider,
    credentialSource: any OrcaRouterCredentialSource,
    sessionConfiguration: URLSessionConfiguration = .ephemeral,
    limits: Limits = Limits()
  ) {
    self.provider = provider
    self.credentialSource = credentialSource
    self.sessionConfiguration = sessionConfiguration
    self.limits = limits
  }

  /// Retrieves the catalog for a capability.
  ///
  /// - Parameters:
  ///   - requirement: The capability requirement to filter on.
  ///   - allowCachedResult: Whether a previously fetched live result may be reused.
  /// - Returns: A catalog, either live or a labelled substitute.
  package func catalog(
    for requirement: OrcaRouterModelRequirement,
    allowCachedResult: Bool = true
  ) async -> OrcaRouterModelCatalog {
    let cacheKey = requirement.capability.queryValue ?? "all"
    do {
      let live = try await fetchLiveCatalog(for: requirement)
      cache.withLock { $0[cacheKey] = live }
      return live
    } catch {
      if allowCachedResult, let cached = cache.withLock({ $0[cacheKey] }) {
        return OrcaRouterModelCatalog(models: cached.models, provenance: .lastKnownGood)
      }
      return OrcaRouterModelCatalog(
        models: OrcaRouterVerifiedSeed.models.filter {
          requirement.isSatisfied(by: $0)
        },
        provenance: .verifiedSeed
      )
    }
  }

  /// Performs one authenticated catalog request.
  ///
  /// - Parameter requirement: The capability requirement, used for the `capability` query value.
  /// - Throws: A network or decoding error when the origin cannot be read.
  private func fetchLiveCatalog(
    for requirement: OrcaRouterModelRequirement
  ) async throws -> OrcaRouterModelCatalog {
    let credential = try await credentialSource.acquire()

    var components = URLComponents(
      url: try provider.makeAPIURL(path: OrcaRouterProvider.modelsPath),
      resolvingAgainstBaseURL: false
    )
    if let capability = requirement.capability.queryValue {
      components?.queryItems = [URLQueryItem(name: "capability", value: capability)]
    }
    guard let url = components?.url else { throw URLError(.badURL) }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = limits.timeout
    // The key is sent to the inference origin only. It never reaches the authentication origin, and
    // it is never placed in the URL.
    request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let session = URLSession(configuration: sessionConfiguration)
    defer { session.finishTasksAndInvalidate() }

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw OrcaRouterCatalogError.malformedResponse
    }
    guard data.count <= limits.maximumResponseBytes else {
      throw OrcaRouterCatalogError.responseTooLarge
    }
    switch http.statusCode {
    case 200:
      break
    case 401:
      throw OrcaRouterCatalogError.unauthorized
    case 403:
      throw OrcaRouterCatalogError.forbidden
    case 429:
      throw OrcaRouterCatalogError.rateLimited
    default:
      throw OrcaRouterCatalogError.unexpectedStatus(http.statusCode)
    }

    let payload = try JSONDecoder().decode(OrcaRouterModelListResponse.self, from: data)
    let models = payload.data.prefix(limits.maximumModelCount).compactMap { entry in
      OrcaRouterModel(entry)
    }
    return OrcaRouterModelCatalog(
      models: models.filter { requirement.isSatisfied(by: $0) },
      provenance: .live
    )
  }
}

// MARK: - Catalog Errors

/// Errors raised while reading the OrcaRouter model catalog.
package enum OrcaRouterCatalogError: Error, LocalizedError, Sendable, Equatable {
  /// The response was not an HTTP response or could not be decoded.
  case malformedResponse
  /// The response exceeded the configured bound.
  case responseTooLarge
  /// The credential was rejected; the account must authorize again.
  case unauthorized
  /// The credential is not permitted to read the catalog.
  case forbidden
  /// The origin is rate limiting the request.
  case rateLimited
  /// The origin returned an unexpected status.
  case unexpectedStatus(Int)

  package var errorDescription: String? {
    switch self {
    case .malformedResponse:
      return "The OrcaRouter model catalog response could not be read."
    case .responseTooLarge:
      return "The OrcaRouter model catalog response exceeded the permitted size."
    case .unauthorized:
      return "The OrcaRouter credential was rejected. Authorize again."
    case .forbidden:
      return "The OrcaRouter credential is not permitted to list models."
    case .rateLimited:
      return "OrcaRouter is rate limiting model catalog requests."
    case .unexpectedStatus(let status):
      return "The OrcaRouter model catalog returned HTTP \(status)."
    }
  }
}

// MARK: - Wire Models

/// The catalog response envelope.
struct OrcaRouterModelListResponse: Decodable {
  let data: [OrcaRouterModelEntry]
}

/// One catalog entry, mirroring the origin's fields.
struct OrcaRouterModelEntry: Decodable {
  struct Architecture: Decodable {
    let inputModalities: [String]?
    let outputModalities: [String]?

    enum CodingKeys: String, CodingKey {
      case inputModalities = "input_modalities"
      case outputModalities = "output_modalities"
    }
  }

  let id: String?
  let name: String?
  let contextLength: Int?
  let maxCompletionTokens: Int?
  let supportedEndpointTypes: [String]?
  let architecture: Architecture?

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case contextLength = "context_length"
    case maxCompletionTokens = "max_completion_tokens"
    case supportedEndpointTypes = "supported_endpoint_types"
    case architecture
  }
}

extension OrcaRouterModel {
  /// Builds a model from a catalog entry, rejecting entries with no usable identifier.
  ///
  /// - Parameter entry: The decoded catalog entry.
  init?(_ entry: OrcaRouterModelEntry) {
    guard let id = entry.id, !id.isEmpty else { return nil }
    self.init(
      id: id,
      displayName: entry.name,
      contextLength: entry.contextLength,
      maxCompletionTokens: entry.maxCompletionTokens,
      endpointTypes: entry.supportedEndpointTypes ?? [],
      inputModalities: entry.architecture?.inputModalities ?? [],
      outputModalities: entry.architecture?.outputModalities
    )
  }
}

// MARK: - Verified Seed

/// The small, verified catalog shipped with the SDK.
///
/// These entries exist so a fresh installation can offer a usable selector during an outage. They
/// are only ever used when live discovery fails, and are always labelled as degraded. Each entry
/// carries the metadata it was verified with; a live result replaces the whole set rather than
/// being merged with it.
package enum OrcaRouterVerifiedSeed {
  /// The seed entries, filtered by capability on use.
  package static let models: [OrcaRouterModel] = [
    OrcaRouterModel(
      id: "openai/gpt-5.5",
      displayName: "OpenAI: GPT-5.5",
      contextLength: 400_000,
      maxCompletionTokens: 128_000,
      endpointTypes: ["openai", "openai-response"],
      inputModalities: ["text", "image"],
      outputModalities: ["text"]
    ),
    OrcaRouterModel(
      id: "anthropic/claude-opus-4.8",
      displayName: "Anthropic: Claude Opus 4.8",
      contextLength: 200_000,
      maxCompletionTokens: 64_000,
      endpointTypes: ["openai", "anthropic"],
      inputModalities: ["text", "image"],
      outputModalities: ["text"]
    ),
    OrcaRouterModel(
      id: "google/gemini-3.5-flash",
      displayName: "Google: Gemini 3.5 Flash",
      contextLength: 1_000_000,
      maxCompletionTokens: 65_536,
      endpointTypes: ["openai", "gemini"],
      inputModalities: ["text", "image"],
      outputModalities: ["text"]
    ),
    OrcaRouterModel(
      id: "deepseek/deepseek-v4-pro",
      displayName: "DeepSeek: DeepSeek V4 Pro",
      contextLength: 1_048_576,
      maxCompletionTokens: 384_000,
      endpointTypes: ["openai", "openai-response"],
      inputModalities: ["text"],
      outputModalities: ["text"]
    ),
    OrcaRouterModel(
      id: "orcarouter/auto",
      displayName: "OrcaRouter: Auto",
      endpointTypes: ["openai", "openai-response", "anthropic", "gemini"],
      inputModalities: ["text"],
      outputModalities: ["text"]
    ),
  ]

  /// The reasoning effort levels verified for `openai/gpt-5.5`.
  ///
  /// Retained so enabling live discovery does not silently reduce a verified model's capabilities.
  package static let gpt55ReasoningEfforts = ["low", "medium", "high", "xhigh"]
}
