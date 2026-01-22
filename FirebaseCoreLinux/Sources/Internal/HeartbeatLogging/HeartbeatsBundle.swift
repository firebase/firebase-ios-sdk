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

    } catch let error as RingBuffer<Heartbeat>.Error {
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
