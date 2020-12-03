// Copyright 2020 Google LLC
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
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseABTesting
#if os(iOS)
  import FirebaseAnalytics
  import FirebaseAppDistribution
#endif
import FirebaseCrashlytics
import FirebaseDynamicLinks
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions
import FirebaseInAppMessaging
import FirebaseInstallations
import FirebaseMessaging
import FirebaseRemoteConfig
import FirebaseStorage
import FirebaseStorageSwift
import GoogleDataTransport
import GoogleUtilities_AppDelegateSwizzler
import GoogleUtilities_Environment
import GoogleUtilities_Logger
import GoogleUtilities_MethodSwizzler
import GoogleUtilities_Network
import GoogleUtilities_NSData
import GoogleUtilities_Reachability
import GoogleUtilities_UserDefaults
import nanopb

import XCTest

class importTest: XCTestCase {
  func testImports() throws {
    XCTAssertFalse(GULAppEnvironmentUtil.isAppStoreReceiptSandbox())
    XCTAssertFalse(GULAppEnvironmentUtil.isFromAppStore())
    #if targetEnvironment(simulator)
      XCTAssertTrue(GULAppEnvironmentUtil.isSimulator())
    #else
      XCTAssertFalse(GULAppEnvironmentUtil.isSimulator())
    #endif
    XCTAssertFalse(GULAppEnvironmentUtil.isAppExtension())
    XCTAssertNil(FirebaseApp.app())
    XCTAssertEqual(GULAppEnvironmentUtil.deviceModel(), "x86_64")

    let versionParts = FirebaseVersion().split(separator: ".")
    XCTAssert(versionParts.count == 3)
    XCTAssertEqual(Int(versionParts[0]), 7)
    XCTAssertNotNil(Int(versionParts[1]))
    XCTAssertNotNil(Int(versionParts[2]))

    print("System version? Answer: \(GULAppEnvironmentUtil.systemVersion())")
  }
}
