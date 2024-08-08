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

import FirebaseSharedSwift
import XCTest

@_implementationOnly import FirebaseCoreExtension

@testable import FirebaseVertexAI

// TODO: Remove this file; manually testing by inspecting logs on CI.
final class LoggingTests: XCTestCase {
  let messageID = 42

  override func setUp() {
    FIRSetLoggerLevel(.max)
  }

  func testLoggingFunctions() {
    FirebaseLogger.vertexAI.debug(messageID: messageID, "This is a DEBUG message.")
    FirebaseLogger.vertexAI.info(messageID: messageID, "This is an INFO message.")
    FirebaseLogger.vertexAI.notice(messageID: messageID, "This is a NOTICE message.")
    FirebaseLogger.vertexAI.warning(messageID: messageID, "This is a WARNING message.")
    FirebaseLogger.vertexAI.error(messageID: messageID, "This is an ERROR message.")
  }

  @available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
  func testLoggingFunctionPrivacy() {
    guard let bundleID = Bundle.main.bundleIdentifier else {
      XCTFail("Bundle ID was nil.")
      return
    }
    FirebaseLogger.vertexAI.osLogger().error("Default Privacy: bundleID[\(bundleID)]")
    FirebaseLogger.vertexAI.osLogger()
      .error("Public Privacy: bundleID[\(bundleID, privacy: .public)]")
    FirebaseLogger.vertexAI.osLogger()
      .error("Private Privacy: bundleID[\(bundleID, privacy: .private)]")
    FirebaseLogger.vertexAI.osLogger()
      .error("Sensitive Privacy: bundleID[\(bundleID, privacy: .sensitive)]")
  }

  @available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
  func testSwiftLoggerPrivacy() {
    guard let bundleID = Bundle.main.bundleIdentifier else {
      XCTFail("Bundle ID was nil.")
      return
    }
    let logger = Logger(subsystem: "com.google.firebase", category: "[FirebaseVertexAI]")
    logger.error("Default Privacy: bundleID[\(bundleID)]")
    logger.error("Public Privacy: bundleID[\(bundleID, privacy: .public)]")
    logger.error("Private Privacy: bundleID[\(bundleID, privacy: .private)]")
    logger.error("Sensitive Privacy: bundleID[\(bundleID, privacy: .sensitive)]")
  }

  @available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
  func testOSLogPrivacy() {
    guard let bundleID = Bundle.main.bundleIdentifier else {
      XCTFail("Bundle ID was nil.")
      return
    }
    let logObj = OSLog(subsystem: "com.google.firebase", category: "[FirebaseVertexAI]")
    os_log(.error, log: logObj, "Default Privacy: bundleID[\(bundleID)]")
    os_log(.error, log: logObj, "Public Privacy: bundleID[\(bundleID, privacy: .public)]")
    os_log(.error, log: logObj, "Private Privacy: bundleID[\(bundleID, privacy: .private)]")
    os_log(.error, log: logObj, "Sensitive Privacy: bundleID[\(bundleID, privacy: .sensitive)]")
  }

  func testOSLogLegacyPrivacy() {
    guard let bundleID = Bundle.main.bundleIdentifier else {
      XCTFail("Bundle ID was nil.")
      return
    }
    let logObj = OSLog(subsystem: "com.google.firebase", category: "[FirebaseVertexAI]")
    os_log(.error, log: logObj, "Default Privacy: bundleID[%@]", bundleID)
    os_log(.error, log: logObj, "Public Privacy: bundleID[%{public}@]", bundleID)
    os_log(.error, log: logObj, "Private Privacy: bundleID[%{private}@]", bundleID)
    os_log(.error, log: logObj, "Sensitive Privacy: bundleID[%{sensitive}@]", bundleID)
  }
}
