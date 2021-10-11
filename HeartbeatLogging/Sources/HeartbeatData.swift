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

protocol MultiQueue { // TODO: Is this necessary? thinking no but maybe for testing
}

// MARK: - HeartbeatData

/// <#Description#>
public struct HeartbeatData: Codable {

  enum TimePeriod: Int, Codable, CaseIterable {
    case daily = 1
    case weekly = 7
    case monthly = 28

    var days: Int { rawValue }
  }

  private var heartbeatsDict: [TimePeriod: [Heartbeat]]

  init(heartbeatsDict: [TimePeriod: [Heartbeat]] = .init()) {
    self.heartbeatsDict = heartbeatsDict
  }

  var types: [TimePeriod] { TimePeriod.allCases }

  /// Enqueues a heartbeat to a heartbeat queue of type `type`.
  ///
  /// <#- ToDo:#>
  ///
  /// - Note: This API is **not** thread-safe.
  ///
  /// - Parameters:
  ///   - heartbeat: The heartbeat to offer to a heartbeat queue.
  ///   - type: The type of heartbeat queue that will be offered the `heartbeat`.
  /// - Returns: `True` if the heartbeat was enqueued; otherwise, `false`.
  /// - Complexity: O(n)
  @discardableResult
  mutating func offer(_ heartbeat: Heartbeat, type: TimePeriod) -> Bool {

    let heartbeatQueue = heartbeatsDict[type] ?? []

    guard !heartbeatQueue.isEmpty else {
      // The `heartbeatQueue` is empty, create a new queue with `heartbeat`.
      heartbeatsDict[type] = [heartbeat]
      return true
    }

    let (calendar, newest) = (Calendar.international, heartbeatQueue.first!)
    let shouldEnqueue = {
      // The `newest` has been stored for at least one time period, so
      // there is no risk of enqueuing a duplicate heartbeat.
      calendar.days(between: heartbeat.date, and: newest.date) >= type.days ||
      // Heartbeat `info` has changed so the `heartbeat` should be enqueued.
      heartbeat.info != newest.info
    }

    guard shouldEnqueue() else { return false }
    heartbeatsDict[type]!.insert(heartbeat, at: 0)
    return true
  }

  /// Dequeues a heartbeat from a heartbeat queue of type `type`.
  ///
  /// <#- ToDo:#>
  ///
  /// - Note: This API is **not** thread-safe.
  ///
  /// - Parameter type: The type of heartbeat queue that will dequeued.
  /// - Returns: The dequeued heartbeat if a heartbeat was dequeued; otherwise, `nil`.
  /// - Complexity: O(1)
  mutating func request(type: TimePeriod) -> Heartbeat? {
    guard let oldest: Heartbeat = heartbeatsDict[type]?.last else {
      // There is no heartbeat to remove.
      return nil
    }

    let (calendar, now) = (Calendar.international, Date())
    if calendar.days(between: oldest.date, and: now) < type.days {
      // The `oldest` must be retained to avoid the potential of later
      // enqueuing a duplicate heartbeat in the same time period.
      return nil
    } else {
      // The `oldest` has been stored for at least one time period, so
      // there is no risk of enqueuing a duplicate heartbeat.
      return heartbeatsDict[type]?.popLast()
    }
  }

}

// MARK: - HTTPHeaderRepresentable

extension HeartbeatData: HTTPHeaderRepresentable {

  public func headerValue() -> String {
    // TODO: Implement
    // - Filter out expired.
    // - Combine heartbeats tagged as multiple types
    // - Ensure it is HTTP compatible.
    heartbeatsDict.reduce(into: "") { header, item in
      // Transforms: `heartbeatsDict` → [String: [String: Any]] → JSON → String
    }
  }
}

// MARK: - `Calendar`

fileprivate extension Calendar {
  static var international: Self {
    Self.init(identifier: .iso8601)
  }

  func days(between from: Date, and to: Date) -> Int {
    let (from, to) = (startOfDay(for: from), startOfDay(for: to))
    let days = dateComponents([.day], from: from, to: to)
    return days.day! // Force unwrap since `.day` is passed to `dateComponents`.
  }
}
