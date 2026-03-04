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

import FirebaseCore
import Foundation
@testable import GeneratedFirebaseAI
@testable import TestServer
import XCTest

class FirebaseE2ETestBase: XCTestCase {
  nonisolated(unsafe) static var testServer: TestServer?

  var client: APIClient!
  var projectID: String!
  var apiKey: String!

  private class func localBinPath() -> String {
    return FileManager.default.temporaryDirectory
      .appendingPathComponent("test-server-bin/test-server").path
  }

  override class func setUp() {
    super.setUp()

    let currentFileURL = URL(fileURLWithPath: #file)
    let sdkRoot = currentFileURL.deletingLastPathComponent().deletingLastPathComponent().path

    let options = TestServerOptions(
      configPath: "\(sdkRoot)/Tests/test-server.yml",
      recordingDir: "\(sdkRoot)/Tests/Recordings",
      mode: ProcessInfo.processInfo.environment["TEST_MODE"] ?? "replay",
      binaryPath: localBinPath(),
      testServerSecrets: nil
    )
    testServer = TestServer(options: options)
  }

  override class func tearDown() {
    testServer?.stop()
    testServer = nil
    super.tearDown()
  }

  override func setUp() async throws {
    try await super.setUp()

    try await Self.testServer?.start()

    // Configure naming for the recording file
    let rawName = name
    let cleanName = rawName.trimmingCharacters(in: CharacterSet(charactersIn: "-[]"))
      .replacingOccurrences(of: " ", with: ".")
    TestServerURLProtocol.currentTestName = cleanName

    // Setup Credentials
    projectID = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT"] ?? "test-project"
    apiKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] ?? "test-api-key"

    // Initialize Client
    let sessionConfig = URLSessionConfiguration.ephemeral
    sessionConfig.protocolClasses = [TestServerURLProtocol.self]
    let proxySession = URLSession(configuration: sessionConfig)

    let firebaseApp = FirebaseFake.create(apiKey: apiKey, projectID: projectID)
    client = APIClient(
      backend: .vertexAI(location: "us-central1", projectId: projectID, version: .v1beta),
      authentication: .firebase(app: firebaseApp),
      urlSession: proxySession
    )
  }
}
