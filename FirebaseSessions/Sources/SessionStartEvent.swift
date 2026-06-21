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

internal import GoogleDataTransport

#if SWIFT_PACKAGE
  import FirebaseSessionsObjC
#endif // SWIFT_PACKAGE

#if SWIFT_PACKAGE
  internal import GoogleUtilities_Environment
#else
  internal import GoogleUtilities
#endif // SWIFT_PACKAGE

///
/// SessionStartEvent is responsible for:
///   1) Writing fields to the Session proto
///   2) Synthesizing itself for persisting to disk and logging to GoogleDataTransport
///
class SessionStartEvent: NSObject, GDTCOREventDataObject {
  var proto: firebase_appquality_sessions_SessionEvent

  init(sessionInfo: SessionInfo, appInfo: ApplicationInfoProtocol,
       time: TimeProvider = Time()) {
    proto = firebase_appquality_sessions_SessionEvent()

    super.init()

    // Note: If you add a proto string field here, remember to free it in the deinit.
    proto.event_type = firebase_appquality_sessions_EventType_SESSION_START
    proto.session_data.session_id = makeProtoString(sessionInfo.sessionId)
    proto.session_data.first_session_id = makeProtoString(sessionInfo.firstSessionId)
    proto.session_data.session_index = sessionInfo.sessionIndex
    proto.session_data.event_timestamp_us = time.timestampUS

    proto.application_info.app_id = makeProtoString(appInfo.appID)
    proto.application_info.session_sdk_version = makeProtoString(appInfo.sdkVersion)
    proto.application_info.os_version = makeProtoString(appInfo.osDisplayVersion)
    proto.application_info.log_environment = convertLogEnvironment(environment: appInfo.environment)
    proto.application_info.device_model = makeProtoString(appInfo.deviceModel)
//    proto.application_info.development_platform_name;
//    proto.application_info.development_platform_version;

    // `which_platform_info` tells nanopb which oneof we're choosing to fill in for our proto
    proto.application_info.which_platform_info = FIRSESGetAppleApplicationInfoTag()
    proto.application_info.apple_app_info
      .bundle_short_version = makeProtoString(appInfo.appDisplayVersion)
    proto.application_info.apple_app_info
      .app_build_version = makeProtoString(appInfo.appBuildVersion)
    proto.application_info.apple_app_info.os_name = convertOSName(osName: appInfo.osName)

    // Set network info to base values but don't fill them in with the real
    // value because these are only tracked when Performance is installed
    proto.application_info.apple_app_info.mcc_mnc = makeProtoString("")
    proto.application_info.apple_app_info.network_connection_info
      .network_type = convertNetworkType(networkType: .none)
    proto.application_info.apple_app_info.network_connection_info
      .mobile_subtype = convertMobileSubtype(mobileSubtype: "")

    proto.session_data.data_collection_status
      .crashlytics = firebase_appquality_sessions_DataCollectionState_COLLECTION_SDK_NOT_INSTALLED
    proto.session_data.data_collection_status
      .performance = firebase_appquality_sessions_DataCollectionState_COLLECTION_SDK_NOT_INSTALLED
  }

  deinit {
    let garbage: [UnsafeMutablePointer<pb_bytes_array_t>?] = [
      proto.application_info.app_id,
      proto.application_info.apple_app_info.app_build_version,
      proto.application_info.apple_app_info.bundle_short_version,
      proto.application_info.apple_app_info.mcc_mnc,
      proto.application_info.development_platform_name,
      proto.application_info.development_platform_version,
      proto.application_info.device_model,
      proto.application_info.os_version,
      proto.application_info.session_sdk_version,
      proto.session_data.session_id,
      proto.session_data.firebase_installation_id,
      proto.session_data.firebase_authentication_token,
      proto.session_data.first_session_id,
    ]
    for pointer in garbage {
      nanopb_free(pointer)
    }
  }

  func setInstallationID(installationId: String) {
    let oldID = proto.session_data.firebase_installation_id
    proto.session_data.firebase_installation_id = makeProtoString(installationId)
    nanopb_free(oldID)
  }

  func setAuthenticationToken(authenticationToken: String) {
    let oldToken = proto.session_data.firebase_authentication_token
    proto.session_data.firebase_authentication_token = makeProtoString(authenticationToken)
    nanopb_free(oldToken)
  }

  func setSamplingRate(samplingRate: Double) {
    proto.session_data.data_collection_status.session_sampling_rate = samplingRate
  }

  func set(subscriber: SessionsSubscriberName, isDataCollectionEnabled: Bool,
           appInfo: ApplicationInfoProtocol) {
    let dataCollectionState = makeDataCollectionProto(isDataCollectionEnabled)
    switch subscriber {
    case .Crashlytics:
      proto.session_data.data_collection_status.crashlytics = dataCollectionState
    case .Performance:
      proto.session_data.data_collection_status.performance = dataCollectionState
    default:
      Logger
        .logWarning("Attempted to set Data Collection status for unknown Subscriber: \(subscriber)")
    }

    // Only set restricted fields if Data Collection is enabled. If it's disabled,
    // we're treating that as if the product isn't installed.
    if isDataCollectionEnabled {
      setRestrictedFields(subscriber: subscriber,
                          appInfo: appInfo)
    }
  }

  /// This method should be called for every subscribed Subscriber. This is for cases where
  /// fields should only be collected if a specific SDK is installed.
  private func setRestrictedFields(subscriber: SessionsSubscriberName,
                                   appInfo: ApplicationInfoProtocol) {
    switch subscriber {
    case .Performance:
      let oldString = proto.application_info.apple_app_info.mcc_mnc
      proto.application_info.apple_app_info.mcc_mnc = makeProtoString("")
      nanopb_free(oldString)
      proto.application_info.apple_app_info.network_connection_info
        .network_type = convertNetworkType(networkType: appInfo.networkInfo.networkType)
      proto.application_info.apple_app_info.network_connection_info
        .mobile_subtype = convertMobileSubtype(mobileSubtype: appInfo.networkInfo.mobileSubtype)
    default:
      break
    }
  }

  // MARK: - GDTCOREventDataObject

  func transportBytes() -> Data {
    return FIRSESTransportBytes(&proto)
  }

  // MARK: - Data Conversion

  func makeDataCollectionProto(_ isDataCollectionEnabled: Bool)
    -> firebase_appquality_sessions_DataCollectionState {
    if isDataCollectionEnabled {
      return firebase_appquality_sessions_DataCollectionState_COLLECTION_ENABLED
    } else {
      return firebase_appquality_sessions_DataCollectionState_COLLECTION_DISABLED
    }
  }

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
        Logger.logError("Session Event failed to decode transportBytes: \(errorMessage)")
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

  private func convertNetworkType(networkType: GULNetworkType)
    -> firebase_appquality_sessions_NetworkConnectionInfo_NetworkType {
    switch networkType {
    case .WIFI:
      return firebase_appquality_sessions_NetworkConnectionInfo_NetworkType_WIFI
    case .mobile:
      return firebase_appquality_sessions_NetworkConnectionInfo_NetworkType_MOBILE
    case .none:
      return firebase_appquality_sessions_NetworkConnectionInfo_NetworkType_DUMMY
    @unknown default:
      return firebase_appquality_sessions_NetworkConnectionInfo_NetworkType_DUMMY
    }
  }

  private func convertMobileSubtype(mobileSubtype: String)
    -> firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype {
    var subtype: firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype

    #if os(iOS) && !targetEnvironment(macCatalyst)
      switch mobileSubtype {
      case CTRadioAccessTechnologyGPRS:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_GPRS
      case CTRadioAccessTechnologyEdge:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EDGE
      case CTRadioAccessTechnologyWCDMA:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_CDMA
      case CTRadioAccessTechnologyCDMA1x:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_CDMA
      case CTRadioAccessTechnologyHSDPA:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_HSDPA
      case CTRadioAccessTechnologyHSUPA:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_HSUPA
      case CTRadioAccessTechnologyCDMAEVDORev0:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EVDO_0
      case CTRadioAccessTechnologyCDMAEVDORevA:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EVDO_A
      case CTRadioAccessTechnologyCDMAEVDORevB:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EVDO_B
      case CTRadioAccessTechnologyeHRPD:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EHRPD
      case CTRadioAccessTechnologyLTE:
        subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_LTE
      default:
        subtype =
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_UNKNOWN_MOBILE_SUBTYPE
      }

      if #available(iOS 14.1, *) {
        if mobileSubtype == CTRadioAccessTechnologyNRNSA || mobileSubtype ==
          CTRadioAccessTechnologyNR {
          subtype = firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_NR
        }
      }
    #else // os(iOS) && !targetEnvironment(macCatalyst)
      subtype =
        firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_UNKNOWN_MOBILE_SUBTYPE
    #endif // os(iOS) && !targetEnvironment(macCatalyst)

    return subtype
  }
}
