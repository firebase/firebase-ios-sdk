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

#if SWIFT_PACKAGE
  import FirebaseSessionsObjC
#endif // SWIFT_PACKAGE

class DevEventConsoleLogger: EventGDTLoggerProtocol {
  private let commandLineArgument = "-FIRSessionsDebugEvents"

  func logEvent(event: SessionStartEvent, completion: @escaping (Result<Void, Error>) -> Void) {
    if !ProcessInfo.processInfo.arguments.contains(commandLineArgument) {
      return
    }

    let proto = event.encodeDecodeEvent()
    prettyPrint(proto: proto)
  }

  func prettyPrint(proto: firebase_appquality_sessions_SessionEvent) {
    let logOutput = """
    Printing Session Event due to \"\(commandLineArgument)\" command line argument
    Session Event:
      event_type: \(proto.event_type)
      session_data
        session_id: \(proto.session_data.session_id.description)
        first_session_id: \(proto.session_data.first_session_id.description)
        session_index: \(proto.session_data.session_index)
        event_timestamp_us: \(proto.session_data.event_timestamp_us)
        firebase_installation_id: \(proto.session_data.firebase_installation_id.description)
        data_collection_status
          crashlytics: \(proto.session_data.data_collection_status.crashlytics)
          performance: \(proto.session_data.data_collection_status.performance)
          session_sampling_rate: \(proto.session_data.data_collection_status.session_sampling_rate)
      application_info
        app_id: \(proto.application_info.app_id.description)
        session_sdk_version: \(proto.application_info.session_sdk_version.description)
        os_version: \(proto.application_info.os_version.description)
        device_model: \(proto.application_info.device_model.description)
        development_platform_name: \(proto.application_info.development_platform_name.description)
        development_platform_version: \(proto.application_info.development_platform_version
      .description)
        session_sdk_version: \(proto.application_info.session_sdk_version.description)
        apple_app_info
          bundle_short_version: \(proto.application_info.apple_app_info.bundle_short_version
      .description)
          app_build_version: \(proto.application_info.apple_app_info.app_build_version.description)
          network_connection_info
            network_type: \(proto.application_info.apple_app_info.network_connection_info
      .network_type.rawValue)
            mobile_subtype: \(proto.application_info.apple_app_info.network_connection_info
      .mobile_subtype.rawValue)
          os_name: \(proto.application_info.apple_app_info.os_name.description)
          log_environment: \(proto.application_info.log_environment)
    """

    Logger.logInfo(logOutput)
  }
}
