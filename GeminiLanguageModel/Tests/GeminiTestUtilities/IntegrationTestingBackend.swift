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
      // Integration tests target Firebase AI Logic only. Uncomment for manual testing against
      // the Gemini Developer API directly (requires `GEMINI_API_KEY` or `GOOGLE_API_KEY`).
      // .developerAPI,
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
    /// In `replay` mode, every backend is available because recorded interactions don't require
    /// credentials.
    ///
    /// - Parameter environment: The test environment to evaluate. Defaults to `.process`.
    /// - Returns: `true` if this backend is available to execute tests; otherwise, `false`.
    package func isAvailable(in environment: IntegrationTestEnvironment = .process) -> Bool {
      if environment.integrationTestMode == .replay {
        return true
      }

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

    /// The network endpoint configuration for this backend in the process environment.
    package var endpointConfiguration: EndpointConfiguration {
      endpointConfiguration(in: .process)
    }

    /// The network endpoint configuration for this backend in the specified test environment.
    ///
    /// In `record` and `replay` modes, requests are sent to the local test-server proxy for the
    /// backend's host instead of the live endpoint.
    ///
    /// - Parameter environment: The test environment to evaluate.
    /// - Returns: The endpoint configuration to use for requests.
    package func endpointConfiguration(
      in environment: IntegrationTestEnvironment
    ) -> EndpointConfiguration {
      let liveConfiguration: EndpointConfiguration
      let apiVersion: String
      let testServerPort: Int
      switch self {
      case .developerAPI:
        liveConfiguration = .geminiDeveloperAPI
        apiVersion = EndpointConfiguration.geminiDeveloperAPIVersion
        testServerPort = TestServerConfiguration.developerAPIPort

      case .firebaseAILogicDeveloperAPI, .firebaseAILogicAgentPlatform:
        liveConfiguration = .firebaseAILogic
        apiVersion = EndpointConfiguration.firebaseAILogicAPIVersion
        testServerPort = TestServerConfiguration.firebaseAILogicPort
      }

      guard environment.integrationTestMode.usesTestServer else {
        return liveConfiguration
      }
      return EndpointConfiguration(
        scheme: "http",
        host: TestServerConfiguration.host,
        port: testServerPort,
        apiVersion: apiVersion
      )
    }

    /// The model resource configuration for this backend given a model identifier.
    ///
    /// - Parameters:
    ///   - modelID: The model identifier. Defaults to `gemini-3.5-flash-lite`.
    ///   - environment: The test environment to evaluate. Defaults to `.process`.
    /// - Returns: The model resource for this backend.
    /// - Throws: `IntegrationBackendError.missingCredential` if the Firebase project ID is
    ///   required but unavailable.
    package func modelResource(
      modelID: String = ModelResource.gemini35FlashLiteID,
      in environment: IntegrationTestEnvironment = .process
    ) throws -> ModelResource {
      switch self {
      case .developerAPI:
        return ModelResource(
          modelID: modelID,
          urlResourceName: "models/\(modelID)",
          payloadResourceName: "models/\(modelID)"
        )

      case .firebaseAILogicDeveloperAPI:
        let projectID = try resolveProjectID(in: environment)
        return ModelResource(
          modelID: modelID,
          urlResourceName: "projects/\(projectID)/models/\(modelID)",
          payloadResourceName: "models/\(modelID)"
        )

      case .firebaseAILogicAgentPlatform(let location):
        let projectID = try resolveProjectID(in: environment)
        let resourcePath =
          "projects/\(projectID)/locations/\(location)/publishers/google/models/\(modelID)"
        return ModelResource(
          modelID: modelID,
          urlResourceName: resourcePath,
          payloadResourceName: "models/\(modelID)"
        )
      }
    }

    /// Creates the header provider for this backend.
    ///
    /// - In `live` mode, the provider returns credential headers.
    /// - In `record` mode, the provider returns credential headers and the test-server
    ///   recording name header.
    /// - In `replay` mode, the provider returns only the recording name header; credentials are
    ///   neither required nor sent.
    ///
    /// - Parameters:
    ///   - recordingName: The test-server recording name, typically from
    ///     ``recordingName(fileID:function:)``. Ignored in `live` mode.
    ///   - authenticated: Whether to send credentials. Pass `false` to test unauthenticated
    ///     requests; only the recording name header is sent.
    ///   - environment: The test environment to evaluate. Defaults to `.process`.
    /// - Returns: A header provider, or `nil` if there are no headers to send.
    /// - Throws: `IntegrationBackendError.missingCredential` if required credentials are missing.
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    package func makeHeaderProvider(
      recordingName: String? = nil,
      authenticated: Bool = true,
      in environment: IntegrationTestEnvironment = .process
    ) throws -> (@Sendable () async throws -> [String: String])? {
      let mode = environment.integrationTestMode
      let recordingHeaders: [String: String] =
        if mode.usesTestServer, let recordingName {
          [TestServerConfiguration.recordingNameHeader: recordingName]
        } else {
          [:]
        }

      let sendsCredentials = authenticated && mode != .replay
      let credentialHeaderProvider =
        sendsCredentials ? try makeCredentialHeaderProvider(in: environment) : nil
      guard let credentialHeaderProvider else {
        guard !recordingHeaders.isEmpty else { return nil }
        return { @Sendable in recordingHeaders }
      }
      return {
        try await credentialHeaderProvider().merging(recordingHeaders) { current, _ in current }
      }
    }

    /// Creates a test-server recording name that is unique per test function and backend.
    ///
    /// For example, `#fileID` `"MyModuleTests/MySuiteTests.swift"` and `#function`
    /// `"myTest(backend:)"` produce `"MyModuleTests/MySuiteTests/myTest/developer-api"` for
    /// ``developerAPI``.
    ///
    /// - Parameters:
    ///   - fileID: The `#fileID` of the test file.
    ///   - function: The `#function` of the test function.
    /// - Returns: A relative, path-safe recording name.
    package func recordingName(fileID: String, function: String) -> String {
      let fileName = fileID.hasSuffix(".swift") ? String(fileID.dropLast(".swift".count)) : fileID
      let functionName = function.prefix { $0 != "(" }
      return "\(fileName)/\(functionName)/\(recordingSlug)"
    }

    /// A stable, path-safe identifier for this backend used in recording names.
    package var recordingSlug: String {
      switch self {
      case .developerAPI:
        return "developer-api"
      case .firebaseAILogicDeveloperAPI:
        return "firebase-ai-logic-developer-api"
      case .firebaseAILogicAgentPlatform(let location):
        return "firebase-ai-logic-agent-platform-\(location)"
      }
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    private func makeCredentialHeaderProvider(
      in environment: IntegrationTestEnvironment
    ) throws -> (@Sendable () async throws -> [String: String])? {
      switch self {
      case .developerAPI:
        if let apiKey = environment.geminiAPIKey {
          return { ["x-goog-api-key": apiKey] }
        }
        return nil

      case .firebaseAILogicDeveloperAPI, .firebaseAILogicAgentPlatform:
        let projectID = try resolveProjectID(in: environment)
        guard let appID = environment.firebaseAppID else {
          throw IntegrationBackendError.missingCredential("firebaseAppID")
        }
        guard let apiKey = environment.firebaseAPIKey else {
          throw IntegrationBackendError.missingCredential("firebaseAPIKey")
        }
        guard let debugToken = environment.appCheckDebugToken else {
          throw IntegrationBackendError.missingCredential("appCheckDebugToken")
        }
        return {
          let appCheckToken = try await AppCheckTokenCache.shared.token(
            projectID: projectID,
            appID: appID,
            apiKey: apiKey,
            debugToken: debugToken
          )
          return [
            "x-goog-api-key": apiKey,
            "x-firebase-appcheck": appCheckToken,
          ]
        }
      }
    }

    private func resolveProjectID(in environment: IntegrationTestEnvironment) throws -> String {
      if environment.integrationTestMode == .replay {
        return TestServerConfiguration.redactedPlaceholder
      }
      guard let projectID = environment.firebaseProjectID else {
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
