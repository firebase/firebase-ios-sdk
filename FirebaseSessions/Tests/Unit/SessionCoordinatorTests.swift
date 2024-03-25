//
// Copyright 2022 Google LLC
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

@testable import FirebaseSessions

class SessionCoordinatorTests: XCTestCase {
  var installations = MockInstallationsProtocol()
  var time = MockTimeProvider()
  var fireLogger = MockGDTLogger()
  var appInfo = MockApplicationInfo()

  var coordinator: SessionCoordinator!

  override func setUp() {
    super.setUp()

    coordinator = SessionCoordinator(
      installations: installations,
      fireLogger: fireLogger
    )
  }

  override func tearDown() {
    installations.authTokenFinished = false
    installations.installationIdFinished = false
  }

  var defaultSessionInfo: SessionInfo {
    return SessionInfo(
      sessionId: "test_session_id",
      firstSessionId: "test_first_session_id",
      dispatchEvents: true,
      sessionIndex: 0
    )
  }

  func test_attemptLoggingSessionStart_logsToGDT() throws {
    let event = SessionStartEvent(sessionInfo: defaultSessionInfo, appInfo: appInfo, time: time)
    var resultSuccess = false
    coordinator.attemptLoggingSessionStart(event: event) { result in
      switch result {
      case .success(()):
        resultSuccess = true
      case .failure:
        resultSuccess = false
      }
    }
    // Make sure we've set the Installation ID
    assertEqualProtoString(
      event.proto.session_data.firebase_installation_id,
      expected: MockInstallationsProtocol.testInstallationId,
      fieldName: "installation_id"
    )

    XCTAssertTrue(installations.authTokenFinished)
    XCTAssertTrue(installations.installationIdFinished)

    // We should have logged successfully
    XCTAssertEqual(fireLogger.loggedEvent, event)
    XCTAssert(resultSuccess)
  }

  func test_attemptLoggingSessionStart_handlesGDTError() throws {
    fireLogger.result = .failure(NSError(domain: "TestError", code: -1))

    let event = SessionStartEvent(sessionInfo: defaultSessionInfo, appInfo: appInfo, time: time)

    // Start success so it must be set to false
    var resultSuccess = true
    coordinator.attemptLoggingSessionStart(event: event) { result in
      switch result {
      case .success(()):
        resultSuccess = true
      case .failure:
        resultSuccess = false
      }
    }

    XCTAssertTrue(installations.authTokenFinished)
    XCTAssertTrue(installations.installationIdFinished)

    // Make sure we've set the Installation ID
    assertEqualProtoString(
      event.proto.session_data.firebase_installation_id,
      expected: MockInstallationsProtocol.testInstallationId,
      fieldName: "installation_id"
    )

    // We should have logged the event, but with a failed result
    XCTAssertEqual(fireLogger.loggedEvent, event)
    XCTAssertFalse(resultSuccess)
  }

  func test_attemptLoggingSessionStart_handlesInstallationsError() throws {
    installations.result = .failure(NSError(domain: "TestInstallationsError", code: -1))

    let event = SessionStartEvent(sessionInfo: defaultSessionInfo, appInfo: appInfo, time: time)

    // Start success so it must be set to false
    var resultSuccess = true
    coordinator.attemptLoggingSessionStart(event: event) { result in
      switch result {
      case .success(()):
        resultSuccess = true
      case .failure:
        resultSuccess = false
      }
    }

    XCTAssertTrue(installations.authTokenFinished)
    XCTAssertTrue(installations.installationIdFinished)
    // We should have logged the event, but with a failed result
    XCTAssertNotNil(fireLogger.loggedEvent)
    XCTAssertFalse(resultSuccess)
  }

  func test_attemptLoggingSessionStart_handlesGDTAndInstallationsError() throws {
    let fireLogError = NSError(domain: "DataTransportError", code: -2)
    fireLogger.result = .failure(fireLogError)
    installations
      .result = .failure(FirebaseSessionsError
        .SessionInstallationsError(NSError(domain: "TestInstallationsError", code: -1)))

    let event = SessionStartEvent(sessionInfo: defaultSessionInfo, appInfo: appInfo, time: time)

    // Start success so it must be set to false
    var resultSuccess = true
    coordinator.attemptLoggingSessionStart(event: event) { result in
      switch result {
      case .success(()):
        resultSuccess = true
      case let .failure(err):
        resultSuccess = false
        // Result should use the FireLog error if there's an error in both
        // Installations and FireLog
        XCTAssertEqual(err, FirebaseSessionsError.DataTransportError(fireLogError))
      }
    }

    XCTAssertTrue(installations.authTokenFinished)
    XCTAssertTrue(installations.installationIdFinished)

    // Make sure we've set the Installation ID to empty because the FIID
    // fetch failed
    assertEqualProtoString(
      event.proto.session_data.firebase_installation_id,
      expected: "",
      fieldName: "installation_id"
    )

    // We should have logged the event, but with a failed result
    XCTAssertEqual(fireLogger.loggedEvent, event)
    XCTAssertFalse(resultSuccess)
  }
}
