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

class InitiatorTests: XCTestCase {
  // 2021-11-01 @ 00:00:00 (EST)
  let date = Date(timeIntervalSince1970: 1_635_739_200)

  func test_beginListening_initiatesColdStart() throws {
    let initiator = SessionInitiator()
    var initiateCalled = false
    initiator.beginListening {
      initiateCalled = true
    }
    assert(initiateCalled)
  }

  func testForegounding_initiatesNewSession() throws {
    // Given
    var pausedClock = date
    let initiator = SessionInitiator(dateProvider: { pausedClock })
    var sessionCount = 0
    initiator.beginListening {
      sessionCount += 1
    }
    assert(sessionCount == 1)

    // When
    // Background, advance time by 30 minutes + 1 second, then foreground
    initiator.appBackgrounded()
    pausedClock.addTimeInterval(30 * 60 + 1)
    initiator.appForegrounded()
    // Then
    // Session count increases because time spent in background > 30 minutes
    assert(sessionCount == 2)

    // When
    // Background, advance time by exactly 30 minutes, then foreground
    initiator.appBackgrounded()
    pausedClock.addTimeInterval(30 * 60)
    initiator.appForegrounded()
    // Then
    // Session count doesn't increase because time spent in background <= 30 minutes
    assert(sessionCount == 2)
  }
}
