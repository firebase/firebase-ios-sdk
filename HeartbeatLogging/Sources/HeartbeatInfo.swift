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

// MARK: - HeartbeatInfo

/// A structure representing a collection of heartbeats.
///
/// - Note: This data structure is **not** thread-safe.
public struct HeartbeatInfo: Codable {
  private var buffer: HeartbeatRingBuffer

  /// Intializes a `HeartbeatInfo` with a given `capacity`.
  /// - Parameter capacity: An `Int` representing the capacity.
  internal init(capacity: Int) {
    buffer = HeartbeatRingBuffer(capacity: capacity)
  }

  /// Enqueues a heartbeat if needed.
  /// - Parameter heartbeat: The heartbeat to offer for enqueueing.
  /// - Returns: `True` if the heartbeat was enqueued; otherwise, `false`.
  /// - Complexity: O(1)
  internal mutating func offer(_ heartbeat: Heartbeat) -> Bool {
    // `timePeriods` represents the time periods that the given `heartbeat`
    // should be tagged with. It is calculated by filtering for time periods
    // that have either an expired heartbeat or no associated heartbeat.
    let timePeriods = TimePeriod.periods.filter { timePeriod in
      if let lastHeartbeat = buffer.lastHeartbeat(forTimePeriod: timePeriod) {
        let (heartbeat, lastHeartbeat) = (heartbeat.date, lastHeartbeat.date)
        // Include `timePeriod` if the `lastHeartbeat` of this type is expired.
        return heartbeat.timeIntervalSince(lastHeartbeat) > timePeriod.timeInterval
      } else {
        // No cached heartbeat for `timePeriod` so include for tagging.
        return true
      }
    }

    guard !timePeriods.isEmpty else {
      // Return `false` as `heartbeat` need not be saved for any `TimePeriod`.
      return false
    }

    // The given `heartbeat` should be stored in the `buffer`.
    // Update the `heartbeat`'s `timePeriods` and append it to the buffer.
    var heartbeat = heartbeat
    heartbeat.timePeriods = timePeriods
    buffer.append(heartbeat)
    return true
  }
}

// MARK: - HeartbeatInfo + HTTPHeaderRepresentable

extension HeartbeatInfo: HTTPHeaderRepresentable {
  public func headerValue() -> String {
    ""
  }
}

// MARK: - HeartbeatRingBuffer

/// A fixed-capacity ring buffer of heartbeats that can track heartbeats from various time periods.
private struct HeartbeatRingBuffer: Codable {
  /// An array of heartbeats treated as a circular queue and intialized with a fixed capacity.
  private var circularQueue: [Heartbeat?]
  /// The current "tail" and insert point for the `circularQueue`.
  private var tailIndex: Int
  /// A cache storing the last heartbeat appended to `circularQueue` for each `TimePeriod`.
  /// - Note: This property's type has reference semantics.
  private let latestHeartbeatByTimePeriod: HeartbeatByTimePeriodCache

  /// Intializes a `RingBuffer` with a given `capacity`.
  /// - Parameter capacity: An `Int` representing the capacity.
  init(capacity: Int) {
    circularQueue = .init(repeating: nil, count: capacity)
    tailIndex = 0
    latestHeartbeatByTimePeriod = .init()
  }

  /// Adds a heartbeat at the end of the buffer, overwriting an existing heartbeat if the capacity is reached.
  /// - Parameter heartbeat: The heartbeat to append to the buffer.
  /// - Complexity: O(1)
  mutating func append(_ heartbeat: Heartbeat) {
    guard circularQueue.capacity > 0 else { return }

    if let replacing = circularQueue[tailIndex] {
      // If a heartbeat in the `circularQueue` is about to be overwritten,
      // remove it from the `heartbeatsByTimePeriodCache`.
      latestHeartbeatByTimePeriod.remove(replacing)
    }

    // Write the `heartbeat` to the `circularQueue` at `tailIndex`.
    circularQueue[tailIndex] = heartbeat

    // Store the written `heartbeat` in the `heartbeatsByTimePeriodCache`.
    latestHeartbeatByTimePeriod.store(heartbeat)

    // Increment `tailIndex`, wrapping around to the start if needed.
    tailIndex = (tailIndex + 1) % circularQueue.capacity
  }

  /// Returns the last heartbeat from a given time period.
  /// - Parameter timePeriod: Time period where a heartbeat may occur.
  /// - Returns: Optionally, the last  `Heartbeat` to occur in the given time period.
  func lastHeartbeat(forTimePeriod timePeriod: TimePeriod) -> Heartbeat? {
    latestHeartbeatByTimePeriod[timePeriod]
  }

  /// A cache mapping `TimePeriod` keys to `Heartbeat` values.
  ///
  /// This type's API are considered to be constant time as they are bounded by the number of cases in
  /// the `TimePeriod` enum.
  ///
  /// - Note: This type has reference semantics.
  private final class HeartbeatByTimePeriodCache: Codable {
    private lazy var cache: [TimePeriod: Heartbeat] = [:]

    /// Removes a given heartbeat from the cache.
    /// - Parameter heartbeat: The heartbeat to remove.
    func remove(_ heartbeat: Heartbeat) {
      // The below operation is considered constant time because the cache has
      // a bounded number of keys (see the `TimePeriod` type).
      cache = cache.filter { $1 /* cachedHeartbeat */ != heartbeat }
    }

    /// Stores a given heartbeat to the cache.
    /// - Parameter heartbeat: The heartbeat to store.
    func store(_ heartbeat: Heartbeat) {
      // The below operation is considered constant time because a heartbeat
      // has a bound number of time periods (see the `TimePeriod` type).
      heartbeat.timePeriods.forEach { cache[$0] = heartbeat }
    }

    subscript(timePeriod: TimePeriod) -> Heartbeat? {
      cache[timePeriod]
    }
  }
}

private extension Date {
  /// Calculates the time interval since a given `date`.
  func timeIntervalSince(_ date: Date) -> TimeInterval {
    timeIntervalSinceReferenceDate - date.timeIntervalSinceReferenceDate
  }
}
