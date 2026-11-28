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

/// Tests for FirebaseCore's logger: levels, debug mode and message codes. They don't use OCMock,
/// so they run unchanged against the Objective-C and Swift implementations of FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIRLoggerTest.m. Instead of partially mocking
/// `NSProcessInfo` for the launch arguments, the tests reset the logger with the launch arguments
/// and user defaults it should read (see `LoggerTestCase`).
///
/// FIRLoggerTest.m's testInitializeASLForNonDebugMode and testInitializeASLForDebugModeWithArgument
/// only asserted under `MAKE_THREAD_SAFE`, which is never defined, so they checked nothing. The
/// debug mode tests below check what they meant to.
final class LoggerTests: LoggerTestCase {
  private let debugModeKey = "/google/firebase/debug_mode"
  private let enableDebugModeArgument = "-FIRDebugEnabled"
  private let disableDebugModeArgument = "-FIRDebugDisabled"
  private let messageCode = "I-COR000001"

  // MARK: - Constants

  func testLoggerServiceNames() {
    // Other products and the FirebaseAnalytics binary log with these services.
    XCTAssertEqual(kFIRLoggerAnalytics, "[FirebaseAnalytics]")
    XCTAssertEqual(kFIRLoggerCore, "[FirebaseCore]")
  }

  func testLoggerLevelValues() {
    // The levels match the ASL_LEVEL_* constants of <asl.h>.
    XCTAssertEqual(FirebaseLoggerLevel.error.rawValue, 3)
    XCTAssertEqual(FirebaseLoggerLevel.warning.rawValue, 4)
    XCTAssertEqual(FirebaseLoggerLevel.notice.rawValue, 5)
    XCTAssertEqual(FirebaseLoggerLevel.info.rawValue, 6)
    XCTAssertEqual(FirebaseLoggerLevel.debug.rawValue, 7)
    XCTAssertEqual(FirebaseLoggerLevel.min, .error)
    XCTAssertEqual(FirebaseLoggerLevel.max, .debug)
  }

  // MARK: - Levels

  func testDefaultLoggerLevelIsNotice() {
    XCTAssertEqual(FIRGetLoggerLevel(), .notice)
    XCTAssertTrue(FIRIsLoggableLevel(.notice, false))
    XCTAssertFalse(FIRIsLoggableLevel(.info, false))
  }

  func testSetLoggerLevel() {
    FIRSetLoggerLevel(.debug)
    XCTAssertEqual(FIRGetLoggerLevel(), .debug)
    XCTAssertTrue(FIRIsLoggableLevel(.debug, false))

    FIRSetLoggerLevel(.error)
    XCTAssertEqual(FIRGetLoggerLevel(), .error)
    XCTAssertTrue(FIRIsLoggableLevel(.error, false))
    XCTAssertFalse(FIRIsLoggableLevel(.warning, false))
  }

  func testLevelSpecificFunctions() {
    // New: FIRLoggerTest.m didn't cover these.
    FIRSetLoggerLevelError()
    XCTAssertEqual(FIRGetLoggerLevel(), .error)
    XCTAssertTrue(FIRIsLoggableLevelError())
    XCTAssertFalse(FIRIsLoggableLevelWarning())

    FIRSetLoggerLevelWarning()
    XCTAssertEqual(FIRGetLoggerLevel(), .warning)
    XCTAssertTrue(FIRIsLoggableLevelWarning())
    XCTAssertFalse(FIRIsLoggableLevelNotice())

    FIRSetLoggerLevelNotice()
    XCTAssertEqual(FIRGetLoggerLevel(), .notice)
    XCTAssertTrue(FIRIsLoggableLevelNotice())
    XCTAssertFalse(FIRIsLoggableLevelDebug())

    FIRSetLoggerLevelDebug()
    XCTAssertEqual(FIRGetLoggerLevel(), .debug)
    XCTAssertTrue(FIRIsLoggableLevelDebug())
  }

  func testResetRestoresDefaultLoggerLevel() {
    FIRSetLoggerLevel(.debug)
    resetLogger(launchArguments: [])
    XCTAssertEqual(FIRGetLoggerLevel(), .notice)
  }

  // MARK: - Debug mode

  func testNoDebugModeByDefault() {
    XCTAssertEqual(FIRGetLoggerLevel(), .notice)
    XCTAssertNil(userDefaults.object(forKey: debugModeKey))
  }

  func testEnableDebugModeArgument() {
    resetLogger(launchArguments: [enableDebugModeArgument])

    XCTAssertEqual(FIRGetLoggerLevel(), .debug)
    XCTAssertTrue(FIRIsLoggableLevel(.debug, false))
    // Debug mode is persisted, so it stays on in later launches without the argument.
    XCTAssertTrue(userDefaults.bool(forKey: debugModeKey))
  }

  func testPersistedDebugMode() {
    userDefaults.set(true, forKey: debugModeKey)
    resetLogger(launchArguments: [])

    XCTAssertEqual(FIRGetLoggerLevel(), .debug)
    XCTAssertTrue(userDefaults.bool(forKey: debugModeKey))
  }

  func testDisableDebugModeArgument() {
    userDefaults.set(true, forKey: debugModeKey)
    resetLogger(launchArguments: [disableDebugModeArgument])

    XCTAssertEqual(FIRGetLoggerLevel(), .notice)
    XCTAssertFalse(FIRIsLoggableLevel(.debug, false))
    XCTAssertNil(userDefaults.object(forKey: debugModeKey))
  }

  func testDisableDebugModeArgumentWins() {
    resetLogger(launchArguments: [enableDebugModeArgument, disableDebugModeArgument])

    XCTAssertEqual(FIRGetLoggerLevel(), .notice)
    XCTAssertNil(userDefaults.object(forKey: debugModeKey))
  }

  func testAnalyticsDebugMode() {
    // New: Analytics debug mode makes only Analytics log verbosely.
    FIRSetAnalyticsDebugMode(true)
    XCTAssertTrue(FIRIsLoggableLevel(.debug, true))
    XCTAssertFalse(FIRIsLoggableLevel(.debug, false))

    resetLogger(launchArguments: [])
    XCTAssertFalse(FIRIsLoggableLevel(.debug, true))
  }

  // MARK: - Logging and message codes

  func testLoggingAtEachLevel() {
    FIRSetLoggerLevel(.debug)
    for level in [FirebaseLoggerLevel.error, .warning, .notice, .info, .debug] {
      assertNoException("level \(level.rawValue)") {
        FirebaseLogger.log(level: level, service: kFIRLoggerCore, code: messageCode,
                           message: "Message.")
      }
    }
    // The C logging function, as the Objective-C macros and functions call it, with arguments.
    assertNoException {
      withVaList(["blah"]) { arguments in
        FIRLogBasic(.error, kFIRLoggerCore, messageCode, "Configure %@.", arguments)
      }
    }
  }

  func testMessageCodeFormat() {
    // Valid case.
    XCTAssertNil(messageCodeException("I-APP000001"))

    let invalidCodes = [
      // An extra or missing dash.
      "I-APP-000001", "IAPP000001",
      // The wrong number of digits.
      "I-APP00001", "I-APP0000001",
      // Lowercase.
      "I-app000001",
      // Empty.
      "",
      // An Android message code.
      "A-APP000001",
    ]
    for code in invalidCodes {
      let exception = messageCodeException(code)
      XCTAssertEqual(exception?.name, .internalInconsistencyException, code)
    }
  }

  func testMessageCodeIsOnlyCheckedWhenLogging() {
    // New: a message below the logger level isn't logged, so its message code isn't checked.
    XCTAssertEqual(FIRGetLoggerLevel(), .notice)
    let exception = CoreTestHooks.exceptionRaised {
      FirebaseLogger.log(level: .debug, service: kFIRLoggerCore, code: "invalid", message: "M.")
    }
    XCTAssertNil(exception)
  }

  // MARK: - Helpers

  /// Logs an error with `code` and returns the exception that the message code check raised.
  private func messageCodeException(_ code: String) -> NSException? {
    CoreTestHooks.exceptionRaised {
      FirebaseLogger.log(level: .error, service: kFIRLoggerCore, code: code, message: "Message.")
    }
  }
}
