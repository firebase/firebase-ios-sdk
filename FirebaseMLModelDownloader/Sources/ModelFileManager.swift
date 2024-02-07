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

/// Manager for common file operations.
enum ModelFileManager {
  /// Separator in model file name components.
  private static let nameSeparator = "@@"

  private static let modelNamePrefix = "fbml_model"

  private static let fileExtension = "tflite"

  private static let fileManager = FileManager.default

  /// Root directory of model file storage on device.
  static var modelsDirectory: URL? {
    let rootDirOptional: URL? = {
      #if os(tvOS)
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
      #else
        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? nil
      #endif
    }()

    guard let rootDirURL = rootDirOptional else {
      return nil
    }

    let modelDirURL = rootDirURL.appendingPathComponent(
      "com.firebase.FirebaseMLModelDownloader",
      isDirectory: true
    )

    do {
      if !fileManager.fileExists(atPath: modelDirURL.absoluteString) {
        try fileManager.createDirectory(at: modelDirURL, withIntermediateDirectories: true)
      }
    } catch {
      return nil
    }

    return modelDirURL
  }

  /// Name for model file stored on device.
  static func getDownloadedModelFileName(appName: String, modelName: String) -> String {
    return [modelNamePrefix, appName, modelName].joined(separator: nameSeparator)
  }

  /// Model name from file path.
  static func getModelNameFromFilePath(_ path: URL) -> String? {
    let components = path.deletingPathExtension().lastPathComponent
      .components(separatedBy: nameSeparator)
    // The file name should have prefix, app name, and model name.
    if components.count == 3 {
      return components.last
    }
    return nil
  }

  /// Full path of model file stored on device.
  static func getDownloadedModelFileURL(appName: String, modelName: String) -> URL? {
    let modelFileName = ModelFileManager.getDownloadedModelFileName(
      appName: appName,
      modelName: modelName
    )
    guard let modelsDir = ModelFileManager.modelsDirectory else { return nil }
    return modelsDir.appendingPathComponent(modelFileName).appendingPathExtension(fileExtension)
  }

  /// Check if file is available at URL.
  static func isFileReachable(at fileURL: URL) -> Bool {
    do {
      return try fileURL.checkResourceIsReachable()
    } catch {
      // File unreachable.
      return false
    }
  }

  /// Move file at a location to another location.
  static func moveFile(at sourceURL: URL, to destinationURL: URL, size: Int64) throws {
    if isFileReachable(at: destinationURL) {
      do {
        try fileManager.removeItem(at: destinationURL)
      } catch {
        // TODO: Handle this - new model file downloaded but not saved due to FileManager error.
        throw DownloadError
          .internalError(
            description: ModelFileManager.ErrorDescription
              .replaceFile(error.localizedDescription)
          )
      }
    }
    do {
      try fileManager.moveItem(at: sourceURL, to: destinationURL)
    } catch CocoaError.fileWriteOutOfSpace {
      throw DownloadError.notEnoughSpace
    } catch {
      throw DownloadError
        .internalError(description: ModelFileManager
          .ErrorDescription.saveFile(error.localizedDescription))
    }
  }

  /// Remove model file at a specific location.
  static func removeFile(at url: URL) throws {
    do {
      try fileManager.removeItem(at: url)
    } catch {
      throw DownloadedModelError
        .internalError(
          description: ModelFileManager.ErrorDescription.deleteFile(error.localizedDescription)
        )
    }
  }

  /// Get all model files in models directory.
  static func contentsOfModelsDirectory() throws -> [URL] {
    guard let modelsDir = modelsDirectory else {
      throw DownloadedModelError
        .internalError(
          description: ModelFileManager.ErrorDescription.noApplicationSupportDirectory
        )
    }
    do {
      let directoryContents = try ModelFileManager.fileManager.contentsOfDirectory(
        at: modelsDir,
        includingPropertiesForKeys: nil,
        options: .skipsHiddenFiles
      )
      return directoryContents.filter { directoryItem in
        directoryItem.path.contains(ModelFileManager.modelNamePrefix) && !directoryItem
          .hasDirectoryPath
      }
    } catch {
      throw DownloadedModelError
        .internalError(
          description: ModelFileManager.ErrorDescription
            .retrieveFile(error.localizedDescription)
        )
    }
  }
}

/// NOTE: Use for testing only.
extension ModelFileManager {
  static func emptyModelsDirectory() throws {
    do {
      let directoryContents = try ModelFileManager.contentsOfModelsDirectory()
      for path in directoryContents {
        try ModelFileManager.removeFile(at: path)
      }
    } catch {
      throw DownloadedModelError
        .internalError(
          description: ModelFileManager.ErrorDescription
            .emptyDirectory(error.localizedDescription)
        )
    }
  }
}

/// Possible error messages during file management.
extension ModelFileManager {
  /// Error descriptions.
  private enum ErrorDescription {
    static let retrieveFile = { (error: String) in
      "Could not retrieve model files in directory: \(error)"
    }

    static let deleteFile = { (error: String) in
      "Could not delete old model file: \(error)"
    }

    static let saveFile = { (error: String) in
      "Unable to save model file: \(error)"
    }

    static let replaceFile = { (error: String) in
      "Could not replace existing model file: \(error)"
    }

    static let availableStorage = { (error: String?) -> String in
      if let error {
        return "Failed to check storage capacity on device: \(error)"
      } else {
        return "Failed to check storage capacity on device."
      }
    }

    static let noApplicationSupportDirectory =
      "Could not locate Application Support directory for model storage."

    static let emptyDirectory = { (error: String) in
      "Could not empty models directory: \(error)"
    }
  }
}
