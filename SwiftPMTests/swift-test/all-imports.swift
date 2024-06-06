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

import Firebase
import FirebaseABTesting
import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import Foundation
#if os(iOS) && !targetEnvironment(macCatalyst)
  import FirebaseAppDistribution
#endif
import FirebaseCrashlytics
import FirebaseDatabase
import FirebaseDynamicLinks
import FirebaseFirestore
import FirebaseFunctions
import FirebaseInstallations
import FirebaseMessaging
#if (os(iOS) && !targetEnvironment(macCatalyst)) || os(tvOS)
  import FirebasePerformance

  @testable import FirebaseInAppMessaging
  import SwiftUI
#endif
import FirebaseRemoteConfig
import FirebaseSessions
import FirebaseStorage
import GoogleDataTransport
import GoogleUtilities_AppDelegateSwizzler
import GoogleUtilities_Environment
import GoogleUtilities_Logger
import GoogleUtilities_Network
import GoogleUtilities_NSData
import GoogleUtilities_Reachability
import GoogleUtilities_UserDefaults
import nanopb

import XCTest

@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
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
    #if os(macOS) || targetEnvironment(macCatalyst)
      // Device model should now return the appropriate hardware model on macOS.
      XCTAssertNotEqual(GULAppEnvironmentUtil.deviceModel(), "x86_64")
    #else
      // Device model should show up as x86_64 for iOS, tvOS, and watchOS
      // simulators.
      let model = GULAppEnvironmentUtil.deviceModel()
      XCTAssertTrue(model == "x86_64" || model == "arm64")
    #endif

    let versionParts = FirebaseVersion().split(separator: ".")
    XCTAssert(versionParts.count == 3)
    XCTAssertNotNil(Int(versionParts[0]))
    XCTAssertNotNil(Int(versionParts[1]))

    print("System version? Answer: \(GULAppEnvironmentUtil.systemVersion())")
  }

  #if (os(iOS) || os(tvOS)) && !targetEnvironment(macCatalyst)
    func testSwiftUI() {
      if #available(iOS 13, tvOS 13, *) {
        _ = ImageOnlyInAppMessageDisplayViewModifier { _, _ in
          EmptyView()
        }

        _ = BannerInAppMessageDisplayViewModifier { _, _ in
          EmptyView()
        }

        _ = CardInAppMessageDisplayViewModifier { _, _ in
          EmptyView()
        }

        _ = ModalInAppMessageDisplayViewModifier { _, _ in
          EmptyView()
        }

        XCTAssertNotNil(
          EmptyView().imageOnlyInAppMessage { _, _ in
            EmptyView()
          }
        )

        XCTAssertNotNil(
          EmptyView().bannerInAppMessage { _, _ in
            EmptyView()
          }
        )

        XCTAssertNotNil(
          EmptyView().cardInAppMessage { _, _ in
            EmptyView()
          }
        )

        XCTAssertNotNil(
          EmptyView().modalInAppMessage { _, _ in
            EmptyView()
          }
        )
      }
    }
  #endif
}
