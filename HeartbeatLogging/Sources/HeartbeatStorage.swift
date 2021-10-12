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

/// A type that acts as a controller for a `PersistentStorage` object(s).
protocol PersistenceController {
  associatedtype Value: Codable
  func load(from storage: PersistentStorage) -> Value
  func save(_ value: Value?, to storage: PersistentStorage)
}

/// A type that provides block-based API for reading and writing.
protocol Synchronizable {
  associatedtype Contents
  typealias ReadWriteBlock = (inout Contents) -> Void
  func readWriteSync(_ transform: ReadWriteBlock)
  func readWriteAsync(_ transform: @escaping ReadWriteBlock)
}

// MARK: - HeartbeatStorage

/// Thread-safe storage object designed for storing heartbeat data.
final class HeartbeatStorage {
  typealias Storage = PersistentStorage

  private let storage: Storage
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let queue: DispatchQueue

  init(id: String, // TODO: - Sanitize!
       storage: Storage,
       encoder: JSONEncoder = .init(),
       decoder: JSONDecoder = .init()) {
    self.storage = storage
    self.encoder = encoder
    self.decoder = decoder

    let label = "com.heartbeat.storage.\(id)"
    queue = DispatchQueue(label: label)
  }
}

// MARK: - Synchronizable

extension HeartbeatStorage: Synchronizable {
  typealias Contents = HeartbeatData

  func readWriteSync(_ transform: ReadWriteBlock) {
    queue.sync { execute(transform) }
  }

  func readWriteAsync(_ transform: @escaping ReadWriteBlock) {
    queue.async { self.execute(transform) }
  }

  func execute(_ transform: ReadWriteBlock) {
    var loggingData = load(from: storage)
    transform(&loggingData)
    save(loggingData, to: storage)
  }
}

// MARK: - PersistenceController

extension HeartbeatStorage: PersistenceController {
  typealias Value = HeartbeatData

  func load(from storage: Storage) -> Value {
    // --snip--
    HeartbeatData()
  }

  func save(_ value: Value?, to storage: Storage) {
    // --snip--
  }
}
