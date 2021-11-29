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

/// An object that provides API to log and flush heartbeats from a synchronized storage container.
public final class HeartbeatController {
  /// The thread-safe storage object to log and flush heartbeats from.
  private let storage: HeartbeatStorageProtocol
  // TODO: Decide on default value.
  /// The max capacity of heartbeats to store in storage.
  private let heartbeatsStorageCapacity: Int = 30
  /// Current date provider. It is used for testability.
  private let dateProvider: () -> Date
  // TODO: Verify that this standardization aligns with backend.
  // TODO: Probably should share config with HeartbeatsPayload's DateFormatter.
  /// Used for standardizing dates for calendar-day comparision.
  static let dateStandardizer: (Date) -> (Date) = {
    var calendar = Calendar(identifier: .iso8601)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.startOfDay(for:)
  }()

  /// Public initializer.
  /// - Parameter id: The `id` to associate this controller's heartbeat storage with.
  public convenience init(id: String) {
    self.init(id: id, dateProvider: Date.init)
  }

  /// Convenience initializer. Mirrors the semantics of the public intializer with the added benefit of
  /// injecting a custom date provider for improved testability.
  /// - Parameters:
  ///   - id: The `id` to associate this controller's heartbeat storage with.
  ///   - dateProvider: A date provider.
  convenience init(id: String,
                   dateProvider: @escaping () -> Date) {
    let storage = HeartbeatStorage.getInstance(id: id)
    self.init(storage: storage, dateProvider: dateProvider)
  }

  /// Designated initializer.
  /// - Parameters:
  ///   - storage: A heartbeat storage container.
  ///   - dateProvider: A date provider. Defaults to providing the current date.
  init(storage: HeartbeatStorageProtocol,
       dateProvider: @escaping () -> Date = Date.init) {
    self.storage = storage
    self.dateProvider = { Self.dateStandardizer(dateProvider()) }
  }

  /// Asynchronously logs a new heartbeat, if needed.
  ///
  /// - Note: This API is thread-safe.
  ///
  /// - Parameter agent: The string agent to associate the logged heartbeat with.
  public func log(_ agent: String) {
    let date = dateProvider()
    let capacity = heartbeatsStorageCapacity

    storage.readAndWriteAsync { heartbeatInfo in
      var heartbeatInfo = heartbeatInfo ?? HeartbeatInfo(capacity: capacity)

      // Filter for the time periods where the last heartbeat to be logged for
      // that time period was logged more than one time period (i.e. day) ago.
      let timePeriods = heartbeatInfo.cache.filter { timePeriod, lastDate in
        date.timeIntervalSince(lastDate) >= timePeriod.timeInterval
      }
      .map { timePeriod, _ in timePeriod }

      if !timePeriods.isEmpty {
        // A heartbeat should only be logged if there is a time period(s) to
        // associate it with.
        let heartbeat = Heartbeat(agent: agent, date: date, timePeriods: timePeriods)
        heartbeatInfo.append(heartbeat)
      }

      return heartbeatInfo
    }
  }

  /// Synchronously flushes heartbeats from storage.
  ///
  /// - Note: This API is thread-safe.
  ///
  /// - Returns: The flushed heartbeats in the form of `HeartbeatsPayload`.
  @discardableResult
  public func flush() -> HeartbeatsPayload {
    let capacity = heartbeatsStorageCapacity

    let resetTransform: (HeartbeatInfo?) -> HeartbeatInfo? = { heartbeatInfo in
      guard let oldHeartbeatInfo = heartbeatInfo else {
        return nil // Storage was empty.
      }

      // The new value that's stored will use the old's cache.
      return HeartbeatInfo(capacity: capacity, cache: oldHeartbeatInfo.cache)
    }

    // Synchronously gets and returns the stored heartbeats and resets storage
    // using the given transform. If the operation threw an error, assume no
    // heartbeats were retrieved/reset.
    let heartbeatInfo = try? storage.getAndReset(using: resetTransform)

    if let heartbeatInfo = heartbeatInfo {
      return heartbeatInfo.makeHeartbeatsPayload()
    } else {
      return HeartbeatsPayload.emptyPayload
    }
  }
}
