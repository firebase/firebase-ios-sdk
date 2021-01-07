// Copyright 2020 Google LLC
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
import FirebaseCore
import FirebaseInstallations

/// Possible errors with model downloading.
public enum DownloadError: Error, Equatable {
  /// No model with this name found on server.
  case notFound
  /// Caller does not have necessary permissions for this operation.
  case permissionDenied
  /// Conditions not met to perform download.
  case failedPrecondition
  /// Not enough space for model on device.
  case notEnoughSpace
  /// Malformed model name.
  case invalidArgument
  /// Other errors with description.
  case internalError(description: String)
}

/// Possible errors with locating model on device.
public enum DownloadedModelError: Error, Equatable {
  /// File system error.
  case fileIOError(description: String)
  /// Model not found on device.
  case notFound
  /// Other errors with description.
  case internalError(description: String)
}

/// Possible ways to get a custom model.
public enum ModelDownloadType {
  /// Get local model stored on device.
  case localModel
  /// Get local model on device and update to latest model from server in the background.
  case localModelUpdateInBackground
  /// Get latest model from server.
  case latestModel
}

/// Downloader to manage custom model downloads.
public class ModelDownloader {
  /// Name of the app associated with this instance of ModelDownloader.
  private let appName: String
  /// Current Firebase app options.
  private let options: FirebaseOptions
  /// Installations instance for current Firebase app.
  private let installations: Installations
  /// User defaults for model info.
  private let userDefaults: UserDefaults

  /// Shared dictionary mapping app name to a specific instance of model downloader.
  // TODO: Switch to using Firebase components.
  private static var modelDownloaderDictionary: [String: ModelDownloader] = [:]

  /// Private init for downloader.
  private init(app: FirebaseApp, defaults: UserDefaults = .firebaseMLDefaults) {
    appName = app.name
    options = app.options
    installations = Installations.installations(app: app)
    userDefaults = defaults

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(deleteModelDownloader),
      name: Notification.Name("FIRAppDeleteNotification"),
      object: nil
    )
  }

  /// Handles app deletion notification.
  @objc private func deleteModelDownloader(notification: Notification) {
    if let userInfo = notification.userInfo,
      let appName = userInfo["FIRAppNameKey"] as? String {
      ModelDownloader.modelDownloaderDictionary.removeValue(forKey: appName)
      // TODO: Clean up user defaults
      // TODO: Clean up local instances of app
    }
  }

  /// Model downloader with default app.
  public static func modelDownloader() -> ModelDownloader {
    guard let defaultApp = FirebaseApp.app() else {
      fatalError("Default Firebase app not configured.")
    }
    return modelDownloader(app: defaultApp)
  }

  /// Model Downloader with custom app.
  public static func modelDownloader(app: FirebaseApp) -> ModelDownloader {
    if let downloader = modelDownloaderDictionary[app.name] {
      return downloader
    } else {
      let downloader = ModelDownloader(app: app)
      modelDownloaderDictionary[app.name] = downloader
      return downloader
    }
  }

  /// Model downloader instance for testing.
  // TODO: Consider using protocols
  static func modelDownloader(app: FirebaseApp, defaults: UserDefaults) -> ModelDownloader {
    if let downloader = modelDownloaderDictionary[app.name] {
      return downloader
    } else {
      let downloader = ModelDownloader(app: app, defaults: defaults)
      modelDownloaderDictionary[app.name] = downloader
      return downloader
    }
  }

  /// Downloads a custom model to device or gets a custom model already on device, w/ optional handler for progress.
  public func getModel(name modelName: String, downloadType: ModelDownloadType,
                       conditions: ModelDownloadConditions,
                       progressHandler: ((Float) -> Void)? = nil,
                       completion: @escaping (Result<CustomModel, DownloadError>) -> Void) {
    switch downloadType {
    case .localModel:
      if let localModel = getLocalModel(modelName: modelName) {
        DispatchQueue.main.async {
          completion(.success(localModel))
        }
      } else {
        getRemoteModel(
          modelName: modelName,
          progressHandler: progressHandler,
          completion: completion
        )
      }
    case .localModelUpdateInBackground:
      if let localModel = getLocalModel(modelName: modelName) {
        DispatchQueue.main.async {
          completion(.success(localModel))
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
          self?.getRemoteModel(
            modelName: modelName,
            progressHandler: nil,
            completion: { result in
              switch result {
              // TODO: Log outcome of background download
              case .success: break
              case .failure: break
              }
            }
          )
        }
      } else {
        getRemoteModel(
          modelName: modelName,
          progressHandler: progressHandler,
          completion: completion
        )
      }

    case .latestModel:
      getRemoteModel(
        modelName: modelName,
        progressHandler: progressHandler,
        completion: completion
      )
    }
  }

  /// Gets all downloaded models.
  public func listDownloadedModels(completion: @escaping (Result<Set<CustomModel>,
    DownloadedModelError>) -> Void) {
    do {
      let modelPaths = try ModelFileManager.contentsOfModelsDirectory()
      var customModels = Set<CustomModel>()
      for path in modelPaths {
        guard let modelName = ModelFileManager.getModelNameFromFilePath(path) else {
          completion(.failure(.internalError(description: "Invalid model file name.")))
          return
        }
        guard let modelInfo = getLocalModelInfo(modelName: modelName) else {
          completion(
            .failure(.internalError(description: "Failed to get model info for model file."))
          )
          return
        }
        guard modelInfo.path == path.absoluteString else {
          completion(
            .failure(.internalError(description: "Outdated model paths in local storage."))
          )
          return
        }
        let model = CustomModel(localModelInfo: modelInfo)
        customModels.insert(model)
      }
      completion(.success(customModels))
    } catch let error as DownloadedModelError {
      completion(.failure(error))
    } catch {
      completion(.failure(.internalError(description: error.localizedDescription)))
    }
  }

  /// Deletes a custom model from device.
  public func deleteDownloadedModel(name modelName: String,
                                    completion: @escaping (Result<Void, DownloadedModelError>)
                                      -> Void) {
    // TODO: Delete previously downloaded model
    guard let localModelInfo = getLocalModelInfo(modelName: modelName),
      let localPath = URL(string: localModelInfo.path)
    else {
      completion(.failure(.notFound))
      return
    }
    do {
      try ModelFileManager.removeFile(at: localPath)
      completion(.success(()))
    } catch let error as DownloadedModelError {
      completion(.failure(error))
    } catch {
      completion(.failure(.internalError(description: error.localizedDescription)))
    }
  }
}

extension ModelDownloader {
  /// Return local model info only if the model info is available and the corresponding model file is already on device.
  private func getLocalModelInfo(modelName: String) -> LocalModelInfo? {
    guard let localModelInfo = LocalModelInfo(
      fromDefaults: userDefaults,
      name: modelName,
      appName: appName
    ) else {
      return nil
    }
    /// There is local model info on device, but no model file at the expected path.
    guard let localPath = URL(string: localModelInfo.path),
      ModelFileManager.isFileReachable(at: localPath) else {
      // TODO: Consider deleting local model info in user defaults.
      return nil
    }
    return localModelInfo
  }

  /// Get model saved on device if available.
  private func getLocalModel(modelName: String) -> CustomModel? {
    guard let localModelInfo = getLocalModelInfo(modelName: modelName) else { return nil }
    let model = CustomModel(localModelInfo: localModelInfo)
    return model
  }

  /// Download and get model from server, unless the latest model is already available on device.
  private func getRemoteModel(modelName: String,
                              progressHandler: ((Float) -> Void)? = nil,
                              completion: @escaping (Result<CustomModel, DownloadError>) -> Void) {
    let localModelInfo = getLocalModelInfo(modelName: modelName)
    let modelInfoRetriever = ModelInfoRetriever(
      modelName: modelName,
      options: options,
      installations: installations,
      appName: appName,
      localModelInfo: localModelInfo
    )
    modelInfoRetriever.downloadModelInfo { result in
      switch result {
      case let .success(downloadModelInfoResult):
        switch downloadModelInfoResult {
        /// New model info was downloaded from server.
        case let .modelInfo(remoteModelInfo):
          let downloadTask = ModelDownloadTask(
            remoteModelInfo: remoteModelInfo,
            appName: self.appName,
            defaults: self.userDefaults,
            progressHandler: progressHandler,
            completion: completion
          )
          downloadTask.resumeModelDownload()
        /// Local model info is the latest model info.
        case .notModified:
          guard let localModel = self.getLocalModel(modelName: modelName) else {
            DispatchQueue.main.async {
              /// This can only happen if either local model info or the model file was suddenly wiped out in the middle of model info request and server response
              // TODO: Consider handling: if model file is deleted after local model info is retrieved but before model info network call
              completion(
                .failure(
                  .internalError(description: "Model unavailable due to deleted local model info.")
                )
              )
            }
            return
          }

          DispatchQueue.main.async {
            completion(.success(localModel))
          }
        }
      case let .failure(downloadError):
        DispatchQueue.main.async {
          completion(.failure(downloadError))
        }
      }
    }
  }
}
