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

/// Tests for `FirebaseConfiguration`. They don't use OCMock, so they run unchanged against the
/// Objective-C and Swift implementations of FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIRConfigurationTest.m and the CocoaPods-only
/// FirebaseCore/Tests/SwiftUnit/FirebaseConfigurationTests.swift. They change the logger level, so
/// the logger is reset around each test (see `LoggerTestCase`).
final class FirebaseConfigurationTests: LoggerTestCase {
  func testSharedInstance() {
    let configuration = FirebaseConfiguration.shared
    XCTAssertTrue(configuration === FirebaseConfiguration.shared)
    XCTAssertTrue(configuration.analyticsConfiguration === FIRAnalyticsConfiguration
      .sharedInstance())
  }

  func testDefaultLoggerLevel() {
    XCTAssertEqual(FirebaseConfiguration.shared.loggerLevel(), .notice)
  }

  func testSetAndGetLoggerLevel() {
    let configuration = FirebaseConfiguration.shared
    for level in [FirebaseLoggerLevel.error, .warning, .notice, .info, .debug] {
      configuration.setLoggerLevel(level)
      XCTAssertEqual(configuration.loggerLevel(), level)
    }
  }
}
