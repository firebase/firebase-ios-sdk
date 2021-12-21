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

/// A type that can be converted to a `HeartbeatsPayload`.
protocol HeartbeatsPayloadConvertible {
  func makeHeartbeatsPayload() -> HeartbeatsPayload
}

/// A codable collection of heartbeats that has a fixed capacity and optimizations for storing heartbeats of
/// multiple time periods.
struct HeartbeatsBundle: Codable, HeartbeatsPayloadConvertible {
  /// The maximum number of heartbeats that can be stored in the buffer.
  let capacity: Int
  /// A cache used for keeping track of the last heartbeat date recorded for a given time period.
  ///
  /// The cache contains the last added date for each time period. The reason only the date is cached is
  /// because it's the only piece of information that should be used by clients to determine whether or not
  /// to append a new heartbeat.
  private(set) var lastAddedHeartbeatDates: [TimePeriod: Date]
  /// A ring buffer of heartbeats.
  private var buffer: RingBuffer<Heartbeat>

  /// A default cache provider that provides a dictionary of all time periods mapping to a default date.
  static var cacheProvider: () -> [TimePeriod: Date] {
    let timePeriodsAndDates = TimePeriod.allCases.map { ($0, Date.distantPast) }
    return { Dictionary(uniqueKeysWithValues: timePeriodsAndDates) }
  }

  /// Designated initializer.
  /// - Parameters:
  ///   - capacity: The heartbeat capacity of the inititialized collection.
  ///   - cache: A cache of time periods mapping to dates. Defaults to using static `cacheProvider`.
  init(capacity: Int,
       cache: [TimePeriod: Date] = cacheProvider()) {
    buffer = RingBuffer(capacity: capacity)
    self.capacity = capacity
    lastAddedHeartbeatDates = cache
  }

  /// Appends a heartbeat to this collection.
  /// - Parameter heartbeat: The heartbeat to append.
  mutating func append(_ heartbeat: Heartbeat) {
    guard capacity > 0 else {
      return // Do not append if capacity is non-positive.
    }

    // 1. Push the heartbeat to the back of the buffer.
    if let overwrittenHeartbeat = buffer.push(heartbeat) {
      // If a heartbeat was overwritten, update the cache to ensure it's date
      // is removed (if it was stored).
      lastAddedHeartbeatDates = lastAddedHeartbeatDates.mapValues { date in
        overwrittenHeartbeat.date == date ? .distantPast : date
      }
    }

    // 2. Update cache with the new heartbeat's date.
    heartbeat.timePeriods.forEach {
      lastAddedHeartbeatDates[$0] = heartbeat.date
    }
  }

  /// Removes the heartbeat associated with the given date.
  /// - Parameter date: The date of the heartbeat needing removal.
  /// - Returns: The heartbeat that was removed or `nil` if there was no heartbeat to remove.
  @discardableResult
  mutating func removeHeartbeat(from date: Date) -> Heartbeat? {
    var removedHeartbeat: Heartbeat?

    var poppedHeartbeats: [Heartbeat] = []

    while let poppedHeartbeat = buffer.pop() {
      if poppedHeartbeat.date == date {
        removedHeartbeat = poppedHeartbeat
        break
      }
      poppedHeartbeats.append(poppedHeartbeat)
    }

    poppedHeartbeats.reversed().forEach {
      buffer.push($0)
    }

    return removedHeartbeat
  }

  /// Makes and returns a `HeartbeatsPayload` from this heartbeats bundle.
  /// - Returns: A heartbeats payload.
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
