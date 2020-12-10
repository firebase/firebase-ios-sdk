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
  /// FirebaseApp associated with this instance of ModelDownloader.
  private let app: FirebaseApp

  private init(app: FirebaseApp) {
    self.app = app
  }

  /// Model downloader with default app.
  static func modelDownloader() throws -> ModelDownloader {
    guard let defaultApp = FirebaseApp.app() else {
      // TODO: Replace with more appropriate error.
      throw DownloadError.internalError(description: "Default Firebase app not configured.")
    }
    return modelDownloader(app: defaultApp)
  }

  /// Model Downloader with custom app.
  static func modelDownloader(app: FirebaseApp) -> ModelDownloader {
    return ModelDownloader(app: app)
  }

  /// Get model saved on device, if available.
  private func getLocalModel(modelName: String, app: FirebaseApp,
                             progressHandler: ((Float) -> Void)? = nil,
                             completion: @escaping (Result<CustomModel, DownloadError>) -> Void) {
    guard let modelInfo = ModelInfo(fromDefaults: .firebaseMLDefaults, name: modelName, app: app),
      let path = modelInfo.path else {
      getRemoteModel(
        modelName: modelName,
        app: app,
        progressHandler: progressHandler,
        completion: completion
      )
      return
    }
    let model = CustomModel(
      name: modelInfo.name,
      size: modelInfo.size,
      path: path,
      hash: modelInfo.modelHash
    )
    completion(.success(model))
  }

  /// Download and get model from server.
  private func getRemoteModel(modelName: String, app: FirebaseApp,
                              progressHandler: ((Float) -> Void)? = nil,
                              completion: @escaping (Result<CustomModel, DownloadError>) -> Void) {
    let modelInfoRetriever = ModelInfoRetriever(app: app, modelName: modelName)
    modelInfoRetriever.downloadModelInfo { error in
      if let downloadError = error {
        completion(.failure(downloadError))
      } else {
        guard let modelInfo = modelInfoRetriever.modelInfo else {
          completion(.failure(.internalError(description: "Error downloading model info.")))
          return
        }
        guard let path = modelInfo.path else {
          let downloadTask = ModelDownloadTask(
            app: app,
            modelInfo: modelInfo,
            progressHandler: progressHandler,
            completion: completion
          )
          downloadTask.resumeModelDownload()
          return
        }
        let model = CustomModel(
          name: modelInfo.name,
          size: modelInfo.size,
          path: path,
          hash: modelInfo.modelHash
        )
        completion(.success(model))
      }
    }
  }

  /// Downloads a custom model to device or gets a custom model already on device, w/ optional handler for progress.
  public func getModel(name modelName: String, downloadType: ModelDownloadType,
                       conditions: ModelDownloadConditions,
                       progressHandler: ((Float) -> Void)? = nil,
                       completion: @escaping (Result<CustomModel, DownloadError>) -> Void) {
    // TODO: Model download
    switch downloadType {
    case .localModel: getLocalModel(
      modelName: modelName,
      app: app,
      progressHandler: progressHandler,
      completion: completion
    )

    case .localModelUpdateInBackground: break

    case .latestModel: getRemoteModel(
      modelName: modelName,
      app: app,
      progressHandler: progressHandler,
      completion: completion
    )
    }

    let modelSize = Int()
    let modelPath = String()
    let modelHash = String()

    let customModel = CustomModel(
      name: modelName,
      size: modelSize,
      path: modelPath,
      hash: modelHash
    )
    completion(.success(customModel))
    completion(.failure(.notFound))
  }

  /// Gets all downloaded models.
  public func listDownloadedModels(completion: @escaping (Result<Set<CustomModel>,
    DownloadedModelError>) -> Void) {
    let customModels = Set<CustomModel>()
    // TODO: List downloaded models
    completion(.success(customModels))
    completion(.failure(.notFound))
  }

  /// Deletes a custom model from device.
  public func deleteDownloadedModel(name modelName: String,
                                    completion: @escaping (Result<Void, DownloadedModelError>)
                                      -> Void) {
    // TODO: Delete previously downloaded model
    completion(.success(()))
    completion(.failure(.notFound))
  }
}
