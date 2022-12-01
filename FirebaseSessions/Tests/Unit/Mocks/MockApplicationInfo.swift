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

@_implementationOnly import GoogleUtilities

@testable import FirebaseSessions

class MockApplicationInfo: ApplicationInfoProtocol {
  var appID: String = ""

  var bundleID: String = ""

  var sdkVersion: String = ""

  var osName: String = ""

  var deviceModel: String = ""

  var mccMNC: String = ""

  var environment: DevEnvironment = .prod

  var appBuildVersion: String = ""

  var appDisplayVersion: String = ""

  var networkInfo: NetworkInfoProtocol = MockNetworkInfo()

  static let testAppID = "testAppID"
  static let testBundleID = "testBundleID"
  static let testSDKVersion = "testSDKVersion"
  static let testOSName = "ios"
  static let testMCCMNC = "testMCCMNC"
  static let testDeviceModel = "testDeviceModel"
  static let testEnvironment: DevEnvironment = .prod
  static let testAppBuildVersion = "testAppBuildVersion"
  static let testAppDisplayVersion = "testAppDisplayVersion"
  static let testNetworkType = GULNetworkType.WIFI
  static let testMobileSubtype = "random"

  func mockAllInfo() {
    appID = MockApplicationInfo.testAppID
    bundleID = MockApplicationInfo.testBundleID
    sdkVersion = MockApplicationInfo.testSDKVersion
    osName = MockApplicationInfo.testOSName
    mccMNC = MockApplicationInfo.testMCCMNC
    deviceModel = MockApplicationInfo.testDeviceModel
    environment = MockApplicationInfo.testEnvironment
    appBuildVersion = MockApplicationInfo.testAppBuildVersion
    appDisplayVersion = MockApplicationInfo.testAppDisplayVersion
  }
}
