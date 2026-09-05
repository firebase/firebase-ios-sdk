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

@Suite("IntegrationTestingBackend Tests")
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
}
