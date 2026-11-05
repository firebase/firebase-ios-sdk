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

/// Unit tests for `IntegrationTestingBackend` configuration, discovery, and credential resolution.
@Suite("IntegrationTestingBackend Tests")
struct IntegrationTestingBackendTests {
  @Test
  func developerAPIEndpoint() {
    let backend = IntegrationTestingBackend.developerAPI
    let config = backend.endpointConfiguration(in: IntegrationTestEnvironment(variables: [:]))

    #expect(config.apiVersion == EndpointConfiguration.geminiDeveloperAPIVersion)
    #expect(config == .geminiDeveloperAPI)
  }

  @Test
  func firebaseAILogicEndpoint() {
    let backend = IntegrationTestingBackend.firebaseAILogicDeveloperAPI
    let config = backend.endpointConfiguration(in: IntegrationTestEnvironment(variables: [:]))

    #expect(config.apiVersion == EndpointConfiguration.firebaseAILogicAPIVersion)
    #expect(config == .firebaseAILogic)
  }

  @Test
  func modelResourceFormats() throws {
    let dev = IntegrationTestingBackend.developerAPI
    #expect(try dev.modelResource(modelID: "test-model").urlResourceName == "models/test-model")

    let agentPlatform =
      IntegrationTestingBackend.firebaseAILogicAgentPlatform(location: "us-central1")
    if hasFirebaseAILogicCredentials {
      let resource = try agentPlatform.modelResource(modelID: "test-model")
      let expectedSubpath = "locations/us-central1/publishers/google/models/test-model"
      #expect(resource.urlResourceName.contains(expectedSubpath))
    }
  }

  @Test
  func integrationBackendErrorDescription() {
    let error = IntegrationBackendError.missingCredential("testField")
    #expect(error.errorDescription == "Missing required integration test credential: testField")
  }

  @Test
  func credentialsResolvedFromPlistPath() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempPlistURL = tempDir.appendingPathComponent(
      "Test-GoogleService-Info-\(UUID().uuidString).plist"
    )
    let plistDict: [String: Any] = [
      "PROJECT_ID": "test-plist-project",
      "GOOGLE_APP_ID": "test-plist-app",
      "API_KEY": "test-plist-api-key",
    ]
    let plistData = try PropertyListSerialization.data(
      fromPropertyList: plistDict,
      format: .xml,
      options: 0
    )
    try plistData.write(to: tempPlistURL)
    defer {
      try? FileManager.default.removeItem(at: tempPlistURL)
    }

    var env = IntegrationTestEnvironment(variables: [:])
    #expect(env.firebaseProjectID == nil)

    env.variables = ["FIREBASE_PLIST_PATH": tempPlistURL.path]
    #expect(env.firebaseProjectID == "test-plist-project")
    #expect(env.firebaseAppID == "test-plist-app")
    #expect(env.firebaseAPIKey == "test-plist-api-key")
    #expect(env.geminiAPIKey == nil)
  }

  @Test
  func plistPathStrictExclusivity() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempPlistURL = tempDir.appendingPathComponent(
      "Test-Incomplete-GoogleService-Info-\(UUID().uuidString).plist"
    )
    let plistDict: [String: Any] = [
      "API_KEY": "only-api-key"
    ]
    let plistData = try PropertyListSerialization.data(
      fromPropertyList: plistDict,
      format: .xml,
      options: 0
    )
    try plistData.write(to: tempPlistURL)
    defer {
      try? FileManager.default.removeItem(at: tempPlistURL)
    }

    let env = IntegrationTestEnvironment(variables: [
      "FIREBASE_PROJECT_ID": "env-project-id",
      "FIREBASE_PLIST_PATH": tempPlistURL.path,
    ])

    #expect(env.firebaseProjectID == nil)
    #expect(env.firebaseAPIKey == "only-api-key")
  }

  @Test
  func plistPathTreatsEmptyStringsAsNil() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let tempPlistURL = tempDir.appendingPathComponent(
      "Test-EmptyValues-GoogleService-Info-\(UUID().uuidString).plist"
    )
    let plistDict: [String: Any] = [
      "PROJECT_ID": "",
      "GOOGLE_APP_ID": "",
      "API_KEY": "",
    ]
    let plistData = try PropertyListSerialization.data(
      fromPropertyList: plistDict,
      format: .xml,
      options: 0
    )
    try plistData.write(to: tempPlistURL)
    defer {
      try? FileManager.default.removeItem(at: tempPlistURL)
    }

    let env = IntegrationTestEnvironment(variables: [
      "FIREBASE_PLIST_PATH": tempPlistURL.path
    ])

    #expect(env.firebaseProjectID == nil)
    #expect(env.firebaseAppID == nil)
    #expect(env.firebaseAPIKey == nil)
    #expect(env.geminiAPIKey == nil)
  }

  @Test
  func geminiAPIKeyResolution() {
    let emptyEnv = IntegrationTestEnvironment(variables: [:])
    #expect(emptyEnv.geminiAPIKey == nil)
    #expect(!emptyEnv.hasGeminiAPIKey)

    let geminiEnv = IntegrationTestEnvironment(variables: [
      "GEMINI_API_KEY": "test-gemini-key"
    ])
    #expect(geminiEnv.geminiAPIKey == "test-gemini-key")
    #expect(geminiEnv.hasGeminiAPIKey)

    let googleEnv = IntegrationTestEnvironment(variables: [
      "GOOGLE_API_KEY": "test-google-key",
      "GEMINI_API_KEY": "test-gemini-key",
    ])
    #expect(googleEnv.geminiAPIKey == "test-google-key")
    #expect(googleEnv.hasGeminiAPIKey)
  }

  @Test
  func processEnvironmentForwarders() {
    let processEnv = IntegrationTestEnvironment.process
    #expect(geminiAPIKey == processEnv.geminiAPIKey)
    #expect(hasGeminiAPIKey == processEnv.hasGeminiAPIKey)
    #expect(firebaseProjectID == processEnv.firebaseProjectID)
    #expect(firebaseAppID == processEnv.firebaseAppID)
    #expect(firebaseAPIKey == processEnv.firebaseAPIKey)
    #expect(appCheckDebugToken == processEnv.appCheckDebugToken)
    #expect(hasFirebaseAILogicCredentials == processEnv.hasFirebaseAILogicCredentials)
    #expect(
      IntegrationTestingBackend.developerAPI.isAvailable
        == IntegrationTestingBackend.developerAPI.isAvailable(in: processEnv)
    )
  }

  // MARK: - Integration Test Modes

  @Test
  func integrationTestModeDefaultsToLive() {
    let environment = IntegrationTestEnvironment(variables: [:])

    let mode = environment.integrationTestMode

    #expect(mode == .live)
  }

  @Test(arguments: [
    ("live", IntegrationTestMode.live),
    ("record", .record),
    ("REPLAY", .replay),
  ])
  func integrationTestModeParsing(value: String, expectedMode: IntegrationTestMode) {
    let environment = IntegrationTestEnvironment(variables: [
      IntegrationTestMode.environmentVariable: value
    ])

    let mode = environment.integrationTestMode

    #expect(mode == expectedMode)
  }

  @Test
  func replayModeMakesBackendsAvailableWithoutCredentials() {
    let environment = IntegrationTestEnvironment(variables: [
      IntegrationTestMode.environmentVariable: "replay"
    ])

    let availability = IntegrationTestingBackend.allCases.map { $0.isAvailable(in: environment) }

    #expect(availability.allSatisfy { $0 })
  }

  @Test
  func recordModeRequiresCredentials() {
    let environment = IntegrationTestEnvironment(variables: [
      IntegrationTestMode.environmentVariable: "record"
    ])

    let availability = IntegrationTestingBackend.allCases.map { $0.isAvailable(in: environment) }

    #expect(availability.allSatisfy { !$0 })
  }

  @Test(arguments: [IntegrationTestMode.record, .replay])
  func testServerModesUseLocalEndpoints(mode: IntegrationTestMode) {
    let environment = IntegrationTestEnvironment(variables: [
      IntegrationTestMode.environmentVariable: mode.rawValue
    ])

    let developerAPIConfig =
      IntegrationTestingBackend.developerAPI.endpointConfiguration(in: environment)
    let firebaseConfig =
      IntegrationTestingBackend.firebaseAILogicAgentPlatform(location: "global")
      .endpointConfiguration(in: environment)

    #expect(
      developerAPIConfig
        == EndpointConfiguration(
          scheme: "http",
          host: "localhost",
          port: TestServerConfiguration.developerAPIPort,
          apiVersion: EndpointConfiguration.geminiDeveloperAPIVersion
        )
    )
    #expect(
      firebaseConfig
        == EndpointConfiguration(
          scheme: "http",
          host: "localhost",
          port: TestServerConfiguration.firebaseAILogicPort,
          apiVersion: EndpointConfiguration.firebaseAILogicAPIVersion
        )
    )
  }

  @Test
  func replayModeUsesRedactedProjectID() throws {
    let environment = IntegrationTestEnvironment(variables: [
      IntegrationTestMode.environmentVariable: "replay"
    ])
    let backend = IntegrationTestingBackend.firebaseAILogicDeveloperAPI

    let resource = try backend.modelResource(modelID: "test-model", in: environment)

    #expect(resource.urlResourceName == "projects/REDACTED/models/test-model")
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func replayHeaderProviderSendsOnlyRecordingName() async throws {
    let environment = IntegrationTestEnvironment(variables: [
      IntegrationTestMode.environmentVariable: "replay"
    ])
    let backend = IntegrationTestingBackend.firebaseAILogicAgentPlatform(location: "global")

    let headerProvider = try #require(
      try backend.makeHeaderProvider(recordingName: "Suite/test/backend", in: environment)
    )
    let headers = try await headerProvider()

    #expect(headers == ["Test-Name": "Suite/test/backend"])
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func recordHeaderProviderSendsCredentialsAndRecordingName() async throws {
    let environment = IntegrationTestEnvironment(variables: [
      IntegrationTestMode.environmentVariable: "record",
      "GEMINI_API_KEY": "test-gemini-key",
    ])
    let backend = IntegrationTestingBackend.developerAPI

    let headerProvider = try #require(
      try backend.makeHeaderProvider(recordingName: "Suite/test/backend", in: environment)
    )
    let headers = try await headerProvider()

    #expect(headers == ["x-goog-api-key": "test-gemini-key", "Test-Name": "Suite/test/backend"])
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func liveHeaderProviderOmitsRecordingName() async throws {
    let environment = IntegrationTestEnvironment(variables: [
      "GEMINI_API_KEY": "test-gemini-key"
    ])
    let backend = IntegrationTestingBackend.developerAPI

    let headerProvider = try #require(
      try backend.makeHeaderProvider(recordingName: "Suite/test/backend", in: environment)
    )
    let headers = try await headerProvider()

    #expect(headers == ["x-goog-api-key": "test-gemini-key"])
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func unauthenticatedHeaderProviderSendsOnlyRecordingName() async throws {
    let environment = IntegrationTestEnvironment(variables: [
      IntegrationTestMode.environmentVariable: "record",
      "GEMINI_API_KEY": "test-gemini-key",
    ])
    let backend = IntegrationTestingBackend.developerAPI

    let headerProvider = try #require(
      try backend.makeHeaderProvider(
        recordingName: "Suite/test/backend",
        authenticated: false,
        in: environment
      )
    )
    let headers = try await headerProvider()

    #expect(headers == ["Test-Name": "Suite/test/backend"])
  }

  @Test
  func recordingNameIncludesFileFunctionAndBackend() {
    let backend = IntegrationTestingBackend.firebaseAILogicAgentPlatform(location: "us-central1")

    let name = backend.recordingName(
      fileID: "MyModuleTests/MySuiteTests.swift",
      function: "myTest(backend:)"
    )

    #expect(
      name == "MyModuleTests/MySuiteTests/myTest/firebase-ai-logic-agent-platform-us-central1"
    )
  }
}
