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
    // Use a safe temporary directory path.
    let dummyPath = NSTemporaryDirectory()
    super.init(path: dummyPath)!
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
  private let resultPath = "resultPath"
  private let resourceName = "resourceName"
  private let fileType = "fileType"

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
    mockBundle = MockBundle(identifier: nil, resources: [resourceName: resultPath])

    let result = FIRBundleUtil.optionsDictionaryPath(
      withResourceName: resourceName,
      andFileType: fileType,
      inBundles: [mockBundle!]
    )
    XCTAssertEqual(result, resultPath)
  }

  /// Verifies that `optionsDictionaryPath` returns nil when resource is missing.
  func testFindOptionsDictionaryPath_notFound() {
    mockBundle = MockBundle(identifier: nil, resources: [:])
    let result = FIRBundleUtil.optionsDictionaryPath(
      withResourceName: resourceName,
      andFileType: fileType,
      inBundles: [mockBundle!]
    )
    XCTAssertNil(result)
  }

  /// Verifies that `optionsDictionaryPath` checks subsequent bundles if resource is missing in the
  /// first.
  func testFindOptionsDictionaryPath_secondBundle() {
    let mockBundleEmpty = MockBundle(identifier: nil, resources: [:])
    mockBundle = MockBundle(identifier: nil, resources: [resourceName: resultPath])

    let bundles = [mockBundleEmpty, mockBundle!]
    let result = FIRBundleUtil.optionsDictionaryPath(
      withResourceName: resourceName,
      andFileType: fileType,
      inBundles: bundles
    )
    XCTAssertEqual(result, resultPath)
  }

  /// Verifies `hasBundleIdentifierPrefix` returns true for exact match.
  func testBundleIdentifierExistsInBundles() {
    let bundleID = "com.google.test"
    mockBundle = MockBundle(identifier: bundleID)

    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix(
      bundleID,
      inBundles: [mockBundle!] as [Any]
    ))
  }

  /// Verifies `hasBundleIdentifierPrefix` returns false for mismatch.
  func testBundleIdentifierExistsInBundles_notExist() {
    mockBundle = MockBundle(identifier: "com.google.test")
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix(
      "not-exist",
      inBundles: [mockBundle!] as [Any]
    ))
  }

  /// Verifies `hasBundleIdentifierPrefix` returns false for empty bundle list.
  func testBundleIdentifierExistsInBundles_emptyBundlesArray() {
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test", inBundles: []))
  }
}
