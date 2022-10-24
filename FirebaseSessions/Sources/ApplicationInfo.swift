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

@_implementationOnly import FirebaseCore
@_implementationOnly import GoogleUtilities

protocol ApplicationInfoProtocol {
  /// Google App ID / GMP App ID
  var appID: String { get }

  /// App's bundle ID / bundle short version
  var bundleID: String { get }

  /// Version of the Firebase SDK
  var sdkVersion: String { get }

  /// Crashlytics-specific device / OS filter values.
  var osName: String { get }

  /// Validated Mobile Country Code and Mobile Network Code
  var mccMNC: String { get }
}

class ApplicationInfo: ApplicationInfoProtocol {
  let appID: String

  private let networkInfo: NetworkInfoProtocol

  init(appID: String, networkInfo: NetworkInfoProtocol = NetworkInfo()) {
    self.appID = appID
    self.networkInfo = networkInfo
  }

  var bundleID: String {
    return Bundle.main.bundleIdentifier ?? ""
  }

  var sdkVersion: String {
    return FirebaseVersion()
  }

  var osName: String {
    // TODO: Update once https://github.com/google/GoogleUtilities/pull/89 is released
    // to production, update this to GULAppEnvironmentUtil.appleDevicePlatform() and update
    // the podfile to depend on the newest version of GoogleUtilities
    return GULAppEnvironmentUtil.applePlatform()
  }

  var mccMNC: String {
    return FIRSESValidateMccMnc(networkInfo.mobileCountryCode, networkInfo.mobileNetworkCode)
  }
}
