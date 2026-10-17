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

import XCTest

@testable import FirebaseSessions

final class TimeTests: XCTestCase {
  func test_timestampUS_keepsFractionalSeconds() {
    // Use fractions that are exactly representable as a `Double` so the expected values are exact.
    let early = Time(currentTimeProvider: { Date(timeIntervalSince1970: 1_700_000_000.25) })
    let late = Time(currentTimeProvider: { Date(timeIntervalSince1970: 1_700_000_000.75) })

    XCTAssertEqual(early.timestampUS, 1_700_000_000_250_000)
    XCTAssertEqual(late.timestampUS, 1_700_000_000_750_000)
  }

  func test_timestampUS_beforeUnixEpoch_isNegative() {
    let time = Time(currentTimeProvider: { Date(timeIntervalSince1970: -1.5) })

    XCTAssertEqual(time.timestampUS, -1_500_000)
  }
}
