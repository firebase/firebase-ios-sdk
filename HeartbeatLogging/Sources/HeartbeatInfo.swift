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
  private var buffer: RingBuffer

  init(capacity: Int) {
    buffer = RingBuffer(capacity: capacity)
  }

  /// <#Description#>
  /// - Parameter heartbeat: <#heartbeat description#>
  /// - Complexity: O(1)
  mutating func offer(_ heartbeat: Heartbeat) {
    let newTypes = Heartbeat.Kind.allCases.filter { kind in
      if let lastHeartbeat = buffer.value(kind) {
        let userAgentHasChanged = lastHeartbeat.info == heartbeat.info
        let isNewerHeartbeat = heartbeat.isNewerThan(lastHeartbeat, kind: kind)
        return isNewerHeartbeat || userAgentHasChanged
      } else {
        // There was no heartbeat of this kind in the cache. This `heartbeat`
        // should be marked as being this kind.
        return true
      }
    }

    if !newTypes.isEmpty {
      var heartbeat = heartbeat
      heartbeat.types = newTypes
      buffer.append(heartbeat)
    }
  }
}

extension HeartbeatInfo {
  /// <#Description#>
  private struct RingBuffer: Codable {
    private var buffer: [Heartbeat?]
    private var index: Int

    private var cache = Cache()

    init(capacity: Int) {
      buffer = .init(repeating: nil, count: capacity)
      index = 0
    }

    /// <#Description#>
    /// - Parameter value: <#value description#>
    mutating func append(_ value: Heartbeat) {
      guard buffer.capacity > 0 else { return }

      // 1. If a heartbeat in the `buffer` is about to be overwritten, remove
      //    it from the buffer `cache`.
      if let replacing = buffer[index] { cache.remove(replacing) }

      // 2. Write the value to the `buffer` at `index`.
      buffer[index] = value

      // 3. Store the written `value` in the buffer `cache`.
      cache.store(value)

      // 4. Increment `index`, wrapping back around to the start accordingly.
      index = (index + 1) % buffer.capacity
    }

    func value(_ key: Heartbeat.Kind) -> Heartbeat? { cache[key] }

    /// <#Description#>
    private final class Cache: Codable {
      private lazy var cache: [Heartbeat.Kind: Heartbeat] = [:]

      func remove(_ heartbeat: Heartbeat) {
        cache = cache.filter { $1 != heartbeat }
      }

      func store(_ heartbeat: Heartbeat) {
        heartbeat.types.forEach { cache[$0] = heartbeat }
      }

      subscript(key: Heartbeat.Kind) -> Heartbeat? { cache[key] }
    }
  }
}

// MARK: - HTTPHeaderRepresentable

extension HeartbeatInfo: HTTPHeaderRepresentable {
  public func headerValue() -> String {
    ""
  }
}
