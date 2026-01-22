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

class MockBundle: Bundle {
  var _bundleIdentifier: String?
  override var bundleIdentifier: String? {
    return _bundleIdentifier
  }

  var mockedPaths: [String: String] = [:]
  override func path(forResource name: String?, ofType ext: String?) -> String? {
    let key = "\(name ?? "").\(ext ?? "")"
    return mockedPaths[key]
  }

  var mockedInfoDictionary: [String: Any]?
  override func object(forInfoDictionaryKey key: String) -> Any? {
    return mockedInfoDictionary?[key]
  }
}

class BundleUtilTests: XCTestCase {
  let kResultPath = "resultPath"
  let kResourceName = "resourceName"
  let kFileType = "fileType"

  var mockBundle: MockBundle!

  override func setUp() {
    super.setUp()
    mockBundle = MockBundle()
    BundleUtil.isAppExtensionOverride = nil
  }

  override func tearDown() {
    BundleUtil.isAppExtensionOverride = nil
    super.tearDown()
  }

  func testRelevantBundles_mainIsFirst() {
    let bundles = BundleUtil.relevantBundles()
    XCTAssertGreaterThan(bundles.count, 0)
    XCTAssertEqual(bundles[0], Bundle.main)
  }

  func testFindOptionsDictionaryPath() {
    mockBundle.mockedPaths["\(kResourceName).\(kFileType)"] = kResultPath
    let result = BundleUtil.optionsDictionaryPath(resourceName: kResourceName,
                                                  fileType: kFileType,
                                                  inBundles: [mockBundle])
    XCTAssertEqual(result, kResultPath)
  }

  func testFindOptionsDictionaryPath_notFound() {
    let result = BundleUtil.optionsDictionaryPath(resourceName: kResourceName,
                                                  fileType: kFileType,
                                                  inBundles: [mockBundle])
    XCTAssertNil(result)
  }

  func testFindOptionsDictionaryPath_secondBundle() {
    let mockBundleEmpty = MockBundle()
    mockBundle.mockedPaths["\(kResourceName).\(kFileType)"] = kResultPath

    let bundles = [mockBundleEmpty, mockBundle]
    let result = BundleUtil.optionsDictionaryPath(resourceName: kResourceName,
                                                  fileType: kFileType,
                                                  inBundles: bundles)
    XCTAssertEqual(result, kResultPath)
  }

  func testBundleIdentifierExistsInBundles() {
    let bundleID = "com.google.test"
    mockBundle._bundleIdentifier = bundleID
    XCTAssertTrue(BundleUtil.hasBundleIdentifierPrefix(bundleID, inBundles: [mockBundle]))
  }

  func testBundleIdentifierExistsInBundles_notExist() {
    mockBundle._bundleIdentifier = "com.google.test"
    XCTAssertFalse(BundleUtil.hasBundleIdentifierPrefix("not-exist", inBundles: [mockBundle]))
  }

  func testBundleIdentifierExistsInBundles_emptyBundlesArray() {
    XCTAssertFalse(BundleUtil.hasBundleIdentifierPrefix("com.google.test", inBundles: []))
  }

  func testBundleIdentifierHasPrefixInBundlesForExtension() {
    BundleUtil.isAppExtensionOverride = true
    mockBundle._bundleIdentifier = "com.google.test.someextension"

    XCTAssertTrue(BundleUtil.hasBundleIdentifierPrefix("com.google.test", inBundles: [mockBundle]))
  }

  func testBundleIdentifierExistsInBundlesForExtensions_exactMatch() {
    BundleUtil.isAppExtensionOverride = true
    mockBundle._bundleIdentifier = "com.google.test.someextension"

    XCTAssertTrue(BundleUtil.hasBundleIdentifierPrefix("com.google.test.someextension",
                                                       inBundles: [mockBundle]))
  }

  func testBundleIdentifierHasPrefixInBundlesNotValidExtension() {
    BundleUtil.isAppExtensionOverride = true

    let bundleID = "com.google.test"

    mockBundle._bundleIdentifier = "com.google.test.someextension.some"
    XCTAssertFalse(BundleUtil.hasBundleIdentifierPrefix(bundleID, inBundles: [mockBundle]))

    mockBundle._bundleIdentifier = "com.google.testsomeextension"
    XCTAssertFalse(BundleUtil.hasBundleIdentifierPrefix(bundleID, inBundles: [mockBundle]))

    mockBundle._bundleIdentifier = "com.google.testsomeextension.some"
    XCTAssertFalse(BundleUtil.hasBundleIdentifierPrefix(bundleID, inBundles: [mockBundle]))

    mockBundle._bundleIdentifier = "not-exist"
    XCTAssertFalse(BundleUtil.hasBundleIdentifierPrefix(bundleID, inBundles: [mockBundle]))

    mockBundle._bundleIdentifier = "com.google.tests" // Prefix matches but logic removes last part
    XCTAssertFalse(BundleUtil.hasBundleIdentifierPrefix("com.google.tests", inBundles: [mockBundle]))
  }
}
