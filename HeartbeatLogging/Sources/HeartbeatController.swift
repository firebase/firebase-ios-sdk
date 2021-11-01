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

  /// Public initializer.
  ///
  /// - Parameter id: The `id` to associate this logger's internal storage with.
  public convenience init(id: String) {
    let storage = StorageFactory.makeStorage(id: id)
    self.init(storage: HeartbeatStorage(id: id, storage: storage))
  }

  /// Designated initializer.
  ///
  /// - Parameters:
  ///   - storage: The logger's internal storage object.
  init(storage: HeartbeatStorageProtocol) {
    self.storage = storage
  }

  /// Asynchronously log a new heartbeat, if needed.
  ///
  /// - Note: This API is thread-safe.
  ///
  /// - Parameter info: A `String` identifier to associate a new heartbeat with.
  public func log(_ info: String) {
    let newHeartbeat = Heartbeat(info: info)
    storage.offer(newHeartbeat)
  }

  /// Synchronously flushes heartbeats from storage.
  ///
  /// - Note: This API is thread-safe.
  ///
  /// - Returns: The flushed heartbeats in the form of `HeartbeatInfo`.
  @discardableResult
  public func flush() -> HeartbeatInfo? {
    storage.flush()
  }
}
