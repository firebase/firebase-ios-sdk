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
import FirebaseAppCheck
#if os(iOS) && !targetEnvironment(macCatalyst)
  import FirebaseAppDistribution
#endif
import FirebaseCrashlytics
import FirebaseDatabase
import FirebaseDynamicLinks
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions
#if (os(iOS) || os(tvOS)) && !targetEnvironment(macCatalyst)
  import FirebaseInAppMessaging
  @testable import FirebaseInAppMessagingSwift
  import SwiftUI
#endif
import FirebaseInstallations
import FirebaseMessaging
#if (os(iOS) && !targetEnvironment(macCatalyst)) || os(tvOS)
  import FirebasePerformance
#endif
import FirebaseRemoteConfig
import FirebaseStorage
import FirebaseStorageSwift
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
    XCTAssertEqual(GULAppEnvironmentUtil.deviceModel(), "x86_64")

    let versionParts = FirebaseVersion().split(separator: ".")
    XCTAssert(versionParts.count == 3)
    XCTAssertEqual(Int(versionParts[0]), 8)
    XCTAssertNotNil(Int(versionParts[1]))
    XCTAssertNotNil(Int(versionParts[2]))

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
