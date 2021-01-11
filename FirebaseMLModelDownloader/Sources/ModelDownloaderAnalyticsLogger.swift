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
import GoogleDataTransport

/// Firelog event.
struct FBMLEvent: Codable {
  var eventName: String
  var systemInfo: FBMLSystemInfo
  var eventDescription: String
  var errorCode: Int?
}

/// System info.
struct FBMLSystemInfo: Codable {
  var appID: String
  var appVersion: String
  var apiKey: String
  var projectID: String
}

/// Enum of debug messages.
// TODO: Create list of all possible messages with code - according to format.
enum LoggerMessageCode {
  case modelDownloaded
  case downloadedModelMovedToURL
  case analyticsEventEncodeError
}

/// Data object for Firelog event.
class FBMLDataObject: NSObject, GDTCOREventDataObject {
  private let event: FBMLEvent

  init(event: FBMLEvent) {
    self.event = event
  }

  /// Encode Firelog event for transport.
  func transportBytes() -> Data {
    do {
      let encoder = JSONEncoder()
      let data = try encoder.encode(event)
      return data
    } catch {
      DeviceLogger.logEvent(
        level: .error,
        category: .analytics,
        message: "Unable to encode Firelog event.",
        messageCode: .analyticsEventEncodeError
      )
      return Data()
    }
  }
}

/// Firelog event transporter.
class ModelDownloaderEventTransport {
  private let logSDKName = "FIREBASE_ML_LOG_SDK"
  let fllTransport: GDTCORTransport

  init?() {
    guard let fllTransport = GDTCORTransport(
      mappingID: logSDKName,
      transformers: nil,
      target: GDTCORTarget.FLL
    ) else {
      return nil
    }
    self.fllTransport = fllTransport
  }
}

/// Firelog logger.
class AnalyticsLogger {
  let isStatsEnabled: Bool
  let fllTransport: GDTCORTransport

  init(isStatsEnabled: Bool, fllTransport: GDTCORTransport) {
    self.isStatsEnabled = isStatsEnabled
    self.fllTransport = fllTransport
  }

  /// Log event to Firelog.
  func logEvent(event: FBMLEvent) {
    let eventForTransport = fllTransport.eventForTransport()
    eventForTransport.dataObject = FBMLDataObject(event: event)
    fllTransport.sendDataEvent(eventForTransport)
  }
}
