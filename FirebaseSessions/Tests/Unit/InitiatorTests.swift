// Copyright 2022 Google LLC
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
@testable import FirebaseSessions

#if os(iOS) || os(tvOS)
  import UIKit
#elseif os(macOS)
  import Cocoa
  import AppKit
#elseif os(watchOS)
  import WatchKit
#endif

class InitiatorTests: XCTestCase {
  // 2021-11-01 @ 00:00:00 (EST)
  let date = Date(timeIntervalSince1970: 1_635_739_200)

  func postBackgroundedNotification() {
    let notificationCenter = NotificationCenter.default
    #if os(iOS) || os(tvOS)
      notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    #elseif os(macOS)
      notificationCenter.post(name: NSApplication.didResignActiveNotification, object: nil)
    #elseif os(watchOS)
      if #available(watchOSApplicationExtension 7.0, *) {
        notificationCenter.post(
          name: WKExtension.applicationDidEnterBackgroundNotification,
          object: nil
        )
      }
    #endif
  }

  func postForegroundedNotification() {
    let notificationCenter = NotificationCenter.default
    #if os(iOS) || os(tvOS)
      notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    #elseif os(macOS)
      notificationCenter.post(name: NSApplication.didBecomeActiveNotification, object: nil)
    #elseif os(watchOS)
      if #available(watchOSApplicationExtension 7.0, *) {
        notificationCenter.post(
          name: WKExtension.applicationDidBecomeActiveNotification,
          object: nil
        )
      }
    #endif
  }

  func test_beginListening_initiatesColdStart() throws {
    let initiator = SessionInitiator()
    var initiateCalled = false
    initiator.beginListening {
      initiateCalled = true
    }
    XCTAssert(initiateCalled)
  }

  func test_appForegrounded_initiatesNewSession() throws {
    // Given
    var pausedClock = date
    let initiator = SessionInitiator(currentTimeProvider: { pausedClock })
    var sessionCount = 0
    initiator.beginListening {
      sessionCount += 1
    }
    XCTAssert(sessionCount == 1)

    // When
    // Background, advance time by 30 minutes + 1 second, then foreground
    postBackgroundedNotification()
    pausedClock.addTimeInterval(30 * 60 + 1)
    postForegroundedNotification()
    // Then
    // Session count increases because time spent in background > 30 minutes
    XCTAssert(sessionCount == 2)

    // When
    // Background, advance time by exactly 30 minutes, then foreground
    postBackgroundedNotification()
    pausedClock.addTimeInterval(30 * 60)
    postForegroundedNotification()
    // Then
    // Session count doesn't increase because time spent in background <= 30 minutes
    XCTAssert(sessionCount == 2)
  }
}
