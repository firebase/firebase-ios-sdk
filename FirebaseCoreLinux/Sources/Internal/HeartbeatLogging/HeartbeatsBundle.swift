// Copyright 2025 Google LLC
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

struct HeartbeatsBundle: Codable, HeartbeatsPayloadConvertible {
  let capacity: Int
  private(set) var lastAddedHeartbeatDates: [TimePeriod: Date]
  private var buffer: RingBuffer<Heartbeat>

  static var cacheProvider: () -> [TimePeriod: Date] {
    let timePeriodsAndDates = TimePeriod.allCases.map { ($0, Date.distantPast) }
    return { Dictionary(uniqueKeysWithValues: timePeriodsAndDates) }
  }

  init(capacity: Int,
       cache: [TimePeriod: Date] = cacheProvider()) {
    buffer = RingBuffer(capacity: capacity)
    self.capacity = capacity
    lastAddedHeartbeatDates = cache
  }

  mutating func append(_ heartbeat: Heartbeat) {
    guard capacity > 0 else { return }

    do {
      if let overwrittenHeartbeat = try buffer.push(heartbeat) {
        lastAddedHeartbeatDates = lastAddedHeartbeatDates.mapValues { date in
          overwrittenHeartbeat.date == date ? .distantPast : date
        }
      }

      for timePeriod in heartbeat.timePeriods {
        lastAddedHeartbeatDates[timePeriod] = heartbeat.date
      }

    } catch let error as RingBufferError {
      self = HeartbeatsBundle(capacity: capacity)

      // RingBuffer error logic
      // Note: RingBuffer.Error was defined in RingBuffer.swift.
      // But here we use RingBuffer<Heartbeat>.Error.
      // In RingBuffer.swift: enum Error: Swift.Error
      // It should be accessible.

      let errorDescription = "\(error)" // Simplified description
      let diagnosticHeartbeat = Heartbeat(
        agent: "\(heartbeat.agent) error/\(errorDescription)",
        date: heartbeat.date,
        timePeriods: heartbeat.timePeriods
      )

      try? buffer.push(diagnosticHeartbeat)

       for timePeriod in diagnosticHeartbeat.timePeriods {
          lastAddedHeartbeatDates[timePeriod] = diagnosticHeartbeat.date
        }
    } catch {
      // Ignore
    }
  }

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

    for poppedHeartbeat in poppedHeartbeats.reversed() {
      try? buffer.push(poppedHeartbeat)
    }

    return removedHeartbeat
  }

  func makeHeartbeatsPayload() -> HeartbeatsPayload {
    let agentAndDates = buffer.map { heartbeat in
      (heartbeat.agent, [heartbeat.date])
    }

    let userAgentPayloads = [String: [Date]](agentAndDates, uniquingKeysWith: +)
      .map(HeartbeatsPayload.UserAgentPayload.init)
      .sorted { $0.agent < $1.agent }

    return HeartbeatsPayload(userAgentPayloads: userAgentPayloads)
  }
}
