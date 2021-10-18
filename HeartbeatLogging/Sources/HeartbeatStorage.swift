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

/// Thread-safe storage object designed for storing heartbeat data.
final class HeartbeatStorage {
  private let storage: PersistentStorage
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let queue: DispatchQueue

  private let limit: Int = 25 // TODO: Decide how this will be injected...

  init(id: String, // TODO: - Sanitize!
       storage: PersistentStorage,
       encoder: JSONEncoder = .init(),
       decoder: JSONDecoder = .init()) {
    self.storage = storage
    self.encoder = encoder
    self.decoder = decoder

    let label = "com.heartbeat.storage.\(id)"
    queue = DispatchQueue(label: label)
  }

  func offer(_ heartbeat: Heartbeat) {
    queue.async { [self] in
      let loaded = try? load(from: storage)
      var heartbeatInfo = loaded ?? HeartbeatInfo(capacity: limit)
      heartbeatInfo.offer(heartbeat)
      try? save(heartbeatInfo, to: storage)
    }
  }

  // TODO: Review and decide if the below API should provide an `async` option.
  func flush() -> HeartbeatInfo? {
    queue.sync {
      let flushed = try? load(from: storage)
      try? save(nil, to: storage)
      return flushed
    }
  }

  private func load(from storage: PersistentStorage) throws -> HeartbeatInfo {
    let data = try self.storage.read()
    let heartbeatData = try decoder.decode(HeartbeatInfo.self, from: data)
    return heartbeatData
  }

  private func save(_ value: HeartbeatInfo?, to storage: PersistentStorage) throws {
    if let value = value {
      let data = try encoder.encode(value)
      try storage.write(data)
    } else {
      try storage.write(nil)
    }
  }
}
