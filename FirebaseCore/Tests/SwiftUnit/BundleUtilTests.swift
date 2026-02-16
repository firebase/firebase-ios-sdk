// Copyright 2024 Google LLC
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
import XCTest

// FIRBundleUtil is exposed via FirebaseCoreExtension in SPM
#if canImport(FirebaseCoreExtension)
  import FirebaseCoreExtension
#endif

// Or via bridging header in CocoaPods (where it's just available)

// We use the ObjC class name directly.

final class MockBundle: Bundle, @unchecked Sendable {
  var mockedBundleIdentifier: String?
  var mockedPaths: [String: String] = [:]
  var mockedInfoDictionary: [String: Any] = [:]

  override var bundleIdentifier: String? {
    return mockedBundleIdentifier
  }

  override func path(forResource name: String?, ofType ext: String?) -> String? {
    guard let name = name, let ext = ext else { return nil }
    return mockedPaths["\(name).\(ext)"]
  }

  override func object(forInfoDictionaryKey key: String) -> Any? {
    return mockedInfoDictionary[key]
  }
}

final class BundleUtilTests: XCTestCase {
  private var mockBundle: MockBundle!

  override func setUp() {
    super.setUp()
    mockBundle = MockBundle()
  }

  override func tearDown() {
    mockBundle = nil
    super.tearDown()
  }

  func testRelevantBundlesContainsMain() {
    let bundles = FIRBundleUtil.relevantBundles()
    let containsMain = bundles.contains { ($0 as? Bundle) == Bundle.main }
    XCTAssertTrue(containsMain, "Relevant bundles should contain main bundle")
  }

  func testFindOptionsDictionaryPath() {
    let resourceName = "GoogleService-Info"
    let fileType = "plist"
    let expectedPath = "/path/to/GoogleService-Info.plist"

    mockBundle.mockedPaths["\(resourceName).\(fileType)"] = expectedPath

    let path = FIRBundleUtil.optionsDictionaryPath(
      withResourceName: resourceName,
      andFileType: fileType,
      inBundles: [mockBundle!]
    )
    XCTAssertEqual(path, expectedPath)
  }

  func testFindOptionsDictionaryPath_NotFound() {
    let path = FIRBundleUtil.optionsDictionaryPath(
      withResourceName: "GoogleService-Info",
      andFileType: "plist",
      inBundles: [mockBundle!]
    )
    XCTAssertNil(path)
  }

  func testFindOptionsDictionaryPath_SecondBundle() {
    let resourceName = "GoogleService-Info"
    let fileType = "plist"
    let expectedPath = "/path/to/GoogleService-Info.plist"

    let emptyBundle = MockBundle()
    mockBundle.mockedPaths["\(resourceName).\(fileType)"] = expectedPath

    let path = FIRBundleUtil.optionsDictionaryPath(
      withResourceName: resourceName,
      andFileType: fileType,
      inBundles: [emptyBundle, mockBundle!]
    )
    XCTAssertEqual(path, expectedPath)
  }

  func testBundleIdentifierExistsInBundles() {
    let bundleID = "com.google.test"
    mockBundle.mockedBundleIdentifier = bundleID

    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix(
      bundleID,
      inBundles: [mockBundle!],
      isAppExtension: false
    ))
  }

  func testBundleIdentifierExistsInBundles_NotExist() {
    mockBundle.mockedBundleIdentifier = "com.google.test"
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix(
      "not-exist",
      inBundles: [mockBundle!],
      isAppExtension: false
    ))
  }

  func testBundleIdentifierExistsInBundles_EmptyBundles() {
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix(
      "com.google.test",
      inBundles: [],
      isAppExtension: false
    ))
  }

  func testBundleIdentifierHasPrefixInBundlesForExtension() {
    let appBundleID = "com.google.test"
    // Extension bundle ID typically has a suffix
    mockBundle.mockedBundleIdentifier = "com.google.test.someextension"

    // Verify it matches when isAppExtension is true
    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix(
      appBundleID,
      inBundles: [mockBundle!],
      isAppExtension: true
    ))
  }

  func testBundleIdentifierExistsInBundlesForExtensions_ExactMatch() {
    let extensionBundleID = "com.google.test.someextension"
    mockBundle.mockedBundleIdentifier = extensionBundleID

    // Verify it matches exactly even if isAppExtension is true
    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix(
      extensionBundleID,
      inBundles: [mockBundle!],
      isAppExtension: true
    ))
  }

  func testBundleIdentifierHasPrefixInBundlesNotValidExtension() {
    // Case 1: Extra component
    mockBundle.mockedBundleIdentifier = "com.google.test.someextension.some"
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix(
      "com.google.test",
      inBundles: [mockBundle!],
      isAppExtension: true
    ))

    // Case 2: No dot separator
    mockBundle.mockedBundleIdentifier = "com.google.testsomeextension"
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix(
      "com.google.test",
      inBundles: [mockBundle!],
      isAppExtension: true
    ))

    // Case 3: Totally different
    mockBundle.mockedBundleIdentifier = "not-exist"
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix(
      "com.google.test",
      inBundles: [mockBundle!],
      isAppExtension: true
    ))

    // Case 4: Logic check - if searching for extension ID, app ID matching shouldn't work backwards
    // The utility removes the last part of BUNDLE identifier to match TARGET identifier.
    // If target is "com.google.tests" and bundle is "com.google", it shouldn't match.
    // (Bundle ID "com.google" -> remove last part -> "com" != "com.google.tests")
    mockBundle.mockedBundleIdentifier = "com.google"
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix(
      "com.google.tests",
      inBundles: [mockBundle!],
      isAppExtension: true
    ))
  }

  func testRelevantURLSchemes() {
    mockBundle.mockedInfoDictionary = [
      "CFBundleURLTypes": [
        [
          "CFBundleURLSchemes": ["scheme1", "scheme2"],
        ],
        [
          "CFBundleURLSchemes": ["scheme3"],
        ],
      ],
    ]

    let schemes = FIRBundleUtil.relevantURLSchemes(inBundles: [mockBundle!]) as? [String]
    XCTAssertNotNil(schemes)
    XCTAssertTrue(schemes!.contains("scheme1"))
    XCTAssertTrue(schemes!.contains("scheme2"))
    XCTAssertTrue(schemes!.contains("scheme3"))
    XCTAssertEqual(schemes!.count, 3)
  }
}
