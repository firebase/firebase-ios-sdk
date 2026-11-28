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

#if SWIFT_PACKAGE
  internal import GoogleUtilities_Environment
#else
  internal import GoogleUtilities
#endif // SWIFT_PACKAGE

/// Tests for the Firebase user agent. They don't use OCMock, so they run unchanged against the
/// Objective-C and Swift implementations of FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIRFirebaseUserAgentTests.m, which checks the user agent
/// through `FirebaseApp`, plus new tests of FIRFirebaseUserAgent itself. `resetApps`, which runs
/// before each test (see `CoreTestCase`), removes the libraries that earlier tests registered.
final class FirebaseUserAgentTests: CoreTestCase {
  private let platforms = ["ios", "tvos", "macos", "watchos", "maccatalyst", "visionos"]

  // MARK: - Environment components

  func testApplePlatform() {
    let expected: String
    #if targetEnvironment(macCatalyst)
      // In a Catalyst app, both `os(iOS)` and `targetEnvironment(macCatalyst)` are true.
      expected = "maccatalyst"
    #elseif os(visionOS)
      expected = "visionos"
    #elseif os(iOS)
      expected = "ios"
    #elseif os(tvOS)
      expected = "tvos"
    #elseif os(macOS)
      expected = "macos"
    #elseif os(watchOS)
      expected = "watchos"
    #else
      // What GoogleUtilities reports for other platforms.
      expected = "unknown"
    #endif
    let agent = FirebaseApp.firebaseUserAgent()
    for platform in platforms {
      XCTAssertEqual(agent.contains("apple-platform/\(platform)"), platform == expected, platform)
    }
  }

  func testDeploymentType() {
    #if SWIFT_PACKAGE
      let deploymentType = "swiftpm"
    #else
      let deploymentType = "cocoapods"
    #endif
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains("deploy/\(deploymentType)"))
  }

  func testDeviceModel() throws {
    let deviceModel = try XCTUnwrap(GULAppEnvironmentUtil.deviceModel())
    let component = "device/\(deviceModel)"
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains(component), component)
  }

  func testOSVersion() {
    let component = "os-version/\(GULAppEnvironmentUtil.systemVersion())"
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains(component), component)
  }

  func testIsFromAppStore() {
    let component = "appstore/\(GULAppEnvironmentUtil.isFromAppStore() ? "true" : "false")"
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains(component), component)
  }

  // MARK: - Registering libraries

  func testRegisterLibraryWithInvalidName() {
    let agent = FirebaseApp.firebaseUserAgent()
    FirebaseApp.registerLibrary("Oops>", withVersion: "1.0.0")
    XCTAssertEqual(FirebaseApp.firebaseUserAgent(), agent)
  }

  func testRegisterLibraryWithInvalidVersion() {
    let agent = FirebaseApp.firebaseUserAgent()
    FirebaseApp.registerLibrary("ValidName", withVersion: "1.0.0+")
    XCTAssertEqual(FirebaseApp.firebaseUserAgent(), agent)
  }

  func testRegisterSingleLibrary() {
    FirebaseApp.registerLibrary("ValidName", withVersion: "1.0.0")
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains("ValidName/1.0.0"))
  }

  func testRegisterMultipleLibraries() {
    FirebaseApp.registerLibrary("ValidName", withVersion: "1.0.0")
    FirebaseApp.registerLibrary("ValidName2", withVersion: "2.0.0")
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains("ValidName/1.0.0 ValidName2/2.0.0"))
  }

  func testRegisterConformingLibrary() {
    FirebaseApp.registerInternalLibrary(CoreTestUncachedLibrary.self,
                                        withName: "ValidName",
                                        withVersion: "1.0.0")
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains("ValidName/1.0.0"))
  }

  func testRegisterNonConformingLibraryRaises() {
    let exception = CoreTestHooks.exceptionRaised {
      CoreTestHooks.registerInternalLibrary(uncheckedClass: NSString.self,
                                            name: "InvalidLibrary",
                                            version: "1.0.0")
    }
    XCTAssertEqual(exception?.name, .invalidArgumentException)
    XCTAssertFalse(FirebaseApp.firebaseUserAgent().contains("InvalidLibrary"))
  }

  func testResetAppsRemovesRegisteredLibraries() {
    // New: `resetApps` resets the user agent too.
    FirebaseApp.registerLibrary("ValidName", withVersion: "1.0.0")
    FirebaseApp.resetApps()
    XCTAssertFalse(FirebaseApp.firebaseUserAgent().contains("ValidName/"))
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains("apple-platform/"))
  }

  // MARK: - FIRFirebaseUserAgent

  func testComponentsAreSortedByName() {
    let userAgent = FIRFirebaseUserAgent()
    userAgent.setValue("1", forComponent: "b-lib")
    userAgent.setValue("2", forComponent: "A-lib")

    let components = userAgent.firebaseUserAgent().components(separatedBy: " ")
    XCTAssertTrue(components.contains("A-lib/2"))
    XCTAssertTrue(components.contains("b-lib/1"))
    // Sorted without regard to case.
    let sorted = components.sorted {
      $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
    }
    XCTAssertEqual(components, sorted)
  }

  func testSettingAComponentUpdatesTheUserAgent() {
    let userAgent = FIRFirebaseUserAgent()
    XCTAssertFalse(userAgent.firebaseUserAgent().contains("lib/"))

    userAgent.setValue("1", forComponent: "lib")
    XCTAssertTrue(userAgent.firebaseUserAgent().contains("lib/1"))

    userAgent.setValue("2", forComponent: "lib")
    XCTAssertTrue(userAgent.firebaseUserAgent().contains("lib/2"))
    XCTAssertFalse(userAgent.firebaseUserAgent().contains("lib/1"))

    userAgent.setValue(nil, forComponent: "lib")
    XCTAssertFalse(userAgent.firebaseUserAgent().contains("lib/"))
  }

  func testResetKeepsEnvironmentComponents() {
    let userAgent = FIRFirebaseUserAgent()
    let environment = userAgent.firebaseUserAgent()
    userAgent.setValue("1", forComponent: "lib")

    userAgent.reset()

    XCTAssertEqual(userAgent.firebaseUserAgent(), environment)
  }

  func testEnvironmentComponentsTakePrecedence() {
    // Characterization: a component with the name of an environment component doesn't replace it.
    let userAgent = FIRFirebaseUserAgent()
    userAgent.setValue("custom", forComponent: "deploy")
    XCTAssertFalse(userAgent.firebaseUserAgent().contains("deploy/custom"))
    XCTAssertTrue(userAgent.firebaseUserAgent().contains("deploy/"))
  }
}
