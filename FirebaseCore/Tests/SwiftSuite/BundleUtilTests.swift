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
import FirebaseCoreTestHooks
import Foundation
import XCTest

/// Tests for FIRBundleUtil, which finds GoogleService-Info.plist and checks bundle IDs. They don't
/// use OCMock, so they run unchanged against the Objective-C and Swift implementations of
/// FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIRBundleUtilTest.m. Instead of mocking `NSBundle`, the
/// tests use real bundles in temporary directories. Instead of mocking
/// `+[GULAppEnvironmentUtil isAppExtension]`, which returns garbage on visionOS, they set the app
/// extension override that FIRBundleUtil and FIRApp share.
final class BundleUtilTests: CoreTestCase {
  private let resourceName = "resourceName"
  private let fileType = "fileType"
  private var resourceFile: String { "\(resourceName).\(fileType)" }

  // MARK: - Relevant bundles

  func testRelevantBundlesStartWithMainBundle() {
    let bundles = FIRBundleUtil.relevantBundles()
    XCTAssertEqual(bundles.count, 2)
    XCTAssertTrue(bundles.first === Bundle.main)
    XCTAssertTrue(bundles.last === Bundle(for: FIRBundleUtil.self))
  }

  func testRelevantBundlesCanBeReplacedForTesting() throws {
    let temporaryBundle = try TemporaryBundle()
    CoreTestHooks.setRelevantBundles([temporaryBundle.bundle])
    XCTAssertEqual(FIRBundleUtil.relevantBundles().count, 1)
    XCTAssertTrue(FIRBundleUtil.relevantBundles().first === temporaryBundle.bundle)

    CoreTestHooks.setRelevantBundles(nil)
    XCTAssertTrue(FIRBundleUtil.relevantBundles().first === Bundle.main)
  }

  func testRelevantURLSchemes() throws {
    // New: FIRBundleUtilTest.m didn't cover URL schemes.
    let first = try TemporaryBundle(infoDictionary: ["CFBundleURLTypes": [
      ["CFBundleURLSchemes": ["scheme-a", "scheme-b"]],
      ["CFBundleURLSchemes": ["scheme-c"]],
    ]])
    let second = try TemporaryBundle(infoDictionary: ["CFBundleURLTypes": [
      ["CFBundleURLSchemes": ["scheme-d"]],
    ]])
    let withoutSchemes = try TemporaryBundle(bundleIdentifier: "com.google.test")
    CoreTestHooks.setRelevantBundles([first.bundle, withoutSchemes.bundle, second.bundle])

    XCTAssertEqual(FIRBundleUtil.relevantURLSchemes(),
                   ["scheme-a", "scheme-b", "scheme-c", "scheme-d"])
  }

  // MARK: - Finding GoogleService-Info.plist

  func testFindOptionsDictionaryPath() throws {
    let temporaryBundle = try TemporaryBundle(resources: [resourceFile])
    let path = FIRBundleUtil.optionsDictionaryPath(resourceName: resourceName,
                                                   fileType: fileType,
                                                   bundles: [temporaryBundle.bundle])
    XCTAssertEqual(resolvedPath(path), temporaryBundle.resolvedPath(of: resourceFile))
  }

  func testFindOptionsDictionaryPathNotFound() throws {
    let temporaryBundle = try TemporaryBundle(resources: ["otherName.\(fileType)"])
    XCTAssertNil(FIRBundleUtil.optionsDictionaryPath(resourceName: resourceName,
                                                     fileType: fileType,
                                                     bundles: [temporaryBundle.bundle]))
    XCTAssertNil(FIRBundleUtil.optionsDictionaryPath(resourceName: resourceName,
                                                     fileType: fileType,
                                                     bundles: []))
  }

  func testFindOptionsDictionaryPathInSecondBundle() throws {
    let emptyBundle = try TemporaryBundle()
    let temporaryBundle = try TemporaryBundle(resources: [resourceFile])
    let path = FIRBundleUtil.optionsDictionaryPath(resourceName: resourceName,
                                                   fileType: fileType,
                                                   bundles: [emptyBundle.bundle,
                                                             temporaryBundle.bundle])
    XCTAssertEqual(resolvedPath(path), temporaryBundle.resolvedPath(of: resourceFile))
  }

  func testFindOptionsDictionaryPathPrefersFirstBundle() throws {
    // New: the bundles are searched in order.
    let first = try TemporaryBundle(resources: [resourceFile])
    let second = try TemporaryBundle(resources: [resourceFile])
    let path = FIRBundleUtil.optionsDictionaryPath(resourceName: resourceName,
                                                   fileType: fileType,
                                                   bundles: [first.bundle, second.bundle])
    XCTAssertEqual(resolvedPath(path), first.resolvedPath(of: resourceFile))
  }

  // MARK: - Bundle IDs

  func testBundleIdentifierExistsInBundles() throws {
    let other = try TemporaryBundle(bundleIdentifier: "com.google.other")
    let temporaryBundle = try TemporaryBundle(bundleIdentifier: "com.google.test")
    XCTAssertEqual(temporaryBundle.bundle.bundleIdentifier, "com.google.test")
    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test",
                                                          in: [other.bundle,
                                                               temporaryBundle.bundle]))
  }

  func testBundleIdentifierDoesNotExistInBundles() throws {
    let temporaryBundle = try TemporaryBundle(bundleIdentifier: "com.google.test")
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("not-exist",
                                                           in: [temporaryBundle.bundle]))
  }

  func testBundleIdentifierWithEmptyBundles() {
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test", in: []))
  }

  func testExtensionBundleIdentifierMatchesAppBundleIdentifier() throws {
    CoreTestHooks.setIsAppExtension(true)
    // The bundle has what an app extension has: the extension's bundle ID.
    let temporaryBundle = try TemporaryBundle(bundleIdentifier: "com.google.test.someextension")
    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test",
                                                          in: [temporaryBundle.bundle]))
  }

  func testExtensionBundleIdentifierMatchesExactly() throws {
    CoreTestHooks.setIsAppExtension(true)
    let temporaryBundle = try TemporaryBundle(bundleIdentifier: "com.google.test.someextension")
    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test.someextension",
                                                          in: [temporaryBundle.bundle]))
  }

  func testExtensionBundleIdentifierMismatches() throws {
    CoreTestHooks.setIsAppExtension(true)
    // Only the last component of an extension's bundle ID is removed.
    for bundleID in ["com.google.test.someextension.some", "com.google.testsomeextension",
                     "com.google.testsomeextension.some", "not-exist"] {
      let temporaryBundle = try TemporaryBundle(bundleIdentifier: bundleID)
      XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test",
                                                             in: [temporaryBundle.bundle]),
                     bundleID)
    }

    // If "com.google.tests" were an extension's bundle ID, the app's would be "com.google", so it
    // doesn't match "com.google.test.someextension".
    let temporaryBundle = try TemporaryBundle(bundleIdentifier: "com.google.test.someextension")
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.tests",
                                                           in: [temporaryBundle.bundle]))
  }

  func testBundleIdentifierSuffixIsIgnoredOutsideExtensions() throws {
    // New: FIRBundleUtilTest.m only checked the extension case.
    CoreTestHooks.setIsAppExtension(false)
    let temporaryBundle = try TemporaryBundle(bundleIdentifier: "com.google.test.someextension")
    XCTAssertFalse(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test",
                                                           in: [temporaryBundle.bundle]))
    XCTAssertTrue(FIRBundleUtil.hasBundleIdentifierPrefix("com.google.test.someextension",
                                                          in: [temporaryBundle.bundle]))
  }

  // MARK: - App extension override

  func testAppExtensionOverrideIsSharedWithFirebaseApp() {
    CoreTestHooks.setIsAppExtension(true)
    XCTAssertTrue(FIRBundleUtil.isAppExtension())
    CoreTestHooks.setIsAppExtension(false)
    XCTAssertFalse(FIRBundleUtil.isAppExtension())

    // FIRAppTest.m sets the override through FIRApp, which forwards to FIRBundleUtil.
    let setOnApp = NSSelectorFromString("setIsAppExtensionForTesting:")
    let appClass: AnyObject = FirebaseApp.self
    XCTAssertTrue(appClass.responds(to: setOnApp))
    _ = appClass.perform(setOnApp, with: NSNumber(value: true))
    XCTAssertTrue(FIRBundleUtil.isAppExtension())
    _ = appClass.perform(setOnApp, with: NSNumber(value: false))
    XCTAssertFalse(FIRBundleUtil.isAppExtension())
  }
}
