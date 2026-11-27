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
internal import FirebaseCoreExtension
import FirebaseCoreTestHooks
import Foundation
import XCTest

/// Tests for GOOGLE_APP_ID validation. Ported from FirebaseCore/Tests/Unit/FIRAppTest.m.
///
/// Intentionally dropped: FIRAppTest.m stubbed `+[FIRApp actualBundleID]` in
/// testAppIDFormatInvalid and testAppIDContainsInvalidBundleIDHash, but neither validation method
/// reads it, so the stubs had no effect.
final class FirebaseAppIDTests: CoreTestCase {
  func testAppIDV1() {
    // Missing separator between platform:hashed bundle ID.
    XCTAssertFalse(FirebaseApp.validateAppID("1:1337:iosdeadbeef"))
    // Wrong platform "android".
    XCTAssertFalse(FirebaseApp.validateAppID("1:1337:android:deadbeef"))
    // The hashed bundle ID, aka 4th field, should only contain hex characters.
    XCTAssertFalse(FirebaseApp.validateAppID("1:1337:ios:123abcxyz"))
    // The hashed bundle ID isn't checked in v1, so an unknown value doesn't cause a failure.
    XCTAssertTrue(FirebaseApp.validateAppID("1:1337:ios:deadbeef"))
  }

  func testAppIDV2() {
    // Unknown versions aren't checked beyond the version prefix, so anything after it passes.
    XCTAssertTrue(FirebaseApp.validateAppID("2:1337:ios5e18052ab54fbfec"))
    XCTAssertTrue(FirebaseApp.validateAppID("2:1337:ios:123abcxyz"))
    XCTAssertTrue(FirebaseApp.validateAppID("2:thisdoesn'teven_m:a:t:t:e:r_"))
    // Known good hashed bundle ID.
    XCTAssertTrue(FirebaseApp.validateAppID("2:1337:ios:5e18052ab54fbfec"))
    // Unknown hashed bundle ID, not tested so shouldn't cause a failure.
    XCTAssertTrue(FirebaseApp.validateAppID("2:1337:ios:deadbeef"))
  }

  func testAppIDV3() {
    // There's no specification for v3, so it isn't expected to fail.
    XCTAssertTrue(FirebaseApp.validateAppID("3:1337:ios:deadbeef"))
  }

  func testAppIDEmpty() {
    XCTAssertFalse(FirebaseApp.validateAppID(""))
    XCTAssertFalse(FirebaseApp.validateAppID(nil))
  }

  func testAppIDPrefix() {
    // Unknown numeric prefixes pass.
    for appID in ["0:", "01:", "10:", "010:", "3:", "123:", "999999999:"] {
      XCTAssertTrue(FirebaseApp.validateAppID(appID), appID)
    }
    // Non-numeric prefixes don't pass.
    for appID in ["a:", "abcsdf0:", "0aaaa:", "0aaaa0450:", "-1:", "abcsdf:", "ABDCF:", " :",
                  "1 :", " 1:", " 123 :", "1 23:", "&($*&%(*$&:", "abCDSF$%%df:"] {
      XCTAssertFalse(FirebaseApp.validateAppID(appID), appID)
    }
    // Known version prefixes never pass without the rest of the app ID.
    XCTAssertFalse(FirebaseApp.validateAppID("1:"))
    // The version must be followed by ":".
    for appID in ["0", "01", "10", "010", "3", "123", "999999999", "com.google.bundleID"] {
      XCTAssertFalse(FirebaseApp.validateAppID(appID), appID)
    }
  }

  func testAppIDFormatInvalid() {
    let goodAppIDV1 = "1:1337:ios:deadbeef"
    let goodVersionV1 = "1"
    let goodAppIDV2 = "2:1337:ios:5e18052ab54fbfec"
    let goodVersionV2 = "2"
    // Sanity checks first.
    XCTAssertTrue(FirebaseApp.validateAppIDFormat(goodAppIDV1, withVersion: goodVersionV1))
    XCTAssertTrue(FirebaseApp.validateAppIDFormat(goodAppIDV2, withVersion: goodVersionV2))

    // Version mismatch.
    XCTAssertFalse(FirebaseApp.validateAppIDFormat(goodAppIDV2, withVersion: goodVersionV1))
    XCTAssertFalse(FirebaseApp.validateAppIDFormat(goodAppIDV1, withVersion: goodVersionV2))
    XCTAssertFalse(FirebaseApp.validateAppIDFormat(goodAppIDV1, withVersion: "999:"))

    // Nil or empty strings.
    XCTAssertFalse(FirebaseApp.validateAppIDFormat(goodAppIDV1, withVersion: nil))
    XCTAssertFalse(FirebaseApp.validateAppIDFormat(goodAppIDV1, withVersion: ""))
    XCTAssertFalse(FirebaseApp.validateAppIDFormat(nil, withVersion: goodVersionV1))
    XCTAssertFalse(FirebaseApp.validateAppIDFormat("", withVersion: goodVersionV1))
    XCTAssertFalse(FirebaseApp.validateAppIDFormat(nil, withVersion: nil))
    XCTAssertFalse(FirebaseApp.validateAppIDFormat("", withVersion: ""))

    // The app ID is only the version prefix.
    XCTAssertFalse(FirebaseApp.validateAppIDFormat(goodVersionV1, withVersion: goodVersionV1))
    // The version is the entire app ID.
    XCTAssertFalse(FirebaseApp.validateAppIDFormat(goodAppIDV1, withVersion: goodAppIDV1))

    // Version digits that may make a partial match.
    for appID in ["01:1337:ios:deadbeef", "10:1337:ios:deadbeef", "11:1337:ios:deadbeef"] {
      XCTAssertFalse(FirebaseApp.validateAppIDFormat(appID, withVersion: goodVersionV1), appID)
    }
    for appID in ["21:1337:ios:5e18052ab54fbfec", "22:1337:ios:5e18052ab54fbfec",
                  "02:1337:ios:5e18052ab54fbfec", "20:1337:ios:5e18052ab54fbfec"] {
      XCTAssertFalse(FirebaseApp.validateAppIDFormat(appID, withVersion: goodVersionV2), appID)
    }

    // Extra fields.
    for appID in ["ab:1:1337:ios:deadbeef", "1:ab:1337:ios:deadbeef", "1:1337:ab:ios:deadbeef",
                  "1:1337:ios:ab:deadbeef", "1:1337:ios:deadbeef:ab"] {
      XCTAssertFalse(FirebaseApp.validateAppIDFormat(appID, withVersion: goodVersionV1), appID)
    }
  }

  func testAppIDContainsInvalidBundleIDHash() {
    let goodAppIDV1 = "1:1337:ios:deadbeef"
    let goodVersionV1 = "1"
    // Sanity check first.
    XCTAssertTrue(FirebaseApp.validateBundleIDHash(withinAppID: goodAppIDV1,
                                                   forVersion: goodVersionV1))
    // Only v1 is known, so the hash of other versions isn't valid.
    XCTAssertFalse(FirebaseApp.validateBundleIDHash(withinAppID: "2:1337:ios:5e18052ab54fbfec",
                                                    forVersion: "2"))

    // Nil or empty strings.
    XCTAssertFalse(FirebaseApp.validateBundleIDHash(withinAppID: goodAppIDV1, forVersion: nil))
    XCTAssertFalse(FirebaseApp.validateBundleIDHash(withinAppID: goodAppIDV1, forVersion: ""))
    XCTAssertFalse(FirebaseApp.validateBundleIDHash(withinAppID: nil, forVersion: goodVersionV1))
    XCTAssertFalse(FirebaseApp.validateBundleIDHash(withinAppID: "", forVersion: goodVersionV1))
    XCTAssertFalse(FirebaseApp.validateBundleIDHash(withinAppID: nil, forVersion: nil))
    XCTAssertFalse(FirebaseApp.validateBundleIDHash(withinAppID: "", forVersion: ""))

    // The app ID is only the version prefix.
    XCTAssertFalse(FirebaseApp.validateBundleIDHash(withinAppID: goodVersionV1,
                                                    forVersion: goodVersionV1))
    // The version is the entire app ID.
    XCTAssertFalse(FirebaseApp.validateBundleIDHash(withinAppID: goodAppIDV1,
                                                    forVersion: goodAppIDV1))
  }

  /// Replaces testAppIDValidationTrue and testAppIDValidationFalse, which stubbed
  /// `+validateAppID:` to check that `-isAppIDValid` returns its result. This checks the same thing
  /// with real app IDs.
  func testIsAppIDValidMatchesValidateAppID() {
    let appIDs = [TestValues.googleAppID, "2:1337:ios:5e18052ab54fbfec", "", "1:1337:android:abc",
                  "1:1337:ios:123abcxyz", "a:"]
    var results = Set<Bool>()
    for appID in appIDs {
      let app = FirebaseApp(instanceWithName: "testIsAppIDValid",
                            options: makeAppOptions(googleAppID: appID))
      let expected = FirebaseApp.validateAppID(appID)
      XCTAssertEqual(app.isAppIDValid(), expected, appID)
      results.insert(expected)
    }
    XCTAssertEqual(results, [true, false], "The app IDs should cover valid and invalid IDs")
  }

  func testConfigureWithInvalidAppIDRaises() {
    // configureCore fails for an invalid GOOGLE_APP_ID, so the app isn't added.
    assertRaisesCoreException {
      FirebaseApp.configure(name: "testInvalidAppID",
                            options: makeAppOptions(googleAppID: "1:1337:android:deadbeef"))
    }
    XCTAssertNil(FirebaseApp.app(name: "testInvalidAppID"))
  }
}
