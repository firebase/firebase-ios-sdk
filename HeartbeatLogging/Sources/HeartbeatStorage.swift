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

/// A type that can store and remove hearbeats.
protocol HeartbeatStoring {
  func offer(_ heartbeat: Heartbeat)
  func flush() -> HeartbeatInfo?
}

/// Thread-safe storage object designed for storing heartbeat data.
final class HeartbeatStorage: HeartbeatStoring {
  private let storage: PersistentStorage
  private let coder: Coder
  private let queue: DispatchQueue

  private let limit: Int = 25 // TODO: Decide how this will be injected...

  init(id: String, // TODO: - Sanitize!
       storage: PersistentStorage,
       coder: Coder = JSONCoder(),
       queue: DispatchQueue? = nil) {
    self.storage = storage
    self.coder = coder
    self.queue = queue ?? DispatchQueue(label: "com.heartbeat.storage.\(id)")
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
      let saveResult = Result { try save(nil, to: storage) }
      return try? saveResult.map { flushed }.get()
    }
  }

  private func load(from storage: PersistentStorage) throws -> HeartbeatInfo {
    let data = try storage.read()
    let heartbeatData = try coder.decode(HeartbeatInfo.self, from: data)
    return heartbeatData
  }

  private func save(_ value: HeartbeatInfo?, to storage: PersistentStorage) throws {
    if let value = value {
      let data = try coder.encode(value)
      try storage.write(data)
    } else {
      try storage.write(nil)
    }
  }
}
