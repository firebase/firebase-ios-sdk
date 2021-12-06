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

/// A type that can perform atomic operations using block-based transformations.
protocol HeartbeatStorageProtocol {
  func readAndWriteAsync(using transform: @escaping (HeartbeatInfo?) -> HeartbeatInfo?)
  func getAndReset(using transform: ((HeartbeatInfo?) -> HeartbeatInfo?)?) throws -> HeartbeatInfo?
}

/// Thread-safe storage object designed for transforming heartbeat data that is persisted to disk.
final class HeartbeatStorage: HeartbeatStorageProtocol {
  /// The identifier used to differentiate instances.
  private let id: String
  /// The underlying storage container to read from and write to.
  private let storage: Storage
  /// An encoder used for encoding an `Encodable` type into `Data`.
  private let encoder: JSONEncoder
  /// A decoder used for decoding `Data` into a `Decodable` type.
  private let decoder: JSONDecoder
  /// The queue for synchronizing storage operations.
  private let queue: DispatchQueue

  /// Designated initializer.
  /// - Parameters:
  ///   - id: A string identifer.
  ///   - storage: The underlying storage container where heartbeat data is stored.
  ///   - encoder: An encoder used for encoding heartbeat data.
  ///   - decoder: A decoder used for decoding heartbeat data.
  init(id: String,
       storage: Storage,
       encoder: JSONEncoder = .init(),
       decoder: JSONDecoder = .init()) {
    self.id = id
    self.storage = storage
    self.encoder = encoder
    self.decoder = decoder
    queue = DispatchQueue(label: "com.heartbeat.storage.\(id)")
  }

  // MARK: - Instance Management

  /// Statically allocated cache of `HeartbeatStorage` instances.
  private static var cachedInstances: [String: WeakContainer<HeartbeatStorage>] = [:]

  /// Gets an existing `HeartbeatStorage` instance with the given `id` if one exists. Otherwise,
  /// makes a new instance with the given `id`.
  ///
  /// - Parameter id: A string identifier.
  /// - Returns: A `HeartbeatStorage` instance.
  static func getInstance(id: String) -> HeartbeatStorage {
    if let cachedInstance = cachedInstances[id]?.object {
      return cachedInstance
    } else {
      let newInstance = HeartbeatStorage.makeHeartbeatStorage(id: id)
      cachedInstances[id] = WeakContainer(object: newInstance)
      return newInstance
    }
  }

  /// Makes a `HeartbeatStorage` instance using a given `String` identifier.
  ///
  /// The created persistent storage object is platform dependent. For tvOS, user defaults
  /// is used as the underlying storage container due to system storage limits. For all other platforms,
  /// the file system is used.
  ///
  /// - Parameter id: A `String` identifier used to create the `HeartbeatStorage`.
  /// - Returns: A `HeartbeatStorage` instance.
  private static func makeHeartbeatStorage(id: String) -> HeartbeatStorage {
    #if os(tvOS)
      let storage = UserDefaultsStorage.makeStorage(id: id)
    #else
      let storage = FileStorage.makeStorage(id: id)
    #endif // os(tvOS)
    return HeartbeatStorage(id: id, storage: storage)
  }

  deinit {
    // Removes the instance if it was cached.
    Self.cachedInstances.removeValue(forKey: id)
  }

  // MARK: - HeartbeatStorageProtocol

  /// Asynchronously reads from and writes to storage using the given transform block.
  /// - Parameter transform: A block to transform `HeartbeatInfo?` to `HeartbeatInfo?`.
  func readAndWriteAsync(using transform: @escaping (HeartbeatInfo?) -> HeartbeatInfo?) {
    queue.async { [self] in
      let oldHeartbeatInfo = try? load(from: storage)
      let newHeartbeatInfo = transform(oldHeartbeatInfo)
      try? save(newHeartbeatInfo, to: storage)
    }
  }

  /// Synchronously gets the current heartbeat data from storage and resets the storage using the
  /// given transform block.
  ///
  /// This API is essentially a `getAndSet`-style API that gets (and returns) the current value and uses
  /// a block to transform the current value (or, soon-to-be old value) to a new value.
  ///
  /// - Parameter transform: An optional block used to reset the currently stored heartbeat.
  /// If `nil`, the storage is emptied.
  /// - Returns: The heartbeat data that was stored (before the `transform` was applied).
  @discardableResult
  func getAndReset(using transform: ((HeartbeatInfo?) -> HeartbeatInfo?)? = nil) throws
    -> HeartbeatInfo? {
    let heartbeatInfo: HeartbeatInfo? = try queue.sync {
      let oldHeartbeatInfo = try? load(from: storage)
      let newHeartbeatInfo = transform?(oldHeartbeatInfo)
      try save(newHeartbeatInfo, to: storage)
      return oldHeartbeatInfo
    }
    return heartbeatInfo
  }

  /// Loads and decodes the stored heartbeat info from a given storage object.
  /// - Parameter storage: The storage container to read from.
  /// - Returns: The decoded `HeartbeatInfo` that is loaded from storage.
  private func load(from storage: Storage) throws -> HeartbeatInfo {
    let data = try storage.read()
    let heartbeatData = try data.decoded(using: decoder) as HeartbeatInfo
    return heartbeatData
  }

  /// Saves the encoding of the given value to the given storage container.
  /// - Parameters:
  ///   - heartbeatInfo: The heartbeat info to encode and save.
  ///   - storage: The storage container to write to.
  private func save(_ heartbeatInfo: HeartbeatInfo?, to storage: Storage) throws {
    if let heartbeatInfo = heartbeatInfo {
      let data = try heartbeatInfo.encoded(using: encoder)
      try storage.write(data)
    } else {
      try storage.write(nil)
    }
  }
}

private extension Data {
  /// Returns the decoded value of this `Data` using the given decoder. Defaults to `JSONDecoder`.
  /// - Returns: The decoded value.
  func decoded<T>(using decoder: JSONDecoder = .init()) throws -> T where T: Decodable {
    try decoder.decode(T.self, from: self)
  }
}

private extension Encodable {
  /// Returns the `Data` encoding of this value using the given encoder.
  /// - Parameter encoder: An encoder used to encode the value. Defaults to `JSONEncoder`.
  /// - Returns: The data encoding of the value.
  func encoded(using encoder: JSONEncoder = .init()) throws -> Data {
    try encoder.encode(self)
  }
}
