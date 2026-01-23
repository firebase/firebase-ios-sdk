// Copyright 2025 Google LLC
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
@testable import FirebaseCoreInternal

class BundleUtilTests: XCTestCase {

  func testRelevantBundles() {
    let bundles = BundleUtil.relevantBundles()
    XCTAssertFalse(bundles.isEmpty)
    XCTAssertEqual(bundles.first, Bundle.main)
    XCTAssertTrue(bundles.contains(Bundle(for: BundleUtil.self)))
  }

  func testRelevantURLSchemes() {
    // Just verify it doesn't crash and returns valid array (empty or not)
    let schemes = BundleUtil.relevantURLSchemes()
    // It might be empty in test environment
    XCTAssertNotNil(schemes)
  }

  func testOptionsDictionaryPath_NotFound() {
    let bundles = [Bundle.main]
    let path = BundleUtil.optionsDictionaryPath(resourceName: "NonExistentResource",
                                                fileType: "plist",
                                                in: bundles)
    XCTAssertNil(path)
  }

  func testHasBundleIdentifierPrefix_Match() {
    guard let mainBundleID = Bundle.main.bundleIdentifier else {
      print("Skipping testHasBundleIdentifierPrefix_Match because Bundle.main has no identifier.")
      return
    }

    let bundles = [Bundle.main]
    XCTAssertTrue(BundleUtil.hasBundleIdentifierPrefix(mainBundleID, in: bundles))
  }

  func testHasBundleIdentifierPrefix_NoMatch() {
     let bundles = [Bundle.main]
     XCTAssertFalse(BundleUtil.hasBundleIdentifierPrefix("com.google.nonexistent", in: bundles))
  }
}
