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
import Foundation
import GoogleDataTransport

/// Extension to set Firebase app info.
extension SystemInfo {
  mutating func setAppInfo(apiKey: String?, projectID: String?) {
    appID = Bundle.main.bundleIdentifier ?? "unknownBundleID"
    let appVersionKey = "CFBundleShortVersionString"
    appVersion = Bundle.main.infoDictionary?[appVersionKey] as? String ?? "unknownAppVersion"
    mlSdkVersion = FirebaseVersion()
    self.apiKey = apiKey ?? "unknownAPIKey"
    firebaseProjectID = projectID ?? "unknownProjectID"
  }
}

/// Extension to set model info.
extension ModelInfo {
  mutating func setModelInfo(modelName: String, modelHash: String) {
    name = modelName
    if !modelHash.isEmpty {
      hash = modelHash
    }
    modelType = .custom
  }
}

/// Extension to set model options.
extension ModelOptions {
  mutating func setModelOptions(modelName: String, modelHash: String) {
    var modelInfo = ModelInfo()
    modelInfo.setModelInfo(modelName: modelName, modelHash: modelHash)
    self.modelInfo = modelInfo
  }
}

/// Extension to build model delete log event.
extension DeleteModelLogEvent {
  mutating func setEvent(modelType: ModelInfo.ModelType = .custom, isSuccessful: Bool) {
    self.modelType = modelType
    self.isSuccessful = isSuccessful
  }
}

/// Extension to build model download log event.
extension ModelDownloadLogEvent {
  mutating func setEvent(status: DownloadStatus, errorCode: ErrorCode,
                         roughDownloadDuration: UInt64? = 0, exactDownloadDuration: UInt64? = 0,
                         downloadFailureStatus: Int64? = 0, modelOptions: ModelOptions) {
    downloadStatus = status
    self.errorCode = errorCode
    if let roughDownloadDuration {
      roughDownloadDurationMs = roughDownloadDuration
    }
    if let exactDownloadDuration {
      exactDownloadDurationMs = exactDownloadDuration
    }
    if let downloadFailureStatus {
      self.downloadFailureStatus = downloadFailureStatus
    }
    options = modelOptions
  }
}

/// Extension to build log event.
extension FirebaseMlLogEvent {
  mutating func setEvent(eventName: EventName, systemInfo: SystemInfo,
                         modelDownloadLogEvent: ModelDownloadLogEvent) {
    self.eventName = eventName
    self.systemInfo = systemInfo
    self.modelDownloadLogEvent = modelDownloadLogEvent
  }

  mutating func setEvent(eventName: EventName, systemInfo: SystemInfo,
                         deleteModelLogEvent: DeleteModelLogEvent) {
    self.eventName = eventName
    self.systemInfo = systemInfo
    self.deleteModelLogEvent = deleteModelLogEvent
  }
}

/// Data object for Firelog event.
class FBMLDataObject: NSObject, GDTCOREventDataObject {
  private let event: FirebaseMlLogEvent

  init(event: FirebaseMlLogEvent) {
    self.event = event
  }

  /// Encode Firelog event for transport.
  func transportBytes() -> Data {
    do {
      let data = try event.serializedData()
      return data
    } catch {
      DeviceLogger.logEvent(level: .debug,
                            message: TelemetryLogger.ErrorDescription.encodeEvent,
                            messageCode: .analyticsEventEncodeError)
      return Data()
    }
  }
}

/// Firelog logger.
class TelemetryLogger {
  /// Mapping ID for the log source.
  private let mappingID = "1326"

  /// Current Firebase app.
  private let app: FirebaseApp

  /// Transport for Firelog events.
  private let cctTransport: GDTCORTransport

  /// Init logger, could be nil if unable to get event transport.
  init?(app: FirebaseApp) {
    self.app = app
    guard let cctTransport = GDTCORTransport(
      mappingID: mappingID,
      transformers: nil,
      target: GDTCORTarget.CCT
    ) else {
      DeviceLogger.logEvent(level: .debug,
                            message: TelemetryLogger.ErrorDescription.initTelemetryLogger,
                            messageCode: .telemetryInitError)
      return nil
    }
    self.cctTransport = cctTransport
  }

  /// Log events to Firelog.
  private func logModelEvent(event: FirebaseMlLogEvent) {
    let eventForTransport: GDTCOREvent = cctTransport.eventForTransport()
    eventForTransport.dataObject = FBMLDataObject(event: event)
    cctTransport.sendTelemetryEvent(eventForTransport)
  }

  /// Log model deleted event to Firelog.
  func logModelDeletedEvent(eventName: EventName, isSuccessful: Bool) {
    guard app.isDataCollectionDefaultEnabled else { return }
    var systemInfo = SystemInfo()
    let apiKey = app.options.apiKey
    let projectID = app.options.projectID
    systemInfo.setAppInfo(apiKey: apiKey, projectID: projectID)
    var deleteModelLogEvent = DeleteModelLogEvent()
    deleteModelLogEvent.setEvent(isSuccessful: isSuccessful)
    var fbmlEvent = FirebaseMlLogEvent()
    fbmlEvent.setEvent(
      eventName: eventName,
      systemInfo: systemInfo,
      deleteModelLogEvent: deleteModelLogEvent
    )
    logModelEvent(event: fbmlEvent)
  }

  /// Log model info retrieval event to Firelog.
  func logModelInfoRetrievalEvent(eventName: EventName,
                                  status: ModelDownloadLogEvent.DownloadStatus,
                                  model: CustomModel,
                                  modelInfoErrorCode: ModelInfoErrorCode) {
    guard app.isDataCollectionDefaultEnabled else { return }
    var systemInfo = SystemInfo()
    let apiKey = app.options.apiKey
    let projectID = app.options.projectID
    systemInfo.setAppInfo(apiKey: apiKey, projectID: projectID)
    var errorCode = ErrorCode()
    var failureCode: Int64?
    switch modelInfoErrorCode {
    case .noError:
      errorCode = .noError
    case .noHash:
      errorCode = .modelInfoDownloadNoHash
    case .connectionFailed:
      errorCode = .modelInfoDownloadConnectionFailed
    case .hashMismatch:
      errorCode = .modelHashMismatch
    case let .httpError(code):
      errorCode = .modelInfoDownloadUnsuccessfulHTTPStatus
      failureCode = Int64(code)
    case .unknown:
      errorCode = .unknownError
    }
    var modelOptions = ModelOptions()
    modelOptions.setModelOptions(
      modelName: model.name,
      modelHash: model.hash
    )
    var modelDownloadLogEvent = ModelDownloadLogEvent()
    modelDownloadLogEvent.setEvent(
      status: status,
      errorCode: errorCode,
      downloadFailureStatus: failureCode,
      modelOptions: modelOptions
    )
    var fbmlEvent = FirebaseMlLogEvent()
    fbmlEvent.setEvent(
      eventName: eventName,
      systemInfo: systemInfo,
      modelDownloadLogEvent: modelDownloadLogEvent
    )
    logModelEvent(event: fbmlEvent)
  }

  /// Log model download event to Firelog.
  func logModelDownloadEvent(eventName: EventName,
                             status: ModelDownloadLogEvent.DownloadStatus,
                             model: CustomModel,
                             downloadErrorCode: ModelDownloadErrorCode) {
    guard app.isDataCollectionDefaultEnabled else { return }
    var modelOptions = ModelOptions()
    modelOptions.setModelOptions(modelName: model.name, modelHash: model.hash)
    var systemInfo = SystemInfo()
    let apiKey = app.options.apiKey
    let projectID = app.options.projectID
    systemInfo.setAppInfo(apiKey: apiKey, projectID: projectID)

    var errorCode = ErrorCode()
    var failureCode: Int64?

    switch downloadErrorCode {
    case .noError:
      errorCode = .noError
    case .urlExpired:
      errorCode = .uriExpired
    case .noConnection:
      errorCode = .noNetworkConnection
    case .downloadFailed:
      errorCode = .downloadFailed
    case let .httpError(code):
      errorCode = .unknownError
      failureCode = Int64(code)
    }

    var modelDownloadLogEvent = ModelDownloadLogEvent()
    modelDownloadLogEvent.setEvent(
      status: status,
      errorCode: errorCode,
      downloadFailureStatus: failureCode,
      modelOptions: modelOptions
    )

    var fbmlEvent = FirebaseMlLogEvent()
    fbmlEvent.setEvent(
      eventName: eventName,
      systemInfo: systemInfo,
      modelDownloadLogEvent: modelDownloadLogEvent
    )
    logModelEvent(event: fbmlEvent)
  }
}

/// Possible error messages while logging telemetry.
private extension TelemetryLogger {
  /// Error descriptions.
  enum ErrorDescription {
    static let encodeEvent = "Unable to encode event for Firelog."
    static let initTelemetryLogger = "Unable to create telemetry logger."
  }
}
