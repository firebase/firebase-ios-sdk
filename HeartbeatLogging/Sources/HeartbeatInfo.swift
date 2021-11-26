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

import Foundation

/// A type that can be represented as a `HeartbeatsPayload`.
protocol HeartbeatsPayloadConvertible {
  func makeHeartbeatsPayload() -> HeartbeatsPayload
}

/// A value type representing
struct HeartbeatInfo: Codable, HeartbeatsPayloadConvertible {
  /// The maximum number of heartbeats that can be stored.
  let capacity: Int
  /// <#Description#>
  private(set) var cache: [TimePeriod: Date]
  /// <#Description#>
  private var buffer: RingBuffer<Heartbeat>

  /// <#Description#>
  static var cacheProvider: () -> [TimePeriod: Date] {
    let timePeriodsAndDates = TimePeriod.periods.map { ($0, Date.distantPast) }
    return { Dictionary(uniqueKeysWithValues: timePeriodsAndDates) }
  }

  /// <#Description#>
  /// - Parameters:
  ///   - capacity: <#capacity description#>
  ///   - cacheProvider: <#cacheProvider description#>
  init(capacity: Int,
       cache: [TimePeriod: Date] = cacheProvider()) {
    buffer = RingBuffer(capacity: capacity)
    self.capacity = capacity
    self.cache = cache
  }

  /// App
  /// - Parameter heartbeat: <#heartbeat description#>
  mutating func append(_ heartbeat: Heartbeat) {
    // 1. Push the heartbeat to the back of the buffer.
    if let overwrittenHeartbeat = buffer.push(heartbeat) {
      // If a heartbeat was overwritten, update the cache to ensure it's date
      // is removed (if it was stored).
      cache = cache.mapValues { date in
        overwrittenHeartbeat.date == date ? .distantPast : date
      }
    }

    // 2. Update cache with the new heartbeat's date.
    heartbeat.timePeriods.forEach {
      cache[$0] = heartbeat.date
    }
  }

  func makeHeartbeatsPayload() -> HeartbeatsPayload {
    let agentAndDates = buffer.map { heartbeat in
      (heartbeat.agent, [heartbeat.date])
    }

    let userAgentPayloads = [String: [Date]](agentAndDates, uniquingKeysWith: +)
      .map(HeartbeatsPayload.UserAgentPayload.init)
      .sorted { $0.agent < $1.agent } // Sort payloads by user agent.

    return HeartbeatsPayload(userAgentPayloads: userAgentPayloads)
  }
}

/// A value type representing a generic ring buffer with a fixed capacity.
struct RingBuffer<Element>: Sequence {
  /// An array of heartbeats treated as a circular queue and intialized with a fixed capacity.
  private var circularQueue: [Element?]
  /// The current "tail" and insert point for the `circularQueue`.
  private var tailIndex: Int = 0

  /// Intializes a `RingBuffer` with a given `capacity`.
  /// - Parameter capacity: An `Int` representing the capacity.
  init(capacity: Int) {
    circularQueue = Array(repeating: nil, count: capacity)
  }

  /// Pushes an element to the back of the buffer, returning the element (`Element?`) that was overriten.
  /// - Parameter element: The element to push to the back of the buffer.
  /// - Returns: The element that was overwritten if an element was indeed overwritten. Else, `nil`.
  /// - Complexity: O(1)
  @discardableResult
  mutating func push(_ element: Element) -> Element? {
    guard circularQueue.capacity > 0 else {
      // Do not append if `capacity` is less than or equal 0.
      return nil
    }

    defer {
      // Increment index, wrapping around to the start if needed.
      tailIndex += 1
      tailIndex %= circularQueue.capacity
    }

    let replaced = circularQueue[tailIndex]
    circularQueue[tailIndex] = element
    return replaced
  }

  func makeIterator() -> IndexingIterator<[Element]> {
    circularQueue
      .compactMap { $0 } // Remove `nil` elements.
      .makeIterator()
  }
}

// MARK: - Codable

extension RingBuffer: Codable where Element: Codable {}
