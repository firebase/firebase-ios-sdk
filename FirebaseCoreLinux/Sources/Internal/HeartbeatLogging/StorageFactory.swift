import Foundation

private enum Constants {
  static let heartbeatFileStorageDirectoryPath = "google-heartbeat-storage"
  static let heartbeatUserDefaultsSuiteName = "com.google.heartbeat.storage"
}

protocol StorageFactory {
  static func makeStorage(id: String) -> Storage
}

// MARK: - FileStorage + StorageFactory

extension FileStorage: StorageFactory {
  static func makeStorage(id: String) -> Storage {
    let rootDirectory = FileManager.default.applicationSupportDirectory
    let heartbeatDirectoryPath = Constants.heartbeatFileStorageDirectoryPath
    let sanitizedID = id.replacingOccurrences(of: ":", with: "_")
    let heartbeatFilePath = "heartbeats-\(sanitizedID)"

    let storageURL = rootDirectory
      .appendingPathComponent(heartbeatDirectoryPath, isDirectory: true)
      .appendingPathComponent(heartbeatFilePath, isDirectory: false)

    return FileStorage(url: storageURL)
  }
}

extension FileManager {
  var applicationSupportDirectory: URL {
    // If .applicationSupportDirectory fails on Linux, fallback to .documentDirectory or similar?
    // But it should be fine.
    let urls = urls(for: .applicationSupportDirectory, in: .userDomainMask)
    if let url = urls.first {
        return url
    }
    // Fallback logic for Linux if needed (e.g. ~/.local/share)
    return URL(fileURLWithPath: ".")
  }
}

// MARK: - UserDefaultsStorage + StorageFactory

extension UserDefaultsStorage: StorageFactory {
  static func makeStorage(id: String) -> Storage {
    let suiteName = Constants.heartbeatUserDefaultsSuiteName
    let key = "heartbeats-\(id)"
    return UserDefaultsStorage(suiteName: suiteName, key: key)
  }
}
