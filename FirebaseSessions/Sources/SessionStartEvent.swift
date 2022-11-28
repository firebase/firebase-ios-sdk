//
// Copyright 2022 Google LLC
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

@_implementationOnly import GoogleDataTransport

///
/// SessionStartEvent is responsible for:
///   1) Writing fields to the Session proto
///   2) Synthesizing itself for persisting to disk and logging to GoogleDataTransport
///
class SessionStartEvent: NSObject, GDTCOREventDataObject {
  var proto: firebase_appquality_sessions_SessionEvent

  init(identifiers: IdentifierProvider, appInfo: ApplicationInfoProtocol,
       time: TimeProvider = Time()) {
    proto = firebase_appquality_sessions_SessionEvent()

    super.init()

    proto.event_type = firebase_appquality_sessions_EventType_SESSION_START
    proto.session_data.session_id = makeProtoString(identifiers.sessionID)
    proto.session_data.previous_session_id = makeProtoStringOrNil(identifiers.previousSessionID)
    proto.session_data.event_timestamp_us = time.timestampUS

    proto.application_info.app_id = makeProtoString(appInfo.appID)
    proto.application_info.session_sdk_version = makeProtoString(appInfo.sdkVersion)
    proto.application_info.log_environment = convertLogEnvironment(environment: appInfo.environment)
    proto.application_info.device_model = makeProtoString(appInfo.deviceModel)
//    proto.application_info.development_platform_name;
//    proto.application_info.development_platform_version;

    // `which_platform_info` tells nanopb which oneof we're choosing to fill in for our proto
    proto.application_info.which_platform_info = FIRSESGetAppleApplicationInfoTag()
    proto.application_info.apple_app_info.bundle_short_version = makeProtoString(appInfo.bundleID)
//    proto.application_info.apple_app_info.network_connection_info
    proto.application_info.apple_app_info.os_name = convertOSName(osName: appInfo.osName)
    proto.application_info.apple_app_info.mcc_mnc = makeProtoString(appInfo.mccMNC)

    proto.session_data.data_collection_status
      .crashlytics = firebase_appquality_sessions_DataCollectionState_COLLECTION_UNKNOWN
    proto.session_data.data_collection_status
      .performance = firebase_appquality_sessions_DataCollectionState_COLLECTION_UNKNOWN
  }

  func setInstallationID(identifiers: IdentifierProvider) {
    proto.session_data.firebase_installation_id = makeProtoString(identifiers.installationID)
  }

  func setSamplingRate(samplingRate: Double) {
    proto.session_data.data_collection_status.session_sampling_rate = samplingRate
  }

  // MARK: - GDTCOREventDataObject

  func transportBytes() -> Data {
    var fields = firebase_appquality_sessions_SessionEvent_fields
    var error: NSError?
    let data = FIRSESEncodeProto(&fields.0, &proto, &error)
    if error != nil {
      Logger.logError(error.debugDescription)
    }
    guard let data = data else {
      Logger.logError("Session event generated nil transportBytes. Returning empty data.")
      return Data()
    }
    return data
  }

  // MARK: - Data Conversion

  private func makeProtoStringOrNil(_ string: String?) -> UnsafeMutablePointer<pb_bytes_array_t>? {
    guard let string = string else {
      return nil
    }
    return FIRSESEncodeString(string)
  }

  private func makeProtoString(_ string: String) -> UnsafeMutablePointer<pb_bytes_array_t>? {
    return FIRSESEncodeString(string)
  }

  private func convertOSName(osName: String) -> firebase_appquality_sessions_OsName {
    switch osName.lowercased() {
    case "macos":
      return firebase_appquality_sessions_OsName_MACOS
    case "maccatalyst":
      return firebase_appquality_sessions_OsName_MACCATALYST
    case "ios_on_mac":
      return firebase_appquality_sessions_OsName_IOS_ON_MAC
    case "ios":
      return firebase_appquality_sessions_OsName_IOS
    case "tvos":
      return firebase_appquality_sessions_OsName_TVOS
    case "watchos":
      return firebase_appquality_sessions_OsName_WATCHOS
    case "ipados":
      return firebase_appquality_sessions_OsName_IPADOS
    default:
      Logger.logWarning("Found unknown OSName: \"\(osName)\" while converting.")
      return firebase_appquality_sessions_OsName_UNKNOWN_OSNAME
    }
  }

  /// Encodes the proto in this SessionStartEvent to Data, and then decodes the Data back into
  /// the proto object and returns the decoded proto. This is used for validating encoding works
  /// and should not be used in production code.
  func encodeDecodeEvent() -> firebase_appquality_sessions_SessionEvent {
    let transportBytes = self.transportBytes()
    var proto = firebase_appquality_sessions_SessionEvent()
    var fields = firebase_appquality_sessions_SessionEvent_fields

    let bytes = (transportBytes as NSData).bytes
    var istream: pb_istream_t = pb_istream_from_buffer(bytes, transportBytes.count)

    if !pb_decode(&istream, &fields.0, &proto) {
      let errorMessage = FIRSESPBGetError(istream)
      if errorMessage.count > 0 {
        Logger.logInfo("Failed to decode transportBytes: \(errorMessage)")
      }
    }
    return proto
  }

  /// Converts the provided log environment to its Proto format.
  private func convertLogEnvironment(environment: DevEnvironment)
    -> firebase_appquality_sessions_LogEnvironment {
    switch environment {
    case .prod:
      return firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_PROD
    case .staging:
      return firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_STAGING
    case .autopush:
      return firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_AUTOPUSH
    }
  }
}
