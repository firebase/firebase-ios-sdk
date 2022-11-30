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

import XCTest

@_implementationOnly import GoogleUtilities

@testable import FirebaseSessions

class SessionStartEventTests: XCTestCase {
  var identifiers: MockIdentifierProvider!
  var time: MockTimeProvider!
  var appInfo: MockApplicationInfo!

  override func setUp() {
    super.setUp()

    identifiers = MockIdentifierProvider()
    time = MockTimeProvider()
    appInfo = MockApplicationInfo()
  }

  /// This function runs the `testCase` twice, once for the proto object stored in
  /// the event, and once after encoding and decoding the proto. This is useful for
  /// testing cases where the proto hasn't been encoded correctly.
  func testProtoAndDecodedProto(sessionEvent: SessionStartEvent,
                                testCase: (firebase_appquality_sessions_SessionEvent) -> Void) {
    let proto = sessionEvent.proto
    testCase(proto)

    /// If you are getting failures in this test case, and not the one above, the
    /// problem likely lies in encoding the proto
    let decodedProto = sessionEvent.encodeDecodeEvent()
    testCase(decodedProto)
  }

  func test_init_setsSessionIDs() {
    identifiers.mockAllValidIDs()

    let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)

    testProtoAndDecodedProto(sessionEvent: event) { proto in
      assertEqualProtoString(
        proto.session_data.session_id,
        expected: MockIdentifierProvider.testSessionID,
        fieldName: "session_id"
      )
      assertEqualProtoString(
        proto.session_data.previous_session_id,
        expected: MockIdentifierProvider.testPreviousSessionID,
        fieldName: "previous_session_id"
      )

      XCTAssertEqual(proto.session_data.event_timestamp_us, 123)
    }
  }

  func test_init_setsApplicationInfo() {
    appInfo.mockAllInfo()

    let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)

    testProtoAndDecodedProto(sessionEvent: event) { proto in
      assertEqualProtoString(
        proto.application_info.app_id,
        expected: MockApplicationInfo.testAppID,
        fieldName: "app_id"
      )
      assertEqualProtoString(
        proto.application_info.session_sdk_version,
        expected: MockApplicationInfo.testSDKVersion,
        fieldName: "session_sdk_version"
      )
      assertEqualProtoString(
        proto.application_info.apple_app_info.bundle_short_version,
        expected: MockApplicationInfo.testBundleID,
        fieldName: "bundle_short_version"
      )
      assertEqualProtoString(
        proto.application_info.device_model,
        expected: MockApplicationInfo.testDeviceModel,
        fieldName: "device_model"
      )
      assertEqualProtoString(
        proto.application_info.apple_app_info.mcc_mnc,
        expected: MockApplicationInfo.testMCCMNC,
        fieldName: "mcc_mnc"
      )

      // Ensure we convert the test OS name into the enum.
      XCTAssertEqual(
        proto.application_info.apple_app_info.os_name,
        firebase_appquality_sessions_OsName_IOS
      )
    }
  }

  func test_setInstallationID_setsInstallationID() {
    identifiers.mockAllValidIDs()

    let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)
    event.setInstallationID(identifiers: identifiers)

    testProtoAndDecodedProto(sessionEvent: event) { proto in
      assertEqualProtoString(
        proto.session_data.firebase_installation_id,
        expected: MockIdentifierProvider.testInstallationID,
        fieldName: "firebase_installation_id"
      )
    }
  }

  func test_convertOSName_convertsCorrectly() {
    let expectations: [(given: String, expected: firebase_appquality_sessions_OsName)] = [
      ("macos", firebase_appquality_sessions_OsName_MACOS),
      ("maccatalyst", firebase_appquality_sessions_OsName_MACCATALYST),
      ("ios_on_mac", firebase_appquality_sessions_OsName_IOS_ON_MAC),
      ("ios", firebase_appquality_sessions_OsName_IOS),
      ("tvos", firebase_appquality_sessions_OsName_TVOS),
      ("watchos", firebase_appquality_sessions_OsName_WATCHOS),
      ("ipados", firebase_appquality_sessions_OsName_IPADOS),
      ("something unknown", firebase_appquality_sessions_OsName_UNKNOWN_OSNAME),
    ]

    expectations.forEach { (given: String, expected: firebase_appquality_sessions_OsName) in
      appInfo.osName = given

      let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)

      testProtoAndDecodedProto(sessionEvent: event) { proto in
        XCTAssertEqual(event.proto.application_info.apple_app_info.os_name, expected)
      }
    }
  }

  func test_convertLogEnvironment_convertsCorrectly() {
    let expectations: [(given: DevEnvironment,
                        expected: firebase_appquality_sessions_LogEnvironment)] = [
      (.prod, firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_PROD),
      (
        .staging,
        firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_STAGING
      ),
      (
        .autopush,
        firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_AUTOPUSH
      ),
    ]

    expectations.forEach { (given: DevEnvironment,
                            expected: firebase_appquality_sessions_LogEnvironment) in
        appInfo.environment = given

        let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)

        XCTAssertEqual(event.proto.application_info.log_environment, expected)
    }
  }

  func test_dataCollectionState_defaultIsUnknown() {
    identifiers.mockAllValidIDs()

    let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)

    testProtoAndDecodedProto(sessionEvent: event) { proto in
      XCTAssertEqual(
        proto.session_data.data_collection_status.performance,
        firebase_appquality_sessions_DataCollectionState_COLLECTION_UNKNOWN
      )
      XCTAssertEqual(
        proto.session_data.data_collection_status.crashlytics,
        firebase_appquality_sessions_DataCollectionState_COLLECTION_UNKNOWN
      )
    }
  }

  func test_convertNetworkType_convertsCorrectly() {
    let expectations: [(
      given: GULNetworkType,
      expected: firebase_appquality_sessions_NetworkConnectionInfo_NetworkType
    )] = [
      (
        .WIFI,
        firebase_appquality_sessions_NetworkConnectionInfo_NetworkType_WIFI
      ),
      (
        .mobile,
        firebase_appquality_sessions_NetworkConnectionInfo_NetworkType_MOBILE
      ),
      (
        .none,
        firebase_appquality_sessions_NetworkConnectionInfo_NetworkType_DUMMY
      ),
    ]

    expectations.forEach { (
      given: GULNetworkType,
      expected: firebase_appquality_sessions_NetworkConnectionInfo_NetworkType
    ) in
      appInfo.networkType = given

      let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)

      testProtoAndDecodedProto(sessionEvent: event) { proto in
        XCTAssertEqual(
          event.proto.application_info.apple_app_info.network_connection_info.network_type,
          expected
        )
      }
    }
  }

  /// Following tests can be run only in iOS environment
  #if TARGET_OS_IOS
    func test_convertMobileSubtype_convertsCorrectlyPreOS14() {
      let expectations: [(
        given: String,
        expected: firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype
      )] = [
        (
          CTRadioAccessTechnologyGPRS,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_GPRS
        ),
        (
          CTRadioAccessTechnologyEdge,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EDGE
        ),
        (
          CTRadioAccessTechnologyWCDMA,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_CDMA
        ),
        (
          CTRadioAccessTechnologyCDMA1x,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_CDMA
        ),
        (
          CTRadioAccessTechnologyHSDPA,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_HSDPA
        ),
        (
          CTRadioAccessTechnologyHSUPA,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_HSUPA
        ),
        (
          CTRadioAccessTechnologyCDMAEVDORev0,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EVDO_0
        ),
        (
          CTRadioAccessTechnologyCDMAEVDORevA,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EVDO_A
        ),
        (
          CTRadioAccessTechnologyCDMAEVDORevB,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EVDO_B
        ),
        (
          CTRadioAccessTechnologyeHRPD,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EHRPD
        ),
        (
          CTRadioAccessTechnologyLTE,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_LTE
        ),
        (
          "random",
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_UNKNOWN_MOBILE_SUBTYPE
        ),
      ]

      expectations
        .forEach { (
          given: String,
          expected: firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype
        ) in
          appInfo.mobileSubtype = given

          let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)

          testProtoAndDecodedProto(sessionEvent: event) { proto in
            XCTAssertEqual(
              event.proto.application_info.apple_app_info.network_connection_info.mobile_subtype,
              expected
            )
          }
        }
    }
    #endif

    #if TARGET_OS_IOS
    @available(iOS 14.1, *)
    func test_convertMobileSubtype_convertsCorrectlyPostOS14() {
      let expectations: [(
        given: String,
        expected: firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype
      )] = [
        (
          CTRadioAccessTechnologyGPRS,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_GPRS
        ),
        (
          CTRadioAccessTechnologyEdge,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EDGE
        ),
        (
          CTRadioAccessTechnologyWCDMA,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_CDMA
        ),
        (
          CTRadioAccessTechnologyCDMA1x,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_CDMA
        ),
        (
          CTRadioAccessTechnologyHSDPA,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_HSDPA
        ),
        (
          CTRadioAccessTechnologyHSUPA,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_HSUPA
        ),
        (
          CTRadioAccessTechnologyCDMAEVDORev0,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EVDO_0
        ),
        (
          CTRadioAccessTechnologyCDMAEVDORevA,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EVDO_A
        ),
        (
          CTRadioAccessTechnologyCDMAEVDORevB,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EVDO_B
        ),
        (
          CTRadioAccessTechnologyeHRPD,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_EHRPD
        ),
        (
          CTRadioAccessTechnologyLTE,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_LTE
        ),
        (
          CTRadioAccessTechnologyNRNSA,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_NR
        ),
        (
          CTRadioAccessTechnologyNR,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_NR
        ),
        (
          "random",
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_UNKNOWN_MOBILE_SUBTYPE
        ),
      ]

      expectations
        .forEach { (
          given: String,
          expected: firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype
        ) in
          appInfo.mobileSubtype = given

          let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)

          testProtoAndDecodedProto(sessionEvent: event) { proto in
            XCTAssertEqual(
              event.proto.application_info.apple_app_info.network_connection_info.mobile_subtype,
              expected
            )
          }
        }
    }
    #endif
}
