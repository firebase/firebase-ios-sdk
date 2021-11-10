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

/// A  logger object that provides API to log and flush heartbeats from a synchronized storage container.
public final class HeartbeatController {
  /// The thread-safe storage object to log and flush heartbeats from.
  private let storage: HeartbeatStorageProtocol
  // TODO: Document.
  private let limit: Int = 30 // TODO: Decide on default value.
  // TODO: Document.
  private let dateProvider: () -> Date
  // TODO: Verify that this standardization aligns with backend.
  // TODO: Document.
  static let dateStandardizer = Calendar(identifier: .gregorian).startOfDay(for:)

  /// Public initializer.
  ///
  /// - Parameter id: The `id` to associate this logger's internal storage with.
  public convenience init(id: String) {
    // TODO: Sanitize id.
    let storage = HeartbeatStorage.getInstance(id: id)
    self.init(storage: storage)
  }

  /// Designated initializer.
  ///
  /// - Parameters:
  ///   - storage: The logger's internal storage object.
  ///   - dateProvider: TODO: Document.
  init(storage: HeartbeatStorageProtocol,
       dateProvider: @escaping () -> Date = Date.init) {
    self.storage = storage
    self.dateProvider = { Self.dateStandardizer(dateProvider()) }
  }

  /// Asynchronously log a new heartbeat, if needed.
  ///
  /// - Note: This API is thread-safe.
  ///
  /// - Parameter info: A `String` identifier to associate a new heartbeat with.
  public func log(_ info: String) {
    let (agent, date, capacity) = (info, dateProvider(), limit)

    storage.async { heartbeatInfo in
      var heartbeatInfo = heartbeatInfo ?? HeartbeatInfo(capacity: capacity)

      let timePeriods = heartbeatInfo.cache.filter { timePeriod, lastDate in
        date.timeIntervalSince(lastDate) >= timePeriod.timeInterval
      }
      .map { timePeriod, _ in timePeriod }

      if !timePeriods.isEmpty {
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
  /// - Returns: The flushed heartbeats in the form of `HeartbeatInfo`.
  @discardableResult
  public func flush() -> HeartbeatsPayload {
    let capacity = limit

    let heartbeatInfo = try? storage.getAndReset { heartbeatInfo in
      if let heartbeatInfo = heartbeatInfo {
        // The new value that's stored will use the old's cache.
        return HeartbeatInfo(capacity: capacity, cache: heartbeatInfo.cache)
      } else {
        return nil // Storage was empty.
      }
    }

    return HeartbeatsPayload.makePayload(heartbeatInfo: heartbeatInfo)
  }
}
