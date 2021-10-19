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

/// A type that can be represented as an HTTP header.
public protocol HTTPHeaderRepresentable {
  func headerValue() -> String
}

/// - <#Todo#>:  Add documentation.
///
///   ```
///
///   {
///     "buffer": [❤ ❤ ❤ ❤ ❤ ❤],
///     "cache": {"type": ❤, ...}
///   }
///
///   ```
///
/// - Note: This data structure is **not** thread-safe.
///
public struct HeartbeatInfo: Codable {
  private var buffer: RingBuffer

  init(capacity: Int) {
    buffer = RingBuffer(capacity: capacity)
  }

  /// <#Description#>
  /// - Parameter heartbeat: <#heartbeat description#>
  /// - Complexity: O(1)
  mutating func offer(_ heartbeat: Heartbeat) {
    // `timePeriods` represents the time periods that the given `heartbeat`
    // should be tagged with. It is calculated by filtering for time periods
    // that have either an expired heartbeat or no associated heartbeat.
    let timePeriods = TimePeriod.periods.filter { timePeriod in
      if let lastHeartbeat = buffer.latestHeartbeat(type: timePeriod) {
        // Include `timePeriod` if the `lastHeartbeat` of this type is expired.
        return heartbeat.date - lastHeartbeat.date > timePeriod.timeInterval
      } else {
        // No cached heartbeat for `timePeriod` so include for tagging.
        return true
      }
    }

    if !timePeriods.isEmpty {
      // If `timePeriods` is non-empty, the given `heartbeat` should be stored
      // in the `buffer`. Update the `heartbeat` and append it to the buffer.
      var heartbeat = heartbeat
      heartbeat.timePeriods = timePeriods
      buffer.append(heartbeat)
    }
  }
}

extension HeartbeatInfo {
  /// <#Description#>
  private struct RingBuffer: Codable {
    /// An array of heartbeats treated as a circular queue and intialized with a fixed capacity.
    private var circularQueue: [Heartbeat?]
    /// The current "tail" and insert point for the `circularQueue`.
    private var tailIndex: Int

    /// <#Description#>
    private var cache = Cache()

    init(capacity: Int) {
      circularQueue = .init(repeating: nil, count: capacity)
      tailIndex = 0
    }

    /// <#Description#>
    /// - Parameter value: <#value description#>
    mutating func append(_ value: Heartbeat) {
      guard circularQueue.capacity > 0 else { return }

      // If a heartbeat in the `circularQueue` is about to be overwritten,
      // remove it from the buffer `cache`.
      if let replacing = circularQueue[tailIndex] { cache.remove(replacing) }

      // Write the value to the `circularQueue` at `tailIndex`.
      circularQueue[tailIndex] = value

      // Store the written `value` in the buffer `cache`.
      cache.store(value)

      // Increment `tailIndex`, wrapping around to the start if needed.
      tailIndex = (tailIndex + 1) % circularQueue.capacity
    }

    func latestHeartbeat(type: TimePeriod) -> Heartbeat? {
      cache[type]
    }

    /// <#Description#>
    private final class Cache: Codable {
      private lazy var cache: [TimePeriod: Heartbeat] = [:]

      func remove(_ heartbeat: Heartbeat) {
        cache = cache.filter { $1 != heartbeat }
      }

      func store(_ heartbeat: Heartbeat) {
        heartbeat.timePeriods.forEach { cache[$0] = heartbeat }
      }

      subscript(key: TimePeriod) -> Heartbeat? {
        cache[key]
      }
    }
  }
}

// MARK: - HTTPHeaderRepresentable

extension HeartbeatInfo: HTTPHeaderRepresentable {
  public func headerValue() -> String {
    ""
  }
}

extension Date {
  static func - (lhs: Self, rhs: Self) -> TimeInterval {
    lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
  }
}
