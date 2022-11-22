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

class SessionSamplerTests: XCTestCase {

  /// Validates if the default sampling rate is to allow all events.
  func test_DefaultSamplingRate() {
    let localSampler = SessionSampler()
    XCTAssertEqual(localSampler.sessionSamplingRate, 1.0)
  }

  /// Validates if the events are disabled when the sampling rate is Zero.
  func test_DisablesEventCollection_samplingRateZero() {
    let localSampler = SessionSampler(sessionSamplingRate: 0.0)
    XCTAssertEqual(localSampler.shouldSendEventForSession(sessionId: "random"), false)
    XCTAssertEqual(localSampler.shouldSendEventForSession(sessionId: "anyEvent"), false)
  }

  /// Validates if the events are allowed when the sampling rate is One.
  func test_AllowsEventCollection_samplingRateOne() {
    let localSampler = SessionSampler(sessionSamplingRate: 1.0)
    XCTAssertEqual(localSampler.shouldSendEventForSession(sessionId: "random"), true)
    XCTAssertEqual(localSampler.shouldSendEventForSession(sessionId: "anyEvent"), true)
  }
}
