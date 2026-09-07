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

#if canImport(Testing)
  import Foundation
  package import GeminiAPIClient
  package import Testing

  /// Represents an integration testing backend for Gemini API requests.
  package enum IntegrationTestingBackend:
    Sendable,
    Hashable,
    CaseIterable,
    CustomStringConvertible
  {
    /// Gemini Developer API (via `generativelanguage.googleapis.com`).
    case developerAPI

    /// Firebase AI Logic proxying to the Gemini Developer API (via
    /// `firebasevertexai.googleapis.com`).
    case firebaseAILogicDeveloperAPI

    /// Firebase AI Logic proxying to the Gemini Enterprise Agent Platform (via
    /// `firebasevertexai.googleapis.com`).
    case firebaseAILogicAgentPlatform(location: String)

    /// Convenience instance targeting the global Gemini Enterprise Agent Platform.
    package static var firebaseAILogicAgentPlatform: IntegrationTestingBackend {
      .firebaseAILogicAgentPlatform(location: "global")
    }

    /// All canonical backend configurations for parameterized testing.
    package static let allCases: [IntegrationTestingBackend] = [
      .developerAPI,
      .firebaseAILogicDeveloperAPI,
      .firebaseAILogicAgentPlatform(location: "global"),
    ]

    package var description: String {
      switch self {
      case .developerAPI:
        return "Developer API"
      case .firebaseAILogicDeveloperAPI:
        return "Firebase AI Logic (Developer API)"
      case .firebaseAILogicAgentPlatform(let location):
        return "Firebase AI Logic (Agent Platform, \(location))"
      }
    }

    /// Indicates whether the required credentials are available for this backend in the
    /// specified test environment.
    ///
    /// - Parameter environment: The test environment to evaluate. Defaults to `.process`.
    /// - Returns: `true` if this backend is available to execute tests; otherwise, `false`.
    package func isAvailable(in environment: IntegrationTestEnvironment = .process) -> Bool {
      switch self {
      case .developerAPI:
        return environment.hasGeminiAPIKey

      case .firebaseAILogicDeveloperAPI, .firebaseAILogicAgentPlatform:
        return environment.hasFirebaseAILogicCredentials
      }
    }

    /// Indicates whether the required credentials are available for this backend.
    package var isAvailable: Bool {
      isAvailable(in: .process)
    }

    /// The list of backends that are currently available to execute tests against.
    package static var availableBackends: [IntegrationTestingBackend] {
      allCases.filter(\.isAvailable)
    }

    /// The network endpoint configuration for this backend.
    package var endpointConfiguration: EndpointConfiguration {
      switch self {
      case .developerAPI:
        return .geminiDeveloperAPI

      case .firebaseAILogicDeveloperAPI, .firebaseAILogicAgentPlatform:
        return .firebaseAILogic
      }
    }

    /// The model resource configuration for this backend given a model identifier.
    package func modelResource(
      modelID: String = ModelResource.gemini35FlashLiteID
    ) throws -> ModelResource {
      switch self {
      case .developerAPI:
        return ModelResource(
          modelID: modelID,
          urlResourceName: "models/\(modelID)",
          payloadResourceName: "models/\(modelID)"
        )

      case .firebaseAILogicDeveloperAPI:
        let projectID = try resolveProjectID()
        return ModelResource(
          modelID: modelID,
          urlResourceName: "projects/\(projectID)/models/\(modelID)",
          payloadResourceName: "models/\(modelID)"
        )

      case .firebaseAILogicAgentPlatform(let location):
        let projectID = try resolveProjectID()
        let resourcePath =
          "projects/\(projectID)/locations/\(location)/publishers/google/models/\(modelID)"
        return ModelResource(
          modelID: modelID,
          urlResourceName: resourcePath,
          payloadResourceName: "models/\(modelID)"
        )
      }
    }

    /// Creates the authentication header provider for this backend.
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    package func makeHeaderProvider() async throws -> (
      @Sendable () async throws -> [String: String]
    )? {
      switch self {
      case .developerAPI:
        if let apiKey = geminiAPIKey {
          return { ["x-goog-api-key": apiKey] }
        }
        return nil

      case .firebaseAILogicDeveloperAPI, .firebaseAILogicAgentPlatform:
        let projectID = try resolveProjectID()
        guard let appID = firebaseAppID else {
          throw IntegrationBackendError.missingCredential("firebaseAppID")
        }
        guard let apiKey = firebaseAPIKey else {
          throw IntegrationBackendError.missingCredential("firebaseAPIKey")
        }
        guard let debugToken = appCheckDebugToken else {
          throw IntegrationBackendError.missingCredential("appCheckDebugToken")
        }
        let appCheckToken = try await AppCheckTokenCache.shared.token(
          projectID: projectID,
          appID: appID,
          apiKey: apiKey,
          debugToken: debugToken
        )
        return {
          [
            "x-goog-api-key": apiKey,
            "x-firebase-appcheck": appCheckToken,
          ]
        }
      }
    }

    private func resolveProjectID() throws -> String {
      guard let projectID = firebaseProjectID else {
        throw IntegrationBackendError.missingCredential("firebaseProjectID")
      }
      return projectID
    }
  }

  // MARK: - Backend Errors

  /// Errors thrown when configuring integration testing backends.
  package enum IntegrationBackendError: Error, LocalizedError, Sendable {
    case missingCredential(String)

    package var errorDescription: String? {
      switch self {
      case .missingCredential(let name):
        return "Missing required integration test credential: \(name)"
      }
    }
  }

  // MARK: - Testing Traits

  /// Indicates whether any integration backend (Developer API or Firebase AI Logic) is available.
  package var hasIntegrationTestingBackend: Bool {
    !IntegrationTestingBackend.availableBackends.isEmpty
  }

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  extension Trait where Self == Testing.ConditionTrait {
    /// Requires at least one integration backend to be available.
    package static var requireIntegrationTestingBackend: Self {
      .enabled(
        if: hasIntegrationTestingBackend,
        "Requires credentials for Developer API or Firebase AI Logic"
      )
    }
  }
#endif  // canImport(Testing)
