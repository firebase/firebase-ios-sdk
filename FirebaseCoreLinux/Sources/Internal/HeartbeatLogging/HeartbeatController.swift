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

public final class HeartbeatController: Sendable {
  private enum DateStandardizer {
    private static let calendar: Calendar = {
      var calendar = Calendar(identifier: .iso8601)
      calendar.locale = Locale(identifier: "en_US_POSIX")
      calendar.timeZone = TimeZone(secondsFromGMT: 0)!
      return calendar
    }()

    static func standardize(_ date: Date) -> (Date) {
      return calendar.startOfDay(for: date)
    }
  }

  private let storage: any HeartbeatStorageProtocol
  private static let heartbeatsStorageCapacity: Int = 30
  private let dateProvider: @Sendable () -> Date
  private static let dateStandardizer = DateStandardizer.self

  public convenience init(id: String) {
    self.init(id: id, dateProvider: { Date() })
  }

  convenience init(id: String, dateProvider: @escaping @Sendable () -> Date) {
    let storage = HeartbeatStorage.getInstance(id: id)
    self.init(storage: storage, dateProvider: dateProvider)
  }

  init(storage: HeartbeatStorageProtocol,
       dateProvider: @escaping @Sendable () -> Date = { Date() }) {
    self.storage = storage
    self.dateProvider = { Self.dateStandardizer.standardize(dateProvider()) }
  }

  public func log(_ agent: String) {
    let date = dateProvider()

    storage.readAndWriteAsync { heartbeatsBundle in
      var heartbeatsBundle = heartbeatsBundle ??
        HeartbeatsBundle(capacity: Self.heartbeatsStorageCapacity)

      let timePeriods = heartbeatsBundle.lastAddedHeartbeatDates.filter { timePeriod, lastDate in
        date.timeIntervalSince(lastDate) >= timePeriod.timeInterval
      }
      .map { timePeriod, _ in timePeriod }

      if !timePeriods.isEmpty {
        let heartbeat = Heartbeat(agent: agent, date: date, timePeriods: timePeriods)
        heartbeatsBundle.append(heartbeat)
      }

      return heartbeatsBundle
    }
  }

  @discardableResult
  public func flush() -> HeartbeatsPayload {
    let resetTransform = { (heartbeatsBundle: HeartbeatsBundle?) -> HeartbeatsBundle? in
      guard let oldHeartbeatsBundle = heartbeatsBundle else {
        return nil
      }
      return HeartbeatsBundle(
        capacity: Self.heartbeatsStorageCapacity,
        cache: oldHeartbeatsBundle.lastAddedHeartbeatDates
      )
    }

    do {
      let heartbeatsBundle = try storage.getAndSet(using: resetTransform)
      return heartbeatsBundle?.makeHeartbeatsPayload() ?? HeartbeatsPayload.emptyPayload
    } catch {
      return HeartbeatsPayload.emptyPayload
    }
  }

  public func flushAsync(completionHandler: @escaping @Sendable (HeartbeatsPayload) -> Void) {
    let resetTransform = { @Sendable (heartbeatsBundle: HeartbeatsBundle?) -> HeartbeatsBundle? in
      guard let oldHeartbeatsBundle = heartbeatsBundle else {
        return nil
      }
      return HeartbeatsBundle(
        capacity: Self.heartbeatsStorageCapacity,
        cache: oldHeartbeatsBundle.lastAddedHeartbeatDates
      )
    }

    storage.getAndSetAsync(using: resetTransform) { result in
      switch result {
      case let .success(heartbeatsBundle):
        completionHandler(heartbeatsBundle?.makeHeartbeatsPayload() ?? HeartbeatsPayload.emptyPayload)
      case .failure:
        completionHandler(HeartbeatsPayload.emptyPayload)
      }
    }
  }

  @discardableResult
  public func flushHeartbeatFromToday() -> HeartbeatsPayload {
    let todaysDate = dateProvider()
    var todaysHeartbeat: Heartbeat?

    storage.readAndWriteSync { heartbeatsBundle in
      guard var heartbeatsBundle = heartbeatsBundle else {
        return nil
      }

      todaysHeartbeat = heartbeatsBundle.removeHeartbeat(from: todaysDate)

      return heartbeatsBundle
    }

    if let todaysHeartbeat {
      return todaysHeartbeat.makeHeartbeatsPayload()
    } else {
      return HeartbeatsPayload.emptyPayload
    }
  }
}
