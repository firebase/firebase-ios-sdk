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

// MARK: - HeartbeatData

/// A value representing an organized collection of different types of heartbeats.
///
/// This data structure is backed by a dictionary where each key is a time period (i.e. daily, weekly, monthly)
/// and the corresponding value is a queue of heartbeats. For example, the `daily` key maps to a queue
/// of "daily" heartbeats, and so on. New heartbeats are enqueued at the front of the queue.
///
/// The underlying dictionary is visualized below:
///
///   ```
///        newest
///   {       \
///     daily: ❤ ❤ ❤ ❤ ❤ ❤
///     weekly: ❤ ❤ ❤     \
///     monthly: ❤      oldest
///   }
///
///   ```
///
///   - Note: This data structure is **not** thread-safe.
///
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

  /// All the types of heartbeat queues (i.e. daily, weekly, monthly).
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
    // --snip--
    true
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
    // --snip--
    nil
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
