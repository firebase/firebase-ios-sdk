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

#if canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#endif

/// Unit tests for `IntegrationTestingBackend` configuration, discovery, and credential resolution.
@Suite("IntegrationTestingBackend Tests", .serialized)
struct IntegrationTestingBackendTests {
  @Test
  func developerAPIEndpoint() {
    let backend = IntegrationTestingBackend.developerAPI
    let config = backend.endpointConfiguration

    #expect(config.apiVersion == EndpointConfiguration.geminiDeveloperAPIVersion)
    if isTestServerRunning(port: defaultTestServerPort) {
      #expect(config.scheme == "http")
      #expect(config.host == "localhost")
      #expect(config.port == defaultTestServerPort)
    } else {
      #expect(config == .geminiDeveloperAPI)
    }
  }

  @Test
  func firebaseAILogicEndpoint() {
    let backend = IntegrationTestingBackend.firebaseAILogicDeveloperAPI
    let config = backend.endpointConfiguration

    #expect(config.apiVersion == EndpointConfiguration.firebaseAILogicAPIVersion)
    if isTestServerRunning(port: defaultTestServerFirebasePort) {
      #expect(config.scheme == "http")
      #expect(config.host == "localhost")
      #expect(config.port == defaultTestServerFirebasePort)
    } else {
      #expect(config == .firebaseAILogic)
    }
  }

  @Test
  func modelResourceFormats() throws {
    let dev = IntegrationTestingBackend.developerAPI
    #expect(try dev.modelResource(modelID: "test-model").urlResourceName == "models/test-model")

    let agentPlatform =
      IntegrationTestingBackend.firebaseAILogicAgentPlatform(location: "us-central1")
    if hasFirebaseAILogicCredentials || isTestServerRunning(port: defaultTestServerFirebasePort) {
      let resource = try agentPlatform.modelResource(modelID: "test-model")
      let expectedSubpath = "locations/us-central1/publishers/google/models/test-model"
      #expect(resource.urlResourceName.contains(expectedSubpath))
    }
  }

  @Test
  func probePortReturnsFalseForUnusedPort() {
    let isRunning = isTestServerRunning(port: 59999)

    #expect(!isRunning)
  }

  @Test
  func cacheResetClearsCachedProbeResults() {
    let firstProbe = isTestServerRunning(port: 59998)
    resetTestServerStatusCache()
    let secondProbe = isTestServerRunning(port: 59998)

    #expect(!firstProbe)
    #expect(!secondProbe)
  }

  @Test
  func defaultPorts() {
    #expect(defaultTestServerPort > 0)
    #expect(defaultTestServerFirebasePort > 0)
  }

  @Test
  func credentialsResolvedFromPlistPath() throws {
    let env = ProcessInfo.processInfo.environment
    let previousPlistPath = env["FIREBASE_PLIST_PATH"]
    let previousGoogleKey = env["GOOGLE_API_KEY"]
    let previousGeminiKey = env["GEMINI_API_KEY"]
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
      if let previousPlistPath {
        setenv("FIREBASE_PLIST_PATH", previousPlistPath, 1)
      } else {
        unsetenv("FIREBASE_PLIST_PATH")
      }
      if let previousGoogleKey {
        setenv("GOOGLE_API_KEY", previousGoogleKey, 1)
      } else {
        unsetenv("GOOGLE_API_KEY")
      }
      if let previousGeminiKey {
        setenv("GEMINI_API_KEY", previousGeminiKey, 1)
      } else {
        unsetenv("GEMINI_API_KEY")
      }
    }

    unsetenv("GOOGLE_API_KEY")
    unsetenv("GEMINI_API_KEY")
    setenv("FIREBASE_PLIST_PATH", tempPlistURL.path, 1)

    #expect(firebaseProjectID == "test-plist-project")
    #expect(firebaseAppID == "test-plist-app")
    #expect(firebaseAPIKey == "test-plist-api-key")
    #expect(geminiAPIKey == nil)
  }

  @Test
  func plistPathStrictExclusivity() throws {
    let previousPlistPath = ProcessInfo.processInfo.environment["FIREBASE_PLIST_PATH"]
    let previousProjectID = ProcessInfo.processInfo.environment["FIREBASE_PROJECT_ID"]
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
      if let previousPlistPath {
        setenv("FIREBASE_PLIST_PATH", previousPlistPath, 1)
      } else {
        unsetenv("FIREBASE_PLIST_PATH")
      }
      if let previousProjectID {
        setenv("FIREBASE_PROJECT_ID", previousProjectID, 1)
      } else {
        unsetenv("FIREBASE_PROJECT_ID")
      }
    }

    setenv("FIREBASE_PROJECT_ID", "env-project-id", 1)
    setenv("FIREBASE_PLIST_PATH", tempPlistURL.path, 1)

    #expect(firebaseProjectID == nil)
    #expect(firebaseAPIKey == "only-api-key")
  }

  @Test
  func plistPathTreatsEmptyStringsAsNil() throws {
    let env = ProcessInfo.processInfo.environment
    let previousPlistPath = env["FIREBASE_PLIST_PATH"]
    let previousGoogleKey = env["GOOGLE_API_KEY"]
    let previousGeminiKey = env["GEMINI_API_KEY"]
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
      if let previousPlistPath {
        setenv("FIREBASE_PLIST_PATH", previousPlistPath, 1)
      } else {
        unsetenv("FIREBASE_PLIST_PATH")
      }
      if let previousGoogleKey {
        setenv("GOOGLE_API_KEY", previousGoogleKey, 1)
      } else {
        unsetenv("GOOGLE_API_KEY")
      }
      if let previousGeminiKey {
        setenv("GEMINI_API_KEY", previousGeminiKey, 1)
      } else {
        unsetenv("GEMINI_API_KEY")
      }
    }

    unsetenv("GOOGLE_API_KEY")
    unsetenv("GEMINI_API_KEY")
    setenv("FIREBASE_PLIST_PATH", tempPlistURL.path, 1)

    #expect(firebaseProjectID == nil)
    #expect(firebaseAppID == nil)
    #expect(firebaseAPIKey == nil)
    #expect(geminiAPIKey == nil)
  }

  @Test
  func geminiAPIKeyResolution() {
    let env = ProcessInfo.processInfo.environment
    let previousGoogleKey = env["GOOGLE_API_KEY"]
    let previousGeminiKey = env["GEMINI_API_KEY"]
    defer {
      if let previousGoogleKey {
        setenv("GOOGLE_API_KEY", previousGoogleKey, 1)
      } else {
        unsetenv("GOOGLE_API_KEY")
      }
      if let previousGeminiKey {
        setenv("GEMINI_API_KEY", previousGeminiKey, 1)
      } else {
        unsetenv("GEMINI_API_KEY")
      }
    }

    unsetenv("GOOGLE_API_KEY")
    unsetenv("GEMINI_API_KEY")
    #expect(geminiAPIKey == nil)
    #expect(!hasGeminiAPIKey)

    setenv("GEMINI_API_KEY", "test-gemini-key", 1)
    #expect(geminiAPIKey == "test-gemini-key")
    #expect(hasGeminiAPIKey)

    setenv("GOOGLE_API_KEY", "test-google-key", 1)
    #expect(geminiAPIKey == "test-google-key")
    #expect(hasGeminiAPIKey)
  }

  @Test
  func testServerRecordingModeDetection() {
    let env = ProcessInfo.processInfo.environment
    let prevMode = env["TEST_SERVER_MODE"]
    let prevRunnerMode = env["TEST_RUNNER_TEST_SERVER_MODE"]
    defer {
      if let prevMode {
        setenv("TEST_SERVER_MODE", prevMode, 1)
      } else {
        unsetenv("TEST_SERVER_MODE")
      }
      if let prevRunnerMode {
        setenv("TEST_RUNNER_TEST_SERVER_MODE", prevRunnerMode, 1)
      } else {
        unsetenv("TEST_RUNNER_TEST_SERVER_MODE")
      }
    }

    unsetenv("TEST_SERVER_MODE")
    unsetenv("TEST_RUNNER_TEST_SERVER_MODE")
    #expect(!isTestServerRecording)

    setenv("TEST_SERVER_MODE", "record", 1)
    #expect(isTestServerRecording)

    setenv("TEST_SERVER_MODE", "RECORD", 1)
    #expect(isTestServerRecording)

    setenv("TEST_SERVER_MODE", "replay", 1)
    #expect(!isTestServerRecording)

    unsetenv("TEST_SERVER_MODE")
    setenv("TEST_RUNNER_TEST_SERVER_MODE", "record", 1)
    #expect(isTestServerRecording)
  }

  @Test
  func isAvailableRequiresCredentialsInRecordMode() {
    let env = ProcessInfo.processInfo.environment
    let prevMode = env["TEST_SERVER_MODE"]
    let prevGoogleKey = env["GOOGLE_API_KEY"]
    let prevGeminiKey = env["GEMINI_API_KEY"]
    defer {
      if let prevMode {
        setenv("TEST_SERVER_MODE", prevMode, 1)
      } else {
        unsetenv("TEST_SERVER_MODE")
      }
      if let prevGoogleKey {
        setenv("GOOGLE_API_KEY", prevGoogleKey, 1)
      } else {
        unsetenv("GOOGLE_API_KEY")
      }
      if let prevGeminiKey {
        setenv("GEMINI_API_KEY", prevGeminiKey, 1)
      } else {
        unsetenv("GEMINI_API_KEY")
      }
    }

    setenv("TEST_SERVER_MODE", "record", 1)
    unsetenv("GOOGLE_API_KEY")
    unsetenv("GEMINI_API_KEY")

    #expect(!IntegrationTestingBackend.developerAPI.isAvailable)

    setenv("GEMINI_API_KEY", "test-key", 1)
    #expect(IntegrationTestingBackend.developerAPI.isAvailable)
  }
}
