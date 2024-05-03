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

import FirebaseCore
import FirebaseInstallations
import Foundation
#if SWIFT_PACKAGE
  @_implementationOnly import GoogleUtilities_UserDefaults
#else
  @_implementationOnly import GoogleUtilities
#endif // SWIFT_PACKAGE

/// Possible ways to get a custom model.
public enum ModelDownloadType {
  /// Get local model stored on device if available. If no local model on device, this is the same
  /// as `latestModel`.
  case localModel
  /// Get local model on device if available and update to latest model from server in the
  /// background. If no local model on device, this is the same as `latestModel`.
  case localModelUpdateInBackground
  /// Get latest model from server. Does not make a network call for model file download if local
  /// model matches the latest version on server.
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
  private let userDefaults: GULUserDefaults

  /// Telemetry logger tied to this instance of model downloader.
  let telemetryLogger: TelemetryLogger?

  /// Number of retries in case of model download URL expiry.
  var numberOfRetries: Int = 1

  /// Shared dictionary mapping app name to a specific instance of model downloader.
  // TODO: Switch to using Firebase components.
  private static var modelDownloaderDictionary: [String: ModelDownloader] = [:]

  /// Download task associated with the model currently being downloaded.
  private var currentDownloadTask: [String: ModelDownloadTask] = [:]

  /// DispatchQueue to manage download task dictionary.
  let taskSerialQueue = DispatchQueue(label: "downloadtask.serial.queue")

  /// Re-dispatch a function on the main queue.
  func asyncOnMainQueue(_ work: @autoclosure @escaping () -> Void) {
    DispatchQueue.main.async {
      work()
    }
  }

  /// Private init for model downloader.
  private init(app: FirebaseApp, defaults: GULUserDefaults = .firebaseMLDefaults) {
    appName = app.name
    options = app.options
    installations = Installations.installations(app: app)
    userDefaults = defaults
    // Respect Firebase-wide data collection setting.
    telemetryLogger = TelemetryLogger(app: app)
    // Notification of app deletion.
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
      // TODO: Clean up user defaults.
      // TODO: Clean up local instances of app.
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

  /// Downloads a custom model to device or gets a custom model already on device, with an optional
  /// handler for progress.
  /// - Parameters:
  ///   - modelName: The name of the model, matching Firebase console.
  ///   - downloadType: ModelDownloadType used to get the model.
  ///   - conditions: Conditions needed to perform a model download.
  ///   - progressHandler: Optional. Returns a float in [0.0, 1.0] that can be used to monitor model
  /// download progress.
  ///   - completion: Returns either a `CustomModel` on success, or a `DownloadError` on failure, at
  /// the end of a model download.
  public func getModel(name modelName: String,
                       downloadType: ModelDownloadType,
                       conditions: ModelDownloadConditions,
                       progressHandler: ((Float) -> Void)? = nil,
                       completion: @escaping (Result<CustomModel, DownloadError>) -> Void) {
    guard !modelName.isEmpty else {
      asyncOnMainQueue(completion(.failure(.emptyModelName)))
      return
    }

    switch downloadType {
    case .localModel:
      if let localModel = getLocalModel(modelName: modelName) {
        DeviceLogger.logEvent(level: .debug,
                              message: ModelDownloader.DebugDescription.localModelFound,
                              messageCode: .localModelFound)
        asyncOnMainQueue(completion(.success(localModel)))
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
        asyncOnMainQueue(completion(.success(localModel)))
        telemetryLogger?.logModelDownloadEvent(
          eventName: .modelDownload,
          status: .scheduled,
          model: CustomModel(name: modelName, size: 0, path: "", hash: ""),
          downloadErrorCode: .noError
        )
        // Update local model in the background.
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
                  model: CustomModel(name: modelName, size: 0, path: "", hash: ""),
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

  /// Gets the set of all downloaded models saved on device.
  /// - Parameter completion: Returns either a set of `CustomModel` models on success, or a
  /// `DownloadedModelError` on failure.
  public func listDownloadedModels(completion: @escaping (Result<Set<CustomModel>,
    DownloadedModelError>) -> Void) {
    do {
      let modelURLs = try ModelFileManager.contentsOfModelsDirectory()
      var customModels = Set<CustomModel>()
      // Retrieve model name from URL.
      for url in modelURLs {
        guard let modelName = ModelFileManager.getModelNameFromFilePath(url) else {
          let description = ModelDownloader.ErrorDescription.parseModelName(url.path)
          DeviceLogger.logEvent(level: .debug,
                                message: description,
                                messageCode: .modelNameParseError)
          asyncOnMainQueue(completion(.failure(.internalError(description: description))))
          return
        }
        // Check if model information corresponding to model is stored in UserDefaults.
        guard let modelInfo = getLocalModelInfo(modelName: modelName) else {
          let description = ModelDownloader.ErrorDescription.noLocalModelInfo(modelName)
          DeviceLogger.logEvent(level: .debug,
                                message: description,
                                messageCode: .noLocalModelInfo)
          asyncOnMainQueue(completion(.failure(.internalError(description: description))))
          return
        }
        // Ensure that local model path is as expected, and reachable.
        guard let modelURL = ModelFileManager.getDownloadedModelFileURL(
          appName: appName,
          modelName: modelName
        ),
          ModelFileManager.isFileReachable(at: modelURL) else {
          DeviceLogger.logEvent(level: .debug,
                                message: ModelDownloader.ErrorDescription.outdatedModelPath,
                                messageCode: .outdatedModelPathError)
          asyncOnMainQueue(completion(.failure(.internalError(description: ModelDownloader
              .ErrorDescription.outdatedModelPath))))
          return
        }
        let model = CustomModel(localModelInfo: modelInfo, path: modelURL.path)
        // Add model to result set.
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
      asyncOnMainQueue(completion(.failure(error)))
    } catch {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.ErrorDescription.listModelsFailed(error),
                            messageCode: .listModelsError)
      asyncOnMainQueue(completion(.failure(.internalError(description: error
          .localizedDescription))))
    }
  }

  /// Deletes a custom model file from device as well as corresponding model information saved in
  /// UserDefaults.
  /// - Parameters:
  ///   - modelName: The name of the model, matching Firebase console and already downloaded to
  /// device.
  ///   - completion: Returns a `DownloadedModelError` on failure.
  public func deleteDownloadedModel(name modelName: String,
                                    completion: @escaping (Result<Void, DownloadedModelError>)
                                      -> Void) {
    // Ensure that there is a matching model file on device, with corresponding model information in
    // UserDefaults.
    guard let modelURL = ModelFileManager.getDownloadedModelFileURL(
      appName: appName,
      modelName: modelName
    ),
      let localModelInfo = getLocalModelInfo(modelName: modelName),
      ModelFileManager.isFileReachable(at: modelURL)
    else {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.ErrorDescription.modelNotFound(modelName),
                            messageCode: .modelNotFound)
      asyncOnMainQueue(completion(.failure(.notFound)))
      return
    }
    do {
      // Remove model file from device.
      try ModelFileManager.removeFile(at: modelURL)
      // Clear out corresponding local model info.
      localModelInfo.removeFromDefaults(userDefaults, appName: appName)
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.DebugDescription.modelDeleted,
                            messageCode: .modelDeleted)
      telemetryLogger?.logModelDeletedEvent(
        eventName: .remoteModelDeleteOnDevice,
        isSuccessful: true
      )
      asyncOnMainQueue(completion(.success(())))
    } catch let error as DownloadedModelError {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.ErrorDescription.modelDeletionFailed(error),
                            messageCode: .modelDeletionFailed)
      telemetryLogger?.logModelDeletedEvent(
        eventName: .remoteModelDeleteOnDevice,
        isSuccessful: false
      )
      asyncOnMainQueue(completion(.failure(error)))
    } catch {
      DeviceLogger.logEvent(level: .debug,
                            message: ModelDownloader.ErrorDescription.modelDeletionFailed(error),
                            messageCode: .modelDeletionFailed)
      telemetryLogger?.logModelDeletedEvent(
        eventName: .remoteModelDeleteOnDevice,
        isSuccessful: false
      )
      asyncOnMainQueue(completion(.failure(.internalError(description: error
          .localizedDescription))))
    }
  }
}

extension ModelDownloader {
  /// Get model information for model saved on device, if available.
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
    /// Local model info is only considered valid if there is a corresponding model file on device.
    guard let modelURL = ModelFileManager.getDownloadedModelFileURL(
      appName: appName,
      modelName: modelName
    ), ModelFileManager.isFileReachable(at: modelURL) else {
      let description = ModelDownloader.DebugDescription.noLocalModelFile(modelName)
      DeviceLogger.logEvent(level: .debug,
                            message: description,
                            messageCode: .noLocalModelFile)
      return nil
    }
    return localModelInfo
  }

  /// Get model saved on device, if available.
  private func getLocalModel(modelName: String) -> CustomModel? {
    guard let modelURL = ModelFileManager.getDownloadedModelFileURL(
      appName: appName,
      modelName: modelName
    ), let localModelInfo = getLocalModelInfo(modelName: modelName) else { return nil }
    let model = CustomModel(localModelInfo: localModelInfo, path: modelURL.path)
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
      appName: appName, installations: installations,
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

  /// Get model info and model file from server.
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
        // New model info was downloaded from server.
        case let .modelInfo(remoteModelInfo):
          // Progress handler for model file download.
          let taskProgressHandler: ModelDownloadTask.ProgressHandler = { progress in
            if let progressHandler {
              self.asyncOnMainQueue(progressHandler(progress))
            }
          }
          // Completion handler for model file download.
          let taskCompletion: ModelDownloadTask.Completion = { result in
            switch result {
            case let .success(model):
              self.asyncOnMainQueue(completion(.success(model)))
            case let .failure(error):
              switch error {
              case .notFound:
                self.asyncOnMainQueue(completion(.failure(.notFound)))
              case .invalidArgument:
                self.asyncOnMainQueue(completion(.failure(.invalidArgument)))
              case .permissionDenied:
                self.asyncOnMainQueue(completion(.failure(.permissionDenied)))
              // This is the error returned when model download URL has expired.
              case .expiredDownloadURL:
                // Retry model info and model file download, if allowed.
                guard self.numberOfRetries > 0 else {
                  self
                    .asyncOnMainQueue(
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
                self.asyncOnMainQueue(completion(.failure(error)))
              }
            }
            self.taskSerialQueue.async {
              // Stop keeping track of current download task.
              self.currentDownloadTask.removeValue(forKey: modelName)
            }
          }
          self.taskSerialQueue.sync {
            // Merge duplicate requests if there is already a download in progress for the same
            // model.
            if let downloadTask = self.currentDownloadTask[modelName],
               downloadTask.canMergeRequests() {
              downloadTask.merge(
                newProgressHandler: taskProgressHandler,
                newCompletion: taskCompletion
              )
              DeviceLogger.logEvent(level: .debug,
                                    message: ModelDownloader.DebugDescription.mergingRequests,
                                    messageCode: .mergeRequests)
              if downloadTask.canResume() {
                downloadTask.resume()
              }
              // TODO: Handle else.
            } else {
              // Create download task for model file download.
              let downloadTask = ModelDownloadTask(
                remoteModelInfo: remoteModelInfo,
                appName: self.appName,
                defaults: self.userDefaults,
                downloader: downloader,
                progressHandler: taskProgressHandler,
                completion: taskCompletion,
                telemetryLogger: self.telemetryLogger
              )
              // Keep track of current download task to allow for merging duplicate requests.
              self.currentDownloadTask[modelName] = downloadTask
              downloadTask.resume()
            }
          }
        /// Local model info is the latest model info.
        case .notModified:
          guard let localModel = self.getLocalModel(modelName: modelName) else {
            // This can only happen if either local model info or the model file was wiped out after
            // model info request but before server response.
            self
              .asyncOnMainQueue(completion(.failure(.internalError(description: ModelDownloader
                  .ErrorDescription.deletedLocalModelInfoOrFile))))
            return
          }
          self.asyncOnMainQueue(completion(.success(localModel)))
        }
      // Error retrieving model info.
      case let .failure(error):
        self.asyncOnMainQueue(completion(.failure(error)))
      }
    }
  }
}

/// Possible errors with model downloading.
public enum DownloadError: Error, Equatable {
  /// No model with this name exists on server.
  case notFound
  /// Invalid, incomplete, or missing permissions for model download.
  case permissionDenied
  /// Conditions not met to perform download.
  case failedPrecondition
  /// Requests quota exhausted.
  case resourceExhausted
  /// Not enough space for model on device.
  case notEnoughSpace
  /// Malformed model name or Firebase app options.
  case invalidArgument
  /// Model name is empty.
  case emptyModelName
  /// Other errors with description.
  case internalError(description: String)
}

/// Possible errors with locating a model file on device.
public enum DownloadedModelError: Error {
  /// No model with this name exists on device.
  case notFound
  /// File system error.
  case fileIOError(description: String)
  /// Other errors with description.
  case internalError(description: String)
}

/// Extension to handle internally meaningful errors.
extension DownloadError {
  /// Model download URL expired before model download.
  // Model info retrieval and download is retried `numberOfRetries` times before failing.
  static let expiredDownloadURL: DownloadError =
    .internalError(description: "Expired model download URL.")
}

/// Possible debug and error messages while using model downloader.
extension ModelDownloader {
  /// Debug descriptions.
  private enum DebugDescription {
    static let createModelDownloader =
      "Initialized with new downloader instance associated with this app."
    static let retrieveModelDownloader =
      "Initialized with existing downloader instance associated with this app."
    static let deleteModelDownloader = "Model downloader instance deleted due to app deletion."
    static let localModelFound = "Found local model on device."
    static let allLocalModelsFound = "Found and listed all local models."
    static let noLocalModelInfo = { (name: String) in
      "No local model info for model named: \(name)."
    }

    static let noLocalModelFile = { (name: String) in
      "No local model file for model named: \(name)."
    }

    static let backgroundModelDownloaded = "Downloaded latest model in the background."
    static let modelDeleted = "Model deleted successfully."
    static let mergingRequests = "Merging duplicate download requests."
    static let retryDownload = "Retrying download."
  }

  /// Error descriptions.
  private enum ErrorDescription {
    static let defaultAppNotConfigured = "Default Firebase app not configured."
    static let invalidOptions = "Unable to retrieve project ID and/or API key for Firebase app."
    static let modelDownloadFailed = { (error: Error) in
      "Model download failed with error: \(error)"
    }

    static let modelNotFound = { (name: String) in
      "Model deletion failed due to no model found with name: \(name)"
    }

    static let modelInfoRetrievalFailed = { (error: Error) in
      "Model info retrieval failed with error: \(error)"
    }

    static let backgroundModelDownload = "Failed to update model in background."
    static let expiredModelInfo = "Unable to update expired model info."
    static let listModelsFailed = { (error: Error) in
      "Unable to list models, failed with error: \(error)"
    }

    static let parseModelName = { (path: String) in
      "List models failed due to unexpected model file name at \(path)."
    }

    static let noLocalModelInfo = { (name: String) in
      "List models failed due to no local model info for model file named: \(name)."
    }

    static let deletedLocalModelInfoOrFile =
      "Model unavailable due to deleted local model info or model file."
    static let outdatedModelPath =
      "List models failed due to outdated model paths in local storage."
    static let modelDeletionFailed = { (error: Error) in
      "Model deletion failed with error: \(error)"
    }
  }
}

/// Model downloader extension for testing.
extension ModelDownloader {
  /// Model downloader instance for testing.
  static func modelDownloaderWithDefaults(_ defaults: GULUserDefaults,
                                          app: FirebaseApp) -> ModelDownloader {
    let downloader = ModelDownloader(app: app, defaults: defaults)
    return downloader
  }
}
