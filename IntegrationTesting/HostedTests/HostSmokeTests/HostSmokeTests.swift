// Copyright 2026 Google LLC
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

import FirebaseCore
import Security
import UIKit
import XCTest

/// Checks that `FirebaseTestHost` provides what hosted SDK test suites rely on and that Swift
/// Package Manager test bundles don't have.
final class HostSmokeTests: XCTestCase {
  private var testBundle: Bundle { Bundle(for: HostSmokeTests.self) }

  /// A keychain item can be added, read, and deleted. Without a host app, `SecItemAdd` can fail
  /// with `errSecMissingEntitlement` (-34018).
  func testKeychainRoundTrip() throws {
    // A unique service name keeps this item apart from items that other test suites running in
    // the same host add.
    let service = "com.google.firebase.HostSmokeTests.\(UUID().uuidString)"
    let query = Self.keychainQuery(service: service)
    addTeardownBlock {
      SecItemDelete(Self.keychainQuery(service: service) as CFDictionary)
    }
    let value = Data("value".utf8)

    var addQuery = query
    addQuery[kSecValueData as String] = value
    XCTAssertEqual(SecItemAdd(addQuery as CFDictionary, nil), errSecSuccess)

    var readQuery = query
    readQuery[kSecReturnData as String] = true
    readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    XCTAssertEqual(SecItemCopyMatching(readQuery as CFDictionary, &result), errSecSuccess)
    XCTAssertEqual(result as? Data, value)

    XCTAssertEqual(SecItemDelete(query as CFDictionary), errSecSuccess)
    XCTAssertEqual(SecItemCopyMatching(readQuery as CFDictionary, nil), errSecItemNotFound)
  }

  private static func keychainQuery(service: String) -> [String: Any] {
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: "HostSmokeTests",
    ]
  }

  /// The host's app delegate is in place, for SDKs that look up or swizzle it.
  @MainActor
  func testSharedApplicationHasHostDelegate() throws {
    let delegate = try XCTUnwrap(UIApplication.shared.delegate)
    XCTAssertEqual(NSStringFromClass(type(of: delegate)), "FIRTestHostAppDelegate")
  }

  /// A file copied into the test bundle by the "Copy GoogleService-Info.plist" build phase can be
  /// read, and the host app has no copy.
  func testGoogleServiceInfoPlistIsInTestBundleOnly() throws {
    let path = try XCTUnwrap(
      testBundle.path(forResource: "GoogleService-Info", ofType: "plist")
    )
    let options = try XCTUnwrap(FirebaseOptions(contentsOfFile: path))
    XCTAssertEqual(options.googleAppID, "1:123:ios:123abc")
    XCTAssertEqual(options.projectID, "hosted-tests-smoke")

    XCTAssertNil(Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"))
  }

  /// FirebaseCore is linked into the test bundle, not the host app.
  func testFirebaseCoreIsLinkedIntoTestBundle() {
    XCTAssertEqual(Bundle(for: FirebaseApp.self), testBundle)
    XCTAssertNotEqual(testBundle, Bundle.main)
  }
}
