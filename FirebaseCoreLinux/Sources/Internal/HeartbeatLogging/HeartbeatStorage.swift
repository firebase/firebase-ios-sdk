import Foundation

/// A type that can perform atomic operations using block-based transformations.
protocol HeartbeatStorageProtocol: Sendable {
  func readAndWriteSync(using transform: (HeartbeatsBundle?) -> HeartbeatsBundle?)
  func readAndWriteAsync(using transform: @escaping @Sendable (HeartbeatsBundle?) -> HeartbeatsBundle?)
  func getAndSet(using transform: (HeartbeatsBundle?) -> HeartbeatsBundle?) throws -> HeartbeatsBundle?
  func getAndSetAsync(using transform: @escaping @Sendable (HeartbeatsBundle?) -> HeartbeatsBundle?,
                      completion: @escaping @Sendable (Result<HeartbeatsBundle?, Error>) -> Void)
}

final class HeartbeatStorage: Sendable, HeartbeatStorageProtocol {
  private let id: String
  private let storage: any Storage
  private let encoder: JSONEncoder = .init()
  private let decoder: JSONDecoder = .init()
  private let queue: DispatchQueue

  init(id: String, storage: Storage) {
    self.id = id
    self.storage = storage
    queue = DispatchQueue(label: "com.heartbeat.storage.\(id)")
  }

  // MARK: - Instance Management

  private static let cachedInstances: UnfairLock<[String: WeakContainer<HeartbeatStorage>]> = UnfairLock([:])

  static func getInstance(id: String) -> HeartbeatStorage {
    cachedInstances.withLock { cachedInstances in
      if let cachedInstance = cachedInstances[id]?.object {
        return cachedInstance
      } else {
        let newInstance = HeartbeatStorage.makeHeartbeatStorage(id: id)
        cachedInstances[id] = WeakContainer(object: newInstance)
        return newInstance
      }
    }
  }

  private static func makeHeartbeatStorage(id: String) -> HeartbeatStorage {
    // Assuming StorageFactory handles platform specifics
    // We need to access StorageFactory implementations.
    // In StorageFactory.swift, I extended FileStorage and UserDefaultsStorage to conform to StorageFactory.
    // But `makeStorage` is static on the type.

    // Always use FileStorage for Linux target to ensure compatibility
    let storage = FileStorage.makeStorage(id: id)
    return HeartbeatStorage(id: id, storage: storage)
  }

  deinit {
    // Need to capture id in closure if accessing self?
    // But withLock takes inout.
    // self.id is immutable.
    let id = self.id
    Self.cachedInstances.withLock { value in
      value.removeValue(forKey: id)
    }
  }

  // MARK: - HeartbeatStorageProtocol

  func readAndWriteSync(using transform: (HeartbeatsBundle?) -> HeartbeatsBundle?) {
    queue.sync {
      let oldHeartbeatsBundle = try? load(from: storage)
      let newHeartbeatsBundle = transform(oldHeartbeatsBundle)
      try? save(newHeartbeatsBundle, to: storage)
    }
  }

  func readAndWriteAsync(using transform: @escaping @Sendable (HeartbeatsBundle?) -> HeartbeatsBundle?) {
    queue.async { [self] in
      let oldHeartbeatsBundle = try? load(from: storage)
      let newHeartbeatsBundle = transform(oldHeartbeatsBundle)
      try? save(newHeartbeatsBundle, to: storage)
    }
  }

  @discardableResult
  func getAndSet(using transform: (HeartbeatsBundle?) -> HeartbeatsBundle?) throws -> HeartbeatsBundle? {
    let heartbeatsBundle: HeartbeatsBundle? = try queue.sync {
      let oldHeartbeatsBundle = try? load(from: storage)
      let newHeartbeatsBundle = transform(oldHeartbeatsBundle)
      try save(newHeartbeatsBundle, to: storage)
      return oldHeartbeatsBundle
    }
    return heartbeatsBundle
  }

  func getAndSetAsync(using transform: @escaping @Sendable (HeartbeatsBundle?) -> HeartbeatsBundle?,
                      completion: @escaping @Sendable (Result<HeartbeatsBundle?, Error>) -> Void) {
    queue.async {
      do {
        let oldHeartbeatsBundle = try? self.load(from: self.storage)
        let newHeartbeatsBundle = transform(oldHeartbeatsBundle)
        try self.save(newHeartbeatsBundle, to: self.storage)
        completion(.success(oldHeartbeatsBundle))
      } catch {
        completion(.failure(error))
      }
    }
  }

  private func load(from storage: Storage) throws -> HeartbeatsBundle? {
    let data = try storage.read()
    if data.isEmpty {
      return nil
    } else {
      return try decoder.decode(HeartbeatsBundle.self, from: data)
    }
  }

  private func save(_ heartbeatsBundle: HeartbeatsBundle?, to storage: Storage) throws {
    if let heartbeatsBundle {
      let data = try encoder.encode(heartbeatsBundle)
      try storage.write(data)
    } else {
      try storage.write(nil)
    }
  }
}
