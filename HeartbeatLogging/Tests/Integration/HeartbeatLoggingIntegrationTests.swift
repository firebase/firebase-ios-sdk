// Copyright 2021 Google LLC
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

import XCTest
@testable import HeartbeatLogging

class HeartbeatLoggingIntegrationTests: XCTestCase {
  override func setUpWithError() throws {
    try removeUnderlyingHeartbeatStorageContainers()
  }

  override func tearDownWithError() throws {
    try removeUnderlyingHeartbeatStorageContainers()
  }

  // MARK: - Public API Only

  func testInitWithPublicAPI_LogAndFlush() throws {
    // Given
    let heartbeatController = HeartbeatController(id: #file)
    // When
    heartbeatController.log("dummy_agent")
    // Then
    let payload = heartbeatController.flush()
    // The `HeartbeatController` should have recorded the current date.
    let dateString = HeartbeatsPayload.dateFormatter.string(from: Date())
    try assertEqualPayloadStrings(
      payload.headerValue(),
      """
      {
        "version": 2,
        "heartbeats": [
          { "agent": "dummy_agent", "dates": ["\(dateString)"] }
        ]
      }
      """
    )
  }

  // MARK: - Stress Tests

  // TODO: Add stress tests
}

/// <#Description#>
/// - Throws: <#description#>
private func removeUnderlyingHeartbeatStorageContainers() throws {
  #if os(tvOS)
    UserDefaults.standard
      .removePersistentDomain(forName: kHeartbeatUserDefaultsSuiteName)
  #else
    let heartbeatsDirectoryURL = FileManager.default
      .applicationSupportDirectory
      .appendingPathComponent(
        kHeartbeatFileStorageDirectoryPath, isDirectory: true
      )

    do {
      try FileManager.default.removeItem(at: heartbeatsDirectoryURL)
    } catch CocoaError.fileNoSuchFile {
      // Do nothing.
    }
  #endif // os(tvOS)
}
