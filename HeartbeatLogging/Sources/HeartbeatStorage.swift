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
  associatedtype Contents: Codable
  func load(from storage: PersistentStorage) -> Contents
  func save(_ value: Contents?, to storage: PersistentStorage)
}

/// A type that provides a synchronizable, block-based API for reading and writing.
protocol Synchronizable: PersistenceController {
  typealias ReadWriteBlock = (inout Contents) -> ()
  func readWriteSync(_ transform: ReadWriteBlock)
  func readWriteAsync(_ transform: @escaping ReadWriteBlock)
}

typealias ThreadSafeStorage = Synchronizable & PersistenceController

// MARK: - HeartbeatStorage

/// Thread-safe storage object designed for storing heartbeat data.
final class HeartbeatStorage {
  typealias Storage = PersistentStorage

  private let storage: Storage
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let queue: DispatchQueue

  init(
    id: String, // TODO: - Sanitize!
    storage: Storage,
    encoder: JSONEncoder = .init(),
    decoder: JSONDecoder = .init()
  ) {
    self.storage = storage
    self.encoder = encoder
    self.decoder = decoder

    let label = "com.heartbeat.storage.\(id)"
    self.queue = DispatchQueue(label: label)
  }

}

// MARK: - ThreadSafeStorage

extension HeartbeatStorage: ThreadSafeStorage {

  func readWriteSync(_ transform: ReadWriteBlock) {
    queue.sync { execute(transform) }
  }

  func readWriteAsync(_ transform: @escaping ReadWriteBlock) {
    queue.async { self.execute(transform) }
  }

  func execute(_ transform: ReadWriteBlock) {
    var loggingData = load(from: storage)  // Load logging data into memory.
    transform(&loggingData)                // Transform the logging data.
    save(loggingData, to: storage)         // Save logging data to memory.
  }

  func load(from storage: Storage) -> HeartbeatData {
    // --snip--
    HeartbeatData()
  }

  func save(_ value: HeartbeatData?, to storage: Storage) {
    // --snip--
  }

}
