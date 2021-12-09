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

class RingBufferTests: XCTestCase {
  // `RingBuffer` is a generic type. `String` is used for simplified testing.
  typealias Element = String

  func testPush_WhenCapacityIsZero_DoesNothing() throws {
    // Given
    var ringBuffer = RingBuffer<Element>(capacity: 0)
    // When
    ringBuffer.push("ezra")
    // Then
    XCTAssertFalse(ringBuffer.contains("ezra"))
  }

  func testPush_WhenUnderFullCapacity_OverwritesAndReturnsTailElement() throws {
    // Given
    var ringBuffer = RingBuffer<Element>(capacity: 3) // [nil, nil, nil]
    // When
    let overwrittenElement = ringBuffer.push("vader") // ["vader", nil, nil]
    // Then
    XCTAssertNil(overwrittenElement)
  }

  func testPush_WhenAtFullCapacity_OverwritesAndReturnsTailElement() throws {
    // Given
    var ringBuffer = RingBuffer<Element>(capacity: 1) // [nil]
    ringBuffer.push("luke") // ["luke"] where "luke" is the tail element.
    // When
    let overwrittenElement = ringBuffer.push("vader")
    // Then
    XCTAssertEqual(overwrittenElement, "luke")
    XCTAssertTrue(
      ringBuffer.elementsEqual(["vader"]),
      "Ring buffer's elements are not equal to given elements."
    )
  }

  func testPush_WhenAtFullCapacity_FollowsFIFO_Ordering() throws {
    // Given
    var ringBuffer = RingBuffer<Element>(capacity: 3) // [nil, nil, nil]
    // When
    ringBuffer.push("chewy") // ["chewy", nil, nil]
    ringBuffer.push("vader") // ["chewy", "vader", nil]
    ringBuffer.push("jabba") // ["chewy", "vader", "jabba"]
    ringBuffer.push("lando") // ["lando", "vader", "jabba"]
    // Then
    XCTAssertTrue(
      ringBuffer.elementsEqual(["lando", "vader", "jabba"]),
      "Ring buffer's elements are not equal to given elements."
    )
  }

  func testPushFollowsFIFO_Ordering() throws {
    // Given
    var ringBuffer = RingBuffer<Element>(capacity: 10)
    // When
    ringBuffer.push("han solo")
    ringBuffer.push("boba")
    ringBuffer.push("jabba")
    // Then
    XCTAssertTrue(
      ringBuffer.elementsEqual(["han solo", "boba", "jabba"]),
      "Ring buffer's elements are not equal to given elements."
    )
  }

  func testPushStressTest() throws {
    // Given
    var ringBuffer = RingBuffer<Int>(capacity: 10)
    // When
    for index in 1 ... 1000 {
      ringBuffer.push(index)
    }
    // Then
    XCTAssertTrue(
      ringBuffer.elementsEqual(Array(991 ... 1000)),
      "Ring buffer's elements are not equal to given elements."
    )
  }
}
