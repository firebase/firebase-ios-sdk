import Foundation

/// An enumeration of time periods.
enum TimePeriod: Int, CaseIterable, Codable {
  case daily = 1

  var timeInterval: TimeInterval {
    Double(rawValue) * 86400
  }
}

/// A structure representing SDK usage.
struct Heartbeat: Codable, Equatable {
  private static let version: Int = 0

  let agent: String
  let date: Date
  let version: Int
  let timePeriods: [TimePeriod]

  init(agent: String,
       date: Date,
       timePeriods: [TimePeriod] = [],
       version: Int = version) {
    self.agent = agent
    self.date = date
    self.timePeriods = timePeriods
    self.version = version
  }
}

extension Heartbeat: HeartbeatsPayloadConvertible {
  func makeHeartbeatsPayload() -> HeartbeatsPayload {
    let userAgentPayloads = [
      HeartbeatsPayload.UserAgentPayload(agent: agent, dates: [date]),
    ]
    return HeartbeatsPayload(userAgentPayloads: userAgentPayloads)
  }
}
