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

// TODO: Add additional validation (#8896 comments).

class HeartbeatControllerTests: XCTestCase {
  func testFlushWhenEmpty() throws {
    // Given
    let controller = HeartbeatController(storage: HeartbeatStorageFake())
    // When
    let flushed = controller.flush()
    // Then
    XCTAssertNil(flushed)
  }

  func testLogThenFlush() throws {
    // Given
    let controller = HeartbeatController(storage: HeartbeatStorageFake())
    XCTAssertNil(controller.flush())
    // When
    controller.log(#function)
    // Then
    XCTAssertNotNil(controller.flush())
    XCTAssertNil(controller.flush())
  }
}

// MARK: - Fakes

private extension HeartbeatControllerTests {
  class HeartbeatStorageFake: HeartbeatStorageProtocol {
    private var heartbeatInfo: HeartbeatInfo?

    func offer(_ heartbeat: Heartbeat) {
      heartbeatInfo = HeartbeatInfo(capacity: 1)
      heartbeatInfo!.offer(heartbeat)
    }

    func flush() -> HeartbeatInfo? {
      let flushed = heartbeatInfo
      heartbeatInfo = nil
      return flushed
    }
  }
}
