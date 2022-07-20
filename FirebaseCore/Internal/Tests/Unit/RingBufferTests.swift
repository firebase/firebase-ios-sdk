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
@testable import FirebaseCoreInternal

class RingBufferTests: XCTestCase {
  // `RingBuffer` is a generic type. `String` is used for simplified testing.
  typealias Element = String

  func testPush_WhenCapacityIsZero_DoesNothing() throws {
    // Given
    var ringBuffer = RingBuffer<Element>(capacity: 0)
    // When
    ringBuffer.push("ezra")
    // Then
    XCTAssertEqual(Array(ringBuffer), [])
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
    XCTAssertEqual(Array(ringBuffer), ["vader"])
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
    XCTAssertEqual(Array(ringBuffer), ["lando", "vader", "jabba"])
  }

  func testPushFollowsFIFO_Ordering() throws {
    // Given
    var ringBuffer = RingBuffer<Element>(capacity: 10)
    // When
    ringBuffer.push("han solo")
    ringBuffer.push("boba")
    ringBuffer.push("jabba")
    // Then
    XCTAssertEqual(Array(ringBuffer), ["han solo", "boba", "jabba"])
  }

  func testPushStressTest() throws {
    // Given
    var ringBuffer = RingBuffer<Int>(capacity: 10)
    // When
    for index in 1 ... 1000 {
      ringBuffer.push(index)
    }
    // Then
    XCTAssertEqual(Array(ringBuffer), Array(991 ... 1000))
  }

  func testPopBeforePushing() throws {
    // Given
    var ringBuffer = RingBuffer<Element>(capacity: 2) // [`tailIndex` -> nil, nil]
    // When
    ringBuffer.pop() // [nil, `tailIndex` -> nil]
    ringBuffer.push("yoda") // [nil, "yoda"]
    ringBuffer.push("mando") // ["mando", "yoda"]
    // Then
    XCTAssertEqual(Array(ringBuffer), ["mando", "yoda"])
  }

  func testPopStressTest() throws {
    // Given
    var ringBuffer = RingBuffer<Int>(capacity: 10)
    // When
    for _ in 1 ... 1000 {
      XCTAssertNil(ringBuffer.pop())
    }
    // Then
    XCTAssertEqual(Array(ringBuffer), [])
  }

  func testPop_WhenCapacityIsZero_DoesNothingAndReturnsNil() throws {
    // Given
    var ringBuffer = RingBuffer<String>(capacity: 0)
    // When
    let popped = ringBuffer.pop()
    // Then
    XCTAssertNil(popped)
    XCTAssertEqual(Array(ringBuffer), [])
  }

  func testPopRemovesAndReturnsLastElement() throws {
    // Given
    var ringBuffer = RingBuffer<Element>(capacity: 3)
    ringBuffer.push("one")
    ringBuffer.push("two")
    ringBuffer.push("three")
    // When
    XCTAssertEqual(ringBuffer.pop(), "three")
    XCTAssertEqual(ringBuffer.pop(), "two")
    XCTAssertEqual(ringBuffer.pop(), "one")
    // Then
    XCTAssertEqual(Array(ringBuffer), [])
  }

  func testPopUndosPush_IncludingIndexingEdgeCases() throws {
    // Given
    var ringBuffer = RingBuffer<Int>(capacity: 10)
    for number in Array(1 ... 15) {
      ringBuffer.push(number)
    }

    // ringBuffer: [11, 12, 13, 14, 15, 6, 7, 8, 9, 10]
    // tailIndex - 1: ______________/

    // Then
    for number in Array(6 ... 15).reversed() {
      let popped = ringBuffer.pop()
      XCTAssertEqual(popped, number)
    }

    XCTAssertNil(ringBuffer.pop())
    XCTAssertEqual(Array(ringBuffer), [])
  }
}
