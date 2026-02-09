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

import XCTest
import GoogleUtilities_Environment

// Internal imports are available via bridging header
// FIRBundleUtil is available as ObjC class.

/// A mock bundle to simulate `NSBundle` behavior for testing.
class MockBundle: Bundle {
  private let _bundleIdentifier: String?
  private let _resources: [String: String]

  init(identifier: String?, resources: [String: String] = [:]) {
    self._bundleIdentifier = identifier
    self._resources = resources
    // Initialize with a dummy path to satisfy Bundle requirements,
    // though we override methods that use the path.
    // Using "/tmp" as a safe dummy path.
    super.init(path: "/tmp")!
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var bundleIdentifier: String? {
    return _bundleIdentifier
  }

  override func path(forResource name: String?, ofType ext: String?) -> String? {
    guard let name = name else { return nil }
    // If extension is provided, append it to look up in our dictionary
    // We store resources as "name.ext" -> "path"
    // But if key is just name, we might need logic.
    // For simplicity, assume keys match exactly what's looked up or close enough.
    // The test usually mocks specific lookups.
    return _resources[name]
  }
}

class BundleUtilTests: XCTestCase {

  private let kResultPath = "resultPath"
  private let kResourceName = "resourceName"
  private let kFileType = "fileType"

  // Use MockBundle instead of OCMock for Bundle
  private var mockBundle: MockBundle!

  override func setUp() {
    super.setUp()
    // Default mock bundle
    mockBundle = MockBundle(identifier: nil)
  }

  override func tearDown() {
    mockBundle = nil
    super.tearDown()
  }

  /// Verifies that `relevantBundles` returns the main bundle as the first element.
  func testRelevantBundles_mainIsFirst() {
    let bundles = FIRBundleUtil.relevantBundles()
    XCTAssertEqual(Bundle.main, bundles.first as? Bundle)
  }

  /// Verifies that `optionsDictionaryPath` finds the resource when present.
  func testFindOptionsDictionaryPath() {
    // Setup mock with resource
    mockBundle = MockBundle(identifier: nil, resources: [kResourceName: kResultPath])

    let result = FIRBundleUtil.optionsDictionaryPath(withResourceName: kResourceName,
                                                     andFileType: kFileType,
                                                     inBundles: [mockBundle!])
    XCTAssertEqual(result, kResultPath)
  }

  /// Verifies that `optionsDictionaryPath` returns nil when resource is missing.
  func testFindOptionsDictionaryPath_notFound() {
    mockBundle = MockBundle(identifier: nil, resources: [:])
    let result = FIRBundleUtil.optionsDictionaryPath(withResourceName: kResourceName,
                                                     andFileType: kFileType,
                                                     inBundles: [mockBundle!])
    XCTAssertNil(result)
  }

  /// Verifies that `optionsDictionaryPath` checks subsequent bundles if resource is missing in the first.
  func testFindOptionsDictionaryPath_secondBundle() {
    let mockBundleEmpty = MockBundle(identifier: nil, resources: [:])
    mockBundle = MockBundle(identifier: nil, resources: [kResourceName: kResultPath])

    let bundles = [mockBundleEmpty, mockBundle!]
    let result = FIRBundleUtil.optionsDictionaryPath(withResourceName: kResourceName,
                                                     andFileType: kFileType,
                                                     inBundles: bundles)
    XCTAssertEqual(result, kResultPath)
  }

  /// Verifies `hasBundleIdentifierPrefix` returns true for exact match.
  func testBundleIdentifierExistsInBundles() {
    let bundleID = "com.google.test"
    mockBundle = MockBundle(identifier: bundleID)

    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix(bundleID, inBundles: [mockBundle!]))
  }

  /// Verifies `hasBundleIdentifierPrefix` returns false for mismatch.
  func testBundleIdentifierExistsInBundles_notExist() {
    mockBundle = MockBundle(identifier: "com.google.test")
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("not-exist", inBundles: [mockBundle!]))
  }

  /// Verifies `hasBundleIdentifierPrefix` returns false for empty bundle list.
  func testBundleIdentifierExistsInBundles_emptyBundlesArray() {
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test", inBundles: []))
  }

  /// Verifies `hasBundleIdentifierPrefix` handles extension logic correctly.
  func testBundleIdentifierHasPrefixInBundlesForExtension() {
    let mockEnv = OCMockObject.mock(for: GULAppEnvironmentUtil.self)
    // Stub class method isAppExtension() to return true
    // (mockEnv.stub() as AnyObject).andReturn(true).isAppExtension()
    // Note: Implicit casting to AnyObject allows dynamic dispatch to OCMockRecorder methods and then the target class method.
    (((mockEnv as AnyObject).stub() as AnyObject).andReturn(true) as AnyObject).isAppExtension()

    mockBundle = MockBundle(identifier: "com.google.test.someextension")

    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test", inBundles: [mockBundle!]))

    mockEnv.stopMocking()
  }

  /// Verifies exact match logic when in extension environment.
  func testBundleIdentifierExistsInBundlesForExtensions_exactMatch() {
    let mockEnv = OCMockObject.mock(for: GULAppEnvironmentUtil.self)
    (((mockEnv as AnyObject).stub() as AnyObject).andReturn(true) as AnyObject).isAppExtension()

    let extensionBundleID = "com.google.test.someextension"
    mockBundle = MockBundle(identifier: extensionBundleID)

    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix(extensionBundleID, inBundles: [mockBundle!]))

    mockEnv.stopMocking()
  }

  /// Verifies prefix logic is strict about extension format.
  func testBundleIdentifierHasPrefixInBundlesNotValidExtension() {
    let mockEnv = OCMockObject.mock(for: GULAppEnvironmentUtil.self)
    (((mockEnv as AnyObject).stub() as AnyObject).andReturn(true) as AnyObject).isAppExtension()

    // Test case 1
    mockBundle = MockBundle(identifier: "com.google.test.someextension.some")
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test", inBundles: [mockBundle!]))

    // Test case 2
    mockBundle = MockBundle(identifier: "com.google.testsomeextension")
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test", inBundles: [mockBundle!]))

    // Test case 3
    mockBundle = MockBundle(identifier: "com.google.testsomeextension.some")
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test", inBundles: [mockBundle!]))

    // Test case 4
    mockBundle = MockBundle(identifier: "not-exist")
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test", inBundles: [mockBundle!]))

    // Test case 5
    // Should be NO, since if @"com.google.tests" is an app extension identifier, then the app bundle
    // identifier is @"com.google"
    mockBundle = MockBundle(identifier: "com.google.tests")
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.tests", inBundles: [mockBundle!]))

    mockEnv.stopMocking()
  }

}
