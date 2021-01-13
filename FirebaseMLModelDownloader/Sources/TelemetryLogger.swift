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
import SwiftProtobuf

/// Extension to set Firebase app info.
extension SystemInfo {
  mutating func setAppInfo(app: FirebaseApp) {
    appID = Bundle.main.bundleIdentifier ?? "unknownBundleID"
    appVersion = Bundle.main
      .infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknownAppVersion"
    apiKey = app.options.apiKey ?? "unknownAPIKey"
    firebaseProjectID = app.options.projectID ?? "unknownProjectID"
  }
}

/// Extension to set model options.
extension ModelOptions {
  mutating func setModelOptions(model: CustomModel) {
    isModelUpdateEnabled = true
    modelInfo.name = model.name
    modelInfo.hash = model.hash
    modelInfo.modelType = .custom
  }
}

extension ModelDownloadLogEvent {
  mutating func setEvent(status: DownloadStatus, errorCode: ErrorCode? = nil,
                         roughDownloadDuration: UInt64? = nil, exactDownloadDuration: UInt64? = nil,
                         downloadFailureStatus: Int64? = nil, modelOptions: ModelOptions) {
    downloadStatus = status
    if let code = errorCode {
      self.errorCode = code
    }
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

/// Data object for Firelog event.
class FBMLDataObject: NSObject, GDTCOREventDataObject {
  private let event: FirebaseMlLogEvent

  init(event: FirebaseMlLogEvent) {
    self.event = event
  }

  /// Encode Firelog event for transport.
  func transportBytes() -> Data {
    do {
      // let data = try event.serializedData()

      var options = JSONEncodingOptions()
      options.alwaysPrintEnumsAsInts = false
      options.preserveProtoFieldNames = true

      let data = try event.jsonUTF8Data(options: options)
      print(try event.jsonString(options: options))

      return data
    } catch {
      DeviceLogger.logEvent(
        level: .debug,
        category: .analytics,
        message: "Unable to encode Firelog event.",
        messageCode: .analyticsEventEncodeError
      )
      return Data()
    }
  }
}

/// Firelog logger.
class TelemetryLogger {
  private let mappingID = "1326"
  let isStatsEnabled: Bool
  let fllTransport: GDTCORTransport

  init(isStatsEnabled: Bool) {
    self.isStatsEnabled = isStatsEnabled
    guard let fllTransport = GDTCORTransport(
      mappingID: mappingID,
      transformers: nil,
      target: GDTCORTarget.FLL
    ) else {
      fatalError("Event transport initialization error")
    }
    self.fllTransport = fllTransport
  }

  /// Log model download event to Firelog.
  func logModelDownloadEvent(event: FirebaseMlLogEvent) {
    let eventForTransport: GDTCOREvent = fllTransport.eventForTransport()
    eventForTransport.dataObject = FBMLDataObject(event: event)
    eventForTransport.qosTier = .qoSFast
    fllTransport.sendDataEvent(eventForTransport)
  }
}
