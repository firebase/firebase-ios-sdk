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

#if canImport(FoundationModels) && compiler(>=6.4)
  import Foundation
  import FoundationModels
  import GeminiAPIClient
  import GeminiTestUtilities
  import Testing

  @testable import GeminiLanguageModel

  /// Integration tests for guided generation (structured output) using `GeminiLanguageModel`.
  @Suite("Guided Generation Integration Tests", .requireFoundationModels)
  struct GuidedGenerationIntegrationTests {
    @Generable(description: "A summary of a city")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct CitySummary {
      var name: String
      var country: String
    }

    @Test(
      .tags(.integration),
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithSchema(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)

      let response = try await session.respond(
        to: "Provide details for the city of Paris.",
        generating: CitySummary.self
      )

      #expect(!response.content.name.isEmpty)
      #expect(!response.content.country.isEmpty)
      #expect(response.usage.totalTokenCount > 0)
      #expect(response.usage.input.totalTokenCount > 0)
      #expect(response.usage.output.totalTokenCount > 0)
    }

    @Test(
      .tags(.integration),
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponseWithSchema(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)

      let stream = session.streamResponse(
        to: "Provide details for the city of Tokyo.",
        generating: CitySummary.self
      )
      var snapshotCount = 0
      for try await _ in stream {
        snapshotCount += 1
      }
      let response = try await stream.collect()

      #expect(snapshotCount > 0)
      #expect(!response.content.name.isEmpty)
      #expect(!response.content.country.isEmpty)
      #expect(response.usage.totalTokenCount > 0)
      #expect(response.usage.input.totalTokenCount > 0)
      #expect(response.usage.output.totalTokenCount > 0)
    }

    @Generable(description: "A priority level for a support ticket")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    enum TicketPriority: String {
      case low
      case medium
      case high
      case critical
    }

    @Generable(description: "A classified support ticket")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct TicketClassification {
      var summary: String
      var priority: TicketPriority
    }

    @Test(
      .tags(.integration),
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithEnumClassification(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)

      let response = try await session.respond(
        to: "The entire production database server is down and users cannot log in.",
        generating: TicketClassification.self
      )

      #expect(!response.content.summary.isEmpty)
      #expect(
        response.content.priority == .high || response.content.priority == .critical
      )
      #expect(response.usage.totalTokenCount > 0)
      #expect(response.usage.input.totalTokenCount > 0)
      #expect(response.usage.output.totalTokenCount > 0)
    }

    @Generable(description: "An organization node in an organizational hierarchy")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct OrganizationNode {
      var name: String
      var headcount: Int
      var budgetMillions: Double
      var isActive: Bool
      var notes: String?
      var skills: [String]
      var subteams: [OrganizationNode]
    }

    @Test(
      .tags(.integration),
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithRecursiveHierarchy(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)

      let prompt = """
        Generate an engineering department named "Platform" with 50 people, a budget of \
        4.5 million, active status, notes "Core infrastructure team", skills ["Swift", "Go"], \
        and one subteam named "Networking" with 10 people, budget 1.0 million, active status, \
        skills ["TCP", "HTTP"], and no subteams.
        """
      let response = try await session.respond(
        to: prompt,
        generating: OrganizationNode.self
      )

      #expect(!response.content.name.isEmpty)
      #expect(response.content.headcount > 0)
      #expect(response.content.budgetMillions > 0.0)
      #expect(response.content.isActive)
      #expect(!response.content.skills.isEmpty)
      #expect(response.content.subteams.count >= 1)
      let firstSubteam = try #require(response.content.subteams.first)
      #expect(!firstSubteam.name.isEmpty)
      #expect(firstSubteam.headcount > 0)
      #expect(firstSubteam.budgetMillions > 0.0)
      #expect(firstSubteam.isActive)
      #expect(response.usage.totalTokenCount > 0)
      #expect(response.usage.input.totalTokenCount > 0)
      #expect(response.usage.output.totalTokenCount > 0)
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
