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
  func test_beginListening_initiatesColdStart() throws {
    let initiator = SessionInitiator()
    var initiateCalled = false
    initiator.beginListening {
      initiateCalled = true
    }
    assert(initiateCalled)
  }
  
  func testForegounding_initiatesNewSession() throws {
    let pausedClock = ShadowDate()
    let initiator = SessionInitiator(now: pausedClock.getDate)
    var sessionCount = 0
    initiator.beginListening {
      sessionCount += 1
    }
    assert(sessionCount == 1)
    
    // Simulate 30 minutes + 1 second of backgrounding, > session timeout
    initiator.appBackgrounded()
    pausedClock.advance(by: 60 * 30 + 1)
    initiator.appForegrounded()
    // A new session is created, so count increases
    assert(sessionCount == 2)
    
    // Simulate only 30 minutes of backgrounding, <= session timeout
    initiator.appBackgrounded()
    pausedClock.advance(by: 60 * 30)
    initiator.appForegrounded()
    // A new session isn't created, so count doesn't increase
    assert(sessionCount == 2)
  }
}
