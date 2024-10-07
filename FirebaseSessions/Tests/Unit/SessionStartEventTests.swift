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

#if SWIFT_PACKAGE
  import FirebaseSessionsObjC
#endif // SWIFT_PACKAGE

#if SWIFT_PACKAGE
  @_implementationOnly import GoogleUtilities_Environment
#else
  @_implementationOnly import GoogleUtilities
#endif // SWIFT_PACKAGE

@testable import FirebaseSessions

class SessionStartEventTests: XCTestCase {
  var time: MockTimeProvider!
  var appInfo: MockApplicationInfo!

  override func setUp() {
    super.setUp()

    time = MockTimeProvider()
    appInfo = MockApplicationInfo()
  }

  var defaultSessionInfo: SessionInfo {
    return SessionInfo(
      sessionId: "test_session_id",
      firstSessionId: "test_first_session_id",
      dispatchEvents: true,
      sessionIndex: 0
    )
  }

  var thirdSessionInfo: SessionInfo {
    return SessionInfo(
      sessionId: "test_third_session_id",
      firstSessionId: "test_first_session_id",
      dispatchEvents: true,
      sessionIndex: 2
    )
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

  func test_init_setsSessionData() {
    let event = SessionStartEvent(sessionInfo: thirdSessionInfo, appInfo: appInfo, time: time)

    testProtoAndDecodedProto(sessionEvent: event) { proto in
      assertEqualProtoString(
        proto.session_data.session_id,
        expected: "test_third_session_id",
        fieldName: "session_id"
      )
      assertEqualProtoString(
        proto.session_data.first_session_id,
        expected: "test_first_session_id",
        fieldName: "first_session_id"
      )
      XCTAssertEqual(proto.session_data.session_index, 2)

      XCTAssertEqual(proto.session_data.event_timestamp_us, 123)
    }
  }

  func test_init_setsApplicationInfo() {
    let event = SessionStartEvent(sessionInfo: defaultSessionInfo, appInfo: appInfo, time: time)

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
        proto.application_info.os_version,
        expected: MockApplicationInfo.testOsDisplayVersion,
        fieldName: "os_version"
      )
      assertEqualProtoString(
        proto.application_info.apple_app_info.bundle_short_version,
        expected: MockApplicationInfo.testAppDisplayVersion,
        fieldName: "bundle_short_version"
      )
      assertEqualProtoString(
        proto.application_info.apple_app_info.app_build_version,
        expected: MockApplicationInfo.testAppBuildVersion,
        fieldName: "app_build_version"
      )
      assertEqualProtoString(
        proto.application_info.device_model,
        expected: MockApplicationInfo.testDeviceModel,
        fieldName: "device_model"
      )

      // Ensure we convert the test OS name into the enum.
      XCTAssertEqual(
        proto.application_info.apple_app_info.os_name,
        firebase_appquality_sessions_OsName_IOS
      )
    }
  }

  func test_setInstallationID_setsInstallationID() {
    let event = SessionStartEvent(sessionInfo: defaultSessionInfo, appInfo: appInfo, time: time)

    event.setInstallationID(installationId: "testInstallationID")

    testProtoAndDecodedProto(sessionEvent: event) { proto in
      assertEqualProtoString(
        proto.session_data.firebase_installation_id,
        expected: "testInstallationID",
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

    for (given, expected) in expectations {
      appInfo.osName = given

      let event = SessionStartEvent(
        sessionInfo: defaultSessionInfo,
        appInfo: appInfo,
        time: time
      )

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

    for (given, expected) in expectations {
      appInfo.environment = given

      let event = SessionStartEvent(
        sessionInfo: defaultSessionInfo,
        appInfo: appInfo,
        time: time
      )

      XCTAssertEqual(event.proto.application_info.log_environment, expected)
    }
  }

  func test_dataCollectionState_defaultIsUnknown() {
    let event = SessionStartEvent(sessionInfo: defaultSessionInfo, appInfo: appInfo, time: time)

    testProtoAndDecodedProto(sessionEvent: event) { proto in
      XCTAssertEqual(
        proto.session_data.data_collection_status.performance,
        firebase_appquality_sessions_DataCollectionState_COLLECTION_SDK_NOT_INSTALLED
      )
      XCTAssertEqual(
        proto.session_data.data_collection_status.crashlytics,
        firebase_appquality_sessions_DataCollectionState_COLLECTION_SDK_NOT_INSTALLED
      )
    }
  }

  func test_networkInfo_onlyPresentWhenPerformanceInstalled() {
    let mockNetworkInfo = MockNetworkInfo()
    mockNetworkInfo.networkType = .mobile
    // Mobile Subtypes are always empty on non-iOS platforms, and
    // Performance doesn't support those platforms anyways
    #if os(iOS) && !targetEnvironment(macCatalyst)
      mockNetworkInfo.mobileSubtype = CTRadioAccessTechnologyHSUPA
    #else // os(iOS) && !targetEnvironment(macCatalyst)
      mockNetworkInfo.mobileSubtype = ""
    #endif // os(iOS) && !targetEnvironment(macCatalyst)
    appInfo.networkInfo = mockNetworkInfo

    let event = SessionStartEvent(sessionInfo: defaultSessionInfo, appInfo: appInfo, time: time)

    // These fields will not be filled in when Crashlytics is installed
    event.set(subscriber: .Crashlytics, isDataCollectionEnabled: true, appInfo: appInfo)

    // They should also not be filled in when Performance data collection is disabled
    event.set(subscriber: .Performance, isDataCollectionEnabled: false, appInfo: appInfo)

    // Expect empty because Crashlytics is installed, but not Perf
    testProtoAndDecodedProto(sessionEvent: event) { proto in
      XCTAssertEqual(
        event.proto.application_info.apple_app_info.network_connection_info.network_type,
        firebase_appquality_sessions_NetworkConnectionInfo_NetworkType_DUMMY
      )
      XCTAssertEqual(
        event.proto.application_info.apple_app_info.network_connection_info.mobile_subtype,
        firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_UNKNOWN_MOBILE_SUBTYPE
      )
      assertEqualProtoString(
        proto.application_info.apple_app_info.mcc_mnc,
        expected: "",
        fieldName: "mcc_mnc"
      )
    }

    // These fields will only be filled in when the Perf SDK is installed
    event.set(subscriber: .Performance, isDataCollectionEnabled: true, appInfo: appInfo)

    // Now the field should be set with the real thing
    testProtoAndDecodedProto(sessionEvent: event) { proto in
      XCTAssertEqual(
        event.proto.application_info.apple_app_info.network_connection_info.network_type,
        firebase_appquality_sessions_NetworkConnectionInfo_NetworkType_MOBILE
      )
      // Mobile Subtypes are always empty on non-iOS platforms, and
      // Performance doesn't support those platforms anyways
      #if os(iOS) && !targetEnvironment(macCatalyst)
        XCTAssertEqual(
          event.proto.application_info.apple_app_info.network_connection_info.mobile_subtype,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_HSUPA
        )
      #else // os(iOS) && !targetEnvironment(macCatalyst)
        XCTAssertEqual(
          event.proto.application_info.apple_app_info.network_connection_info.mobile_subtype,
          firebase_appquality_sessions_NetworkConnectionInfo_MobileSubtype_UNKNOWN_MOBILE_SUBTYPE
        )
      #endif // os(iOS) && !targetEnvironment(macCatalyst)

      assertEqualProtoString(
        proto.application_info.apple_app_info.mcc_mnc,
        expected: "",
        fieldName: "mcc_mnc"
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

    for (given, expected) in expectations {
      let mockNetworkInfo = MockNetworkInfo()
      mockNetworkInfo.networkType = given
      appInfo.networkInfo = mockNetworkInfo

      let event = SessionStartEvent(
        sessionInfo: defaultSessionInfo,
        appInfo: appInfo,
        time: time
      )

      // These fields will only be filled in when the Perf SDK is installed
      event.set(subscriber: .Performance, isDataCollectionEnabled: true, appInfo: appInfo)

      testProtoAndDecodedProto(sessionEvent: event) { proto in
        XCTAssertEqual(
          event.proto.application_info.apple_app_info.network_connection_info.network_type,
          expected
        )
      }
    }
  }

  /// Following tests can be run only in iOS environment
  #if os(iOS) && !targetEnvironment(macCatalyst)
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

      for (given, expected) in expectations {
        let mockNetworkInfo = MockNetworkInfo()
        mockNetworkInfo.mobileSubtype = given
        appInfo.networkInfo = mockNetworkInfo

        let event = SessionStartEvent(
          sessionInfo: defaultSessionInfo,
          appInfo: appInfo,
          time: time
        )

        // These fields will only be filled in when the Perf SDK is installed
        event.set(subscriber: .Performance, isDataCollectionEnabled: true, appInfo: appInfo)

        testProtoAndDecodedProto(sessionEvent: event) { proto in
          XCTAssertEqual(
            event.proto.application_info.apple_app_info.network_connection_info
              .mobile_subtype,
            expected
          )
        }
      }
    }
  #endif // os(iOS) && !targetEnvironment(macCatalyst)

  #if os(iOS) && !targetEnvironment(macCatalyst)
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

      for (given, expected) in expectations {
        let mockNetworkInfo = MockNetworkInfo()
        mockNetworkInfo.mobileSubtype = given
        appInfo.networkInfo = mockNetworkInfo

        let event = SessionStartEvent(
          sessionInfo: defaultSessionInfo,
          appInfo: appInfo,
          time: time
        )

        // These fields will only be filled in when the Perf SDK is installed
        event.set(subscriber: .Performance, isDataCollectionEnabled: true, appInfo: appInfo)

        testProtoAndDecodedProto(sessionEvent: event) { proto in
          XCTAssertEqual(
            event.proto.application_info.apple_app_info.network_connection_info
              .mobile_subtype,
            expected
          )
        }
      }
    }
  #endif // os(iOS) && !targetEnvironment(macCatalyst)
}
