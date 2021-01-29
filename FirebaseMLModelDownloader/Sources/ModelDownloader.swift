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
public enum DownloadedModelError: Error {
  /// File system error.
  case fileIOError(description: String)
  /// Model not found on device.
  case notFound
  /// Other errors with description.
  case internalError(description: String)
}

/// Extension to handle internally meaningful errors.
extension DownloadError {
  static let expiredDownloadURL: DownloadError = {
    DownloadError.internalError(description: "Expired model download URL.")
  }()
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
  /// Telemetry logger tied to this instance of model downloader.
  let telemetryLogger: TelemetryLogger?
  /// Number of retries in case of model download URL expiry.
  var numberOfRetries: Int = 1
  /// Handler that always runs on the main thread
  let mainQueueHandler = { handler in
    DispatchQueue.main.async {
      handler
    }
  }

  /// Shared dictionary mapping app name to a specific instance of model downloader.
  // TODO: Switch to using Firebase components.
  private static var modelDownloaderDictionary: [String: ModelDownloader] = [:]

  /// Private init for downloader.
  private init(app: FirebaseApp, defaults: UserDefaults = .firebaseMLDefaults) {
    appName = app.name
    options = app.options
    installations = Installations.installations(app: app)
    /// Respect Firebase-wide data collection setting.
    telemetryLogger = TelemetryLogger(app: app)
    userDefaults = defaults

    let notificationName = "FIRAppDeleteNotification"
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(deleteModelDownloader),
      name: Notification.Name(notificationName),
      object: nil
    )
  }

  /// Handles app deletion notification.
  @objc private func deleteModelDownloader(notification: Notification) {
    let userInfoKey = "FIRAppNameKey"
    if let userInfo = notification.userInfo,
      let appName = userInfo[userInfoKey] as? String {
      ModelDownloader.modelDownloaderDictionary.removeValue(forKey: appName)
      // TODO: Clean up user defaults
      // TODO: Clean up local instances of app
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.DebugDescription.deleteModelDownloader,
                            messageCode: .downloaderInstanceDeleted)
    }
  }

  /// Model downloader with default app.
  public static func modelDownloader() -> ModelDownloader {
    guard let defaultApp = FirebaseApp.app() else {
      fatalError(ModelDownloader.ErrorDescription.defaultAppNotConfigured)
    }
    return modelDownloader(app: defaultApp)
  }

  /// Model Downloader with custom app.
  public static func modelDownloader(app: FirebaseApp) -> ModelDownloader {
    if let downloader = modelDownloaderDictionary[app.name] {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.DebugDescription.retrieveModelDownloader,
                            messageCode: .downloaderInstanceRetrieved)
      return downloader
    } else {
      let downloader = ModelDownloader(app: app)
      modelDownloaderDictionary[app.name] = downloader
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.DebugDescription.createModelDownloader,
                            messageCode: .downloaderInstanceCreated)
      return downloader
    }
  }

  /// Downloads a custom model to device or gets a custom model already on device, w/ optional handler for progress.
  public func getModel(name modelName: String,
                       downloadType: ModelDownloadType,
                       conditions: ModelDownloadConditions,
                       progressHandler: ((Float) -> Void)? = nil,
                       completion: @escaping (Result<CustomModel, DownloadError>) -> Void) {
    switch downloadType {
    case .localModel:
      if let localModel = getLocalModel(modelName: modelName) {
        DeviceLogger.logEvent(level: .debug,
                              message: ModelDownloader.DebugDescription.localModelFound,
                              messageCode: .localModelFound)
        mainQueueHandler(completion(.success(localModel)))
      } else {
        getRemoteModel(
          modelName: modelName,
          conditions: conditions,
          progressHandler: progressHandler,
          completion: completion
        )
      }
    case .localModelUpdateInBackground:
      if let localModel = getLocalModel(modelName: modelName) {
        DeviceLogger.logEvent(level: .debug,
                              message: ModelDownloader.DebugDescription.localModelFound,
                              messageCode: .localModelFound)
        mainQueueHandler(completion(.success(localModel)))
        telemetryLogger?.logModelDownloadEvent(
          eventName: .modelDownload,
          status: .scheduled,
          downloadErrorCode: .noError
        )
        DispatchQueue.global(qos: .utility).async { [weak self] in
          self?.getRemoteModel(
            modelName: modelName,
            conditions: conditions,
            progressHandler: nil,
            completion: { result in
              switch result {
              case let .success(model):
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelDownloader.DebugDescription
                                        .backgroundModelDownloaded,
                                      messageCode: .backgroundModelDownloaded)
                self?.telemetryLogger?.logModelDownloadEvent(
                  eventName: .modelDownload,
                  status: .succeeded,
                  model: model,
                  downloadErrorCode: .noError
                )
              case .failure:
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelDownloader.ErrorDescription
                                        .backgroundModelDownload,
                                      messageCode: .backgroundDownloadError)
                self?.telemetryLogger?.logModelDownloadEvent(
                  eventName: .modelDownload,
                  status: .failed,
                  downloadErrorCode: .downloadFailed
                )
              }
            }
          )
        }
      } else {
        getRemoteModel(
          modelName: modelName,
          conditions: conditions,
          progressHandler: progressHandler,
          completion: completion
        )
      }

    case .latestModel:
      getRemoteModel(
        modelName: modelName,
        conditions: conditions,
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
          let description = ModelDownloader.ErrorDescription.parseModelName(path.absoluteString)
          DeviceLogger.logEvent(level: .debug,
                                message: description,
                                messageCode: .modelNameParseError)
          mainQueueHandler(completion(.failure(.internalError(description: description))))
          return
        }
        guard let modelInfo = getLocalModelInfo(modelName: modelName) else {
          let description = ModelDownloader.ErrorDescription.noLocalModelInfo(modelName)
          DeviceLogger.logEvent(level: .debug,
                                message: description,
                                messageCode: .noLocalModelInfo)
          mainQueueHandler(completion(.failure(.internalError(description: description))))
          return
        }
        guard modelInfo.path == path.absoluteString else {
          DeviceLogger.logEvent(level: .debug,
                                message: ModelDownloader.ErrorDescription.outdatedModelPath,
                                messageCode: .outdatedModelPathError)
          mainQueueHandler(completion(.failure(.internalError(description: ModelDownloader
              .ErrorDescription.outdatedModelPath))))
          return
        }
        let model = CustomModel(localModelInfo: modelInfo)
        customModels.insert(model)
      }
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.DebugDescription.allLocalModelsFound,
                            messageCode: .allLocalModelsFound)
      completion(.success(customModels))
    } catch let error as DownloadedModelError {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.ErrorDescription.listModelsFailed(error),
                            messageCode: .listModelsError)
      mainQueueHandler(completion(.failure(error)))
    } catch {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.ErrorDescription.listModelsFailed(error),
                            messageCode: .listModelsError)
      mainQueueHandler(completion(.failure(.internalError(description: error
          .localizedDescription))))
    }
  }

  /// Deletes a custom model from device.
  public func deleteDownloadedModel(name modelName: String,
                                    completion: @escaping (Result<Void, DownloadedModelError>)
                                      -> Void) {
    guard let localModelInfo = getLocalModelInfo(modelName: modelName),
      let localPath = URL(string: localModelInfo.path)
    else {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.ErrorDescription.modelNotFound(modelName),
                            messageCode: .modelNotFound)
      mainQueueHandler(completion(.failure(.notFound)))
      return
    }
    do {
      try ModelFileManager.removeFile(at: localPath)
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.DebugDescription.modelDeleted,
                            messageCode: .modelDeleted)
      mainQueueHandler(completion(.success(())))
    } catch let error as DownloadedModelError {
      mainQueueHandler(completion(.failure(error)))
    } catch {
      mainQueueHandler(completion(.failure(.internalError(description: error
          .localizedDescription))))
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
      let description = ModelDownloader.DebugDescription.noLocalModelInfo(modelName)
      DeviceLogger.logEvent(level: .debug,
                            message: description,
                            messageCode: .noLocalModelInfo)
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
                              conditions: ModelDownloadConditions,
                              progressHandler: ((Float) -> Void)? = nil,
                              completion: @escaping (Result<CustomModel, DownloadError>) -> Void) {
    let localModelInfo = getLocalModelInfo(modelName: modelName)
    guard let projectID = options.projectID, let apiKey = options.apiKey else {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.ErrorDescription.invalidOptions,
                            messageCode: .invalidOptions)
      completion(.failure(.internalError(description: ModelDownloader.ErrorDescription
          .invalidOptions)))
      return
    }
    let modelInfoRetriever = ModelInfoRetriever(
      modelName: modelName,
      projectID: projectID,
      apiKey: apiKey,
      installations: installations,
      appName: appName,
      localModelInfo: localModelInfo,
      telemetryLogger: telemetryLogger
    )

    let downloader = ModelFileDownloader(conditions: conditions)
    downloadInfoAndModel(
      modelName: modelName,
      modelInfoRetriever: modelInfoRetriever,
      downloader: downloader,
      conditions: conditions,
      progressHandler: progressHandler,
      completion: completion
    )
  }

  func downloadInfoAndModel(modelName: String,
                            modelInfoRetriever: ModelInfoRetriever,
                            downloader: FileDownloader,
                            conditions: ModelDownloadConditions,
                            progressHandler: ((Float) -> Void)? = nil,
                            completion: @escaping (Result<CustomModel, DownloadError>)
                              -> Void) {
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
            downloader: downloader,
            telemetryLogger: self.telemetryLogger
          )
          downloadTask.download(progressHandler: { progress in
            if let progressHandler = progressHandler {
              self.mainQueueHandler(progressHandler(progress))
            }
          }) { result in
            switch result {
            case let .success(model):
              self.mainQueueHandler(completion(.success(model)))
            case let .failure(error):
              switch error {
              case .notFound:
                self.mainQueueHandler(completion(.failure(.notFound)))
              case .invalidArgument:
                self.mainQueueHandler(completion(.failure(.invalidArgument)))
              case .permissionDenied:
                self.mainQueueHandler(completion(.failure(.permissionDenied)))
              /// This is the error returned when URL expired.
              case .expiredDownloadURL:
                /// Check if retries are allowed.
                guard self.numberOfRetries > 0 else {
                  self
                    .mainQueueHandler(
                      completion(.failure(.internalError(description: ModelDownloader
                          .ErrorDescription
                          .expiredModelInfo)))
                    )
                  return
                }
                self.numberOfRetries -= 1
                DeviceLogger.logEvent(level: .debug,
                                      message: ModelDownloader.DebugDescription.retryDownload,
                                      messageCode: .retryDownload)
                self.downloadInfoAndModel(
                  modelName: modelName,
                  modelInfoRetriever: modelInfoRetriever,
                  downloader: downloader,
                  conditions: conditions,
                  progressHandler: progressHandler,
                  completion: completion
                )
              default:
                self.mainQueueHandler(completion(.failure(error)))
              }
            }
          }
        /// Local model info is the latest model info.
        case .notModified:
          guard let localModel = self.getLocalModel(modelName: modelName) else {
            /// This can only happen if either local model info or the model file was suddenly wiped out in the middle of model info request and server response
            // TODO: Consider handling: If model file is deleted after local model info is retrieved but before model info network call.
            self
              .mainQueueHandler(completion(.failure(.internalError(description: ModelDownloader
                  .ErrorDescription.deletedLocalModelInfo))))
            return
          }

          self.mainQueueHandler(completion(.success(localModel)))
        }
      case let .failure(error):
        self.mainQueueHandler(completion(.failure(error)))
      }
    }
  }
}

/// Model downloader extension for testing.
extension ModelDownloader {
  /// Model downloader instance for testing.
  static func modelDownloaderWithDefaults(_ defaults: UserDefaults,
                                          app: FirebaseApp) -> ModelDownloader {
    if let downloader = modelDownloaderDictionary[app.name] {
      return downloader
    } else {
      let downloader = ModelDownloader(app: app, defaults: defaults)
      modelDownloaderDictionary[app.name] = downloader
      return downloader
    }
  }
}

/// Possible error messages while using model downloader.
extension ModelDownloader {
  /// Debug descriptions.
  private enum DebugDescription {
    static let deleteModelDownloader = "Model downloader instance deleted due to app deletion."
    static let retrieveModelDownloader =
      "Initialized with existing downloader instance associated with this app."
    static let createModelDownloader =
      "Initialized with new downloader instance associated with this app."
    static let localModelFound = "Found local model on device."
    static let backgroundModelDownloaded = "Downloaded latest model in the background."
    static let allLocalModelsFound = "Found and listed all local models."
    static let modelDeleted = "Model deleted successfully."
    static let retryDownload = "Retrying download."
    static let noLocalModelInfo = { (name: String) in
      "No local model info for model file named: \(name)."
    }
  }

  /// Error descriptions.
  private enum ErrorDescription {
    static let defaultAppNotConfigured =
      "Default Firebase app not configured."
    static let parseModelName = { (path: String) in
      "List models failed due to unexpected model file name at \(path)."
    }

    static let invalidOptions = "Unable to retrieve project ID and/or API key for Firebase app."

    static let listModelsFailed = { (error: Error) in
      "Unable to list models, failed with error: \(error)"
    }

    static let modelNotFound = { (name: String) in
      "Model deletion failed due to no model found with name: \(name)"
    }

    static let noLocalModelInfo = { (name: String) in
      "List models failed due to no local model info for model file named: \(name)."
    }

    static let modelDownloadFailed = { (error: Error) in
      "Model download failed with error: \(error)"
    }

    static let modelInfoRetrievalFailed = { (error: Error) in
      "Model info retrieval failed with error: \(error)"
    }

    static let outdatedModelPath =
      "List models failed due to outdated model paths in local storage."
    static let deletedLocalModelInfo =
      "Model unavailable due to deleted local model info."
    static let backgroundModelDownload =
      "Failed to update model in background."
    static let expiredModelInfo = "Unable to update expired model info."
  }
}
