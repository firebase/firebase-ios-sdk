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

/// Extension to set model options.
extension ModelOptions {
  mutating func setModelOptions(model: CustomModel, isModelUpdateEnabled: Bool? = nil) {
    if let updateEnabled = isModelUpdateEnabled {
      self.isModelUpdateEnabled = updateEnabled
    }
    modelInfo.name = model.name
    modelInfo.hash = model.hash
    modelInfo.modelType = .custom
  }
}

/// Extension to build model download log event.
extension ModelDownloadLogEvent {
  mutating func setEvent(status: DownloadStatus, errorCode: ErrorCode,
                         roughDownloadDuration: UInt64? = nil, exactDownloadDuration: UInt64? = nil,
                         downloadFailureStatus: Int64? = nil, modelOptions: ModelOptions) {
    downloadStatus = status
    self.errorCode = errorCode
    if let roughDuration = roughDownloadDuration {
      roughDownloadDurationMs = roughDuration
    }
    if let exactDuration = exactDownloadDuration {
      exactDownloadDurationMs = exactDuration
    }
    if let failureStatus = downloadFailureStatus {
      self.downloadFailureStatus = failureStatus
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
  private let fllTransport: GDTCORTransport

  /// Init logger, could be nil if unable to get event transport.
  init?(app: FirebaseApp) {
    self.app = app
    guard let fllTransport = GDTCORTransport(
      mappingID: mappingID,
      transformers: nil,
      target: GDTCORTarget.FLL
    ) else {
      DeviceLogger.logEvent(level: .debug,
                            message: TelemetryLogger.ErrorDescription.initTelemetryLogger,
                            messageCode: .telemetryInitError)
      return nil
    }
    self.fllTransport = fllTransport
  }

  /// Log events to Firelog.
  private func logModelEvent(event: FirebaseMlLogEvent) {
    let eventForTransport: GDTCOREvent = fllTransport.eventForTransport()
    eventForTransport.dataObject = FBMLDataObject(event: event)
    fllTransport.sendTelemetryEvent(eventForTransport)
  }

  /// Log model info retrieval event to Firelog.
  func logModelInfoRetrievalEvent(eventName: EventName,
                                  status: ModelDownloadLogEvent.DownloadStatus,
                                  model: CustomModel? = nil, errorCode: ModelInfoErrorCode) {
    guard app.isDataCollectionDefaultEnabled else { return }
    var systemInfo = SystemInfo()
    let apiKey = app.options.apiKey
    let projectID = app.options.projectID
    systemInfo.setAppInfo(apiKey: apiKey, projectID: projectID)
    let modelDownloadLogEvent = ModelDownloadLogEvent()
    var fbmlEvent = FirebaseMlLogEvent()
    fbmlEvent.setEvent(
      eventName: eventName,
      systemInfo: systemInfo,
      modelDownloadLogEvent: modelDownloadLogEvent
    )
    logModelEvent(event: fbmlEvent)
  }

  /// Log model download event to Firelog.
  func logModelDownloadEvent(eventName: EventName, status: ModelDownloadLogEvent.DownloadStatus,
                             model: CustomModel? = nil, downloadErrorCode: ModelDownloadErrorCode) {
    guard app.isDataCollectionDefaultEnabled else { return }
    var modelOptions = ModelOptions()
    if let model = model {
      modelOptions.setModelOptions(model: model)
    }
    var systemInfo = SystemInfo()
    let apiKey = app.options.apiKey
    let projectID = app.options.projectID
    systemInfo.setAppInfo(apiKey: apiKey, projectID: projectID)

    var errorCode = ErrorCode()
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
      errorCode = ErrorCode(rawValue: code) ?? .unknownError
    }

    var modelDownloadLogEvent = ModelDownloadLogEvent()
    modelDownloadLogEvent.setEvent(
      status: status,
      errorCode: errorCode,
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
extension TelemetryLogger {
  /// Error descriptions.
  fileprivate enum ErrorDescription {
    static let encodeEvent = "Unable to encode event for Firelog."
    static let initTelemetryLogger = "Unable to create telemetry logger."
  }
}
