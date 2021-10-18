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

/// - <#Todo#>:  Add documentation.
///
///   ```
///
///   {
///     "buffer": [❤ ❤ ❤ ❤ ❤ ❤],
///     "cache": {"type": ❤, ...}
///   }
///
///   ```
///
/// - Note: This data structure is **not** thread-safe.
///
public struct HeartbeatInfo: Codable {
  private let capacity: Int
  private var buffer: RingBuffer
  private var cache: Cache

  init(capacity: Int) {
    self.capacity = capacity
    buffer = RingBuffer(capacity: capacity)
    cache = Cache()
  }

  mutating func offer(_ heartbeat: Heartbeat) {
    // Store a heartbeat if needed.
  }
}

extension HeartbeatInfo {
  private struct RingBuffer: Codable {
    init(capacity: Int) {}
    mutating func append(_ value: Heartbeat) {}
  }

  private final class Cache: Codable {
    lazy var cache: [Heartbeat.Kind: Heartbeat] = [:]
  }
}

// MARK: - HTTPHeaderRepresentable

extension HeartbeatInfo: HTTPHeaderRepresentable {
  public func headerValue() -> String {
    ""
  }
}
