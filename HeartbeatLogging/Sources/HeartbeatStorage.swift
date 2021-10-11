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

/// <#Description#>
protocol StorageInterop { // TODO: Rename to `Storage Controller`?
  associatedtype Storage: PersistentStorage
  associatedtype Contents: Codable

  func load(from storage: Storage) -> Contents
  func save(_ value: Contents?, to storage: Storage)
}

/// A type that provides a synchronizable, block-based API for reading and writing transactions.
protocol Synchronizable: StorageInterop {
  typealias ReadWriteBlock = (inout Contents) -> ()
  func readWriteSync(_ transform: ReadWriteBlock)
  func readWriteAsync(_ transform: @escaping ReadWriteBlock)
}

typealias ThreadSafeStorage = Synchronizable & StorageInterop

// MARK: - HeartbeatStorage

// TODO: Investigate potential storage optimizations. `final class`?

/// Thread-safe storage designed for storing heartbeat data.
struct HeartbeatStorage<Factory: PersistentStorageFactory> {
  typealias Storage = Factory.Storage

  private let storage: Storage
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let queue: DispatchQueue

  init(
    id: String, // TODO: - Sanitize!
    encoder: JSONEncoder = .init(),
    decoder: JSONDecoder = .init()
  ) {
    self.storage = Factory.makeStorage(id: id)
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
    queue.async { execute(transform) }
  }

  func execute(_ transform: ReadWriteBlock) {
    var loggingData = load(from: storage)  // Load logging data into memory.
    transform(&loggingData)                // Transform the logging data.
    save(loggingData, to: storage)         // Save logging data to memory.
  }

  func load(from storage: Storage) -> HeartbeatData {
    let data = try? self.storage.read() // TODO: Handle error.

    let loggingData =                   // TODO: Handle error.
        try? decoder.decode(Contents.self, from: data!)

    return loggingData!
  }

  func save(_ value: HeartbeatData?, to storage: Storage) {
    if let value = value {
      let data = try? encoder.encode(value) // TODO: Handle error.
      try? storage.write(data)              // TODO: Handle error.
    } else {
      try? storage.write(nil)               // TODO: Handle error.
    }
  }

}
