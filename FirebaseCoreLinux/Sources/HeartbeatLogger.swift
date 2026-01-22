import Foundation

/// A logger that reports heartbeats.
public class HeartbeatLogger {
  private let heartbeatController: HeartbeatController
  private let userAgentProvider: () -> String

  public init(appID: String) {
    self.heartbeatController = HeartbeatController(id: appID)
    // TODO: Implement proper user agent generation
    self.userAgentProvider = {
      return "FirebaseCoreLinux/1.0"
    }
  }

  public func log() {
    let userAgent = userAgentProvider()
    heartbeatController.log(userAgent)
  }

  public func headerValue() -> String? {
    let payload = heartbeatController.flush()
    if payload.isEmpty {
      return nil
    }
    return payload.headerValue()
  }
}
