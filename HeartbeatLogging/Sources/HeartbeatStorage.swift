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

protocol HeartbeatStorageProtocol {
  typealias HeartbeatInfoTransform = (HeartbeatInfo?) -> HeartbeatInfo?

  func async(_ transform: @escaping HeartbeatInfoTransform)
  // TODO: Evaluate if async variant of below API is needed.
  func getAndReset(using transform: HeartbeatInfoTransform?) throws -> HeartbeatInfo?
}

/// Thread-safe storage object designed for storing heartbeat data.
final class HeartbeatStorage: HeartbeatStorageProtocol {
  // The identifier used to differentiate instances.
  private let id: String
  // The underlying storage container to read from and write to.
  private let storage: Storage
  // An object used to encode and decode Codable heartbeat data.
  private let coder: Coder
  // The queue for synchronizing storage operations.
  private let queue: DispatchQueue

  init(id: String,
       storage: Storage,
       coder: Coder = JSONCoder(),
       queue: DispatchQueue? = nil) {
    self.id = id
    self.storage = storage
    self.coder = coder
    self.queue = queue ?? DispatchQueue(label: "com.heartbeat.storage.\(id)")
  }

  // MARK: - Instance Management

  // TODO: Add tests for instance management.

  /// <#Description#>
  static var cachedInstances: [String: Weak<HeartbeatStorage>] = [:]

  /// <#Description#>
  /// - Parameter id: <#id description#>
  /// - Returns: <#description#>
  static func getInstance(id: String) -> HeartbeatStorage {
    if let cachedInstance = cachedInstances[id]?.object {
      return cachedInstance
    } else {
      return HeartbeatStorage.makeStorage(id: id)
    }
  }

  deinit {
    // Removes the instance if it was cached.
    Self.cachedInstances.removeValue(forKey: id)
  }

  // MARK: - HeartbeatStorageProtocol

  func async(_ transform: @escaping HeartbeatInfoTransform) {
    queue.async { [self] in
      let oldHeartbeatInfo = try? load(from: storage)
      let newHeartbeatInfo = transform(oldHeartbeatInfo)
      try? save(newHeartbeatInfo, to: storage)
    }
  }

  @discardableResult
  func getAndReset(using transform: HeartbeatInfoTransform? = nil) throws -> HeartbeatInfo? {
    let heartbeatInfo: HeartbeatInfo? = try queue.sync {
      let oldHeartbeatInfo = try? load(from: storage)
      let newHeartbeatInfo = transform?(oldHeartbeatInfo)
      try save(newHeartbeatInfo, to: storage)
      return oldHeartbeatInfo
    }
    return heartbeatInfo
  }

  private func load(from storage: Storage) throws -> HeartbeatInfo {
    let data = try storage.read()
    let heartbeatData = try coder.decode(HeartbeatInfo.self, from: data)
    return heartbeatData
  }

  private func save(_ value: HeartbeatInfo?, to storage: Storage) throws {
    if let value = value {
      let data = try coder.encode(value)
      try storage.write(data)
    } else {
      try storage.write(nil)
    }
  }
}

// MARK: - HeartbeatStorage + StorageFactory

extension HeartbeatStorage: StorageFactory {
  /// Makes a `Storage` instance using a given `String` identifier.
  ///
  /// The created persistent storage object is platform dependent. For tvOS, user defaults
  /// is used as the underlying storage container due to system storage limits. For all other platforms,
  /// the file system is used.
  ///
  /// - Parameter id: A `String` identifier used to create the `Storage`.
  /// - Returns: A `Storage` instance.
  static func makeStorage(id: String) -> Self {
    #if os(tvOS)
      let storage = UserDefaultsStorage.makeStorage(id: id)
    #else
      let storage = FileStorage.makeStorage(id: id)
    #endif // os(tvOS)
    return .init(id: id, storage: storage)
  }
}
