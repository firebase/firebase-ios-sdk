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

class SessionStartEventTests: XCTestCase {
  var identifiers: MockIdentifierProvider!
  var time: MockTimeProvider!

  override func setUp() {
    super.setUp()

    identifiers = MockIdentifierProvider()
    time = MockTimeProvider()
  }

  func test_init_setsSessionIDs() {
    identifiers.mockAllValidIDs()

    let event = SessionStartEvent(identifiers: identifiers, time: time)
    assertEqualProtoString(
      event.proto.session_data.session_id,
      expected: MockIdentifierProvider.testSessionID,
      fieldName: "session_id"
    )
    assertEqualProtoString(
      event.proto.session_data.previous_session_id,
      expected: MockIdentifierProvider.testPreviousSessionID,
      fieldName: "previous_session_id"
    )

    XCTAssertEqual(event.proto.session_data.event_timestamp_us, 123)
  }

  func test_setInstallationID_setsInstallationID() {
    identifiers.mockAllValidIDs()

    let event = SessionStartEvent(identifiers: identifiers, time: time)
    event.setInstallationID(identifiers: identifiers)
    assertEqualProtoString(
      event.proto.session_data.firebase_installation_id,
      expected: MockIdentifierProvider.testInstallationID,
      fieldName: "firebase_installation_id"
    )
  }
}
