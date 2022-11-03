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

  func test_init_setsSessionIDs() {
    identifiers.mockAllValidIDs()

    let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)
    assertEqualProtoString(
      event.proto.session_data.session_id,
      expected: MockIdentifierProvider.testSessionID,
      fieldName: "session_id"
    )
    assertEqualProtoString(
      event.proto.session_data.previous_session_id,
      expected: MockIdentifierProvider.testPreviousSessionID,
      fieldName: "previous_session_id"
    )

    XCTAssertEqual(event.proto.session_data.event_timestamp_us, 123)
  }

  func test_init_setsApplicationInfo() {
    appInfo.mockAllInfo()

    let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)

    assertEqualProtoString(
      event.proto.application_info.app_id,
      expected: MockApplicationInfo.testAppID,
      fieldName: "app_id"
    )
    assertEqualProtoString(
      event.proto.application_info.session_sdk_version,
      expected: MockApplicationInfo.testSDKVersion,
      fieldName: "session_sdk_version"
    )
    assertEqualProtoString(
      event.proto.application_info.apple_app_info.bundle_short_version,
      expected: MockApplicationInfo.testBundleID,
      fieldName: "bundle_short_version"
    )
    assertEqualProtoString(
      event.proto.application_info.apple_app_info.mcc_mnc,
      expected: MockApplicationInfo.testMCCMNC,
      fieldName: "mcc_mnc"
    )

    // Ensure we convert the test OS name into the enum.
    XCTAssertEqual(
      event.proto.application_info.apple_app_info.os_name,
      firebase_appquality_sessions_OsName_IOS
    )
  }

  func test_setInstallationID_setsInstallationID() {
    identifiers.mockAllValidIDs()

    let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)
    event.setInstallationID(identifiers: identifiers)
    assertEqualProtoString(
      event.proto.session_data.firebase_installation_id,
      expected: MockIdentifierProvider.testInstallationID,
      fieldName: "firebase_installation_id"
    )
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

      XCTAssertEqual(event.proto.application_info.apple_app_info.os_name, expected)
    }
  }
  
  func test_convertLogEnvironment_convertsCorrectly() {
    let expectations: [(given: String, expected: firebase_appquality_sessions_LogEnvironment)] = [
      ("prod", firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_PROD),
      ("staging", firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_STAGING),
      ("autopush", firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_AUTOPUSH),
      ("PROD", firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_PROD),
      ("STAGING", firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_STAGING),
      ("AUTOPUSH", firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_AUTOPUSH),
      ("", firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_UNKNOWN),
      (" ", firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_UNKNOWN),
      ("random", firebase_appquality_sessions_LogEnvironment_LOG_ENVIRONMENT_UNKNOWN),
    ]

    expectations.forEach { (given: String, expected: firebase_appquality_sessions_LogEnvironment) in
      appInfo.environment = given

      let event = SessionStartEvent(identifiers: identifiers, appInfo: appInfo, time: time)

      XCTAssertEqual(event.proto.application_info.log_environment, expected)
    }
  }
}
