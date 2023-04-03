//
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

#if SWIFT_PACKAGE
  import FirebaseSessionsObjC
#endif // SWIFT_PACKAGE

@testable import FirebaseSessions

final class FirebaseSessionsTestsBase_BaseBehaviors: FirebaseSessionsTestsBase {
  // MARK: - Test Settings & Sampling

  func test_settingsDisabled_doesNotLogSessionEventButDoesFetchSettings() {
    runSessionsSDK(
      subscriberSDKs: [
        mockPerformanceSubscriber,

      ], preSessionsInit: { _ in
        self.mockSettings.sessionsEnabled = false

      }, postSessionsInit: {
        sessions.register(subscriber: self.mockPerformanceSubscriber)

      }, postLogEvent: { result, subscriberSDKs in
        // Make sure we failed with the correct error
        self.assertFailure(result: result, expectedError: .DisabledViaSettingsError)

        // We must still fetch settings because otherwise we would
        // never fetch them again when we disabled the SDK via settings
        XCTAssertTrue(self.mockSettings.updateSettingsCalled)

        // Make sure we didn't log any events
        XCTAssertNil(self.mockCoordinator.loggedEvent)
      }
    )
  }

  func test_sessionSampled_doesNotLogSessionEventButDoesFetchSettings() {
    runSessionsSDK(
      subscriberSDKs: [
        mockPerformanceSubscriber,

      ], preSessionsInit: { _ in
        self.mockSettings.samplingRate = 0.0

      }, postSessionsInit: {
        sessions.register(subscriber: self.mockPerformanceSubscriber)

      }, postLogEvent: { result, subscriberSDKs in
        // Make sure we failed with the correct error
        self.assertFailure(result: result, expectedError: .SessionSamplingError)

        // We must still fetch settings because otherwise we could
        // get stuck with a sampling rate that samples all events.
        XCTAssertTrue(self.mockSettings.updateSettingsCalled)

        // Make sure we didn't log any events
        XCTAssertNil(self.mockCoordinator.loggedEvent)
      }
    )
  }

  // MARK: - Test Multiple Initiation

  // This test is failing on CI for watchOS only. I can't reproduce it locally
  // which may be due to the CI machine running x86 simulators. Disabling
  // this test for now.
  #if !os(watchOS)

    // This test ensures that if we go into the background for longer than
    // the Session Timeout, we log another event when we come to the foreground.
    //
    // We wanted to make sure that since we've introduced promises,
    // once the promise has been fulfilled, that .then'ing on the promise
    // in future initiations still results in a log
    func test_multipleInitiations_logsSessionEventEachInitiation() {
      var loggedCount = 0
      var lastLoggedSessionID = ""
      let loggedTwiceExpectation = expectation(description: "Sessions SDK logged events twice")

      runSessionsSDK(
        subscriberSDKs: [
          mockPerformanceSubscriber,

        ], preSessionsInit: { _ in

        }, postSessionsInit: {
          sessions.register(subscriber: self.mockPerformanceSubscriber)

        }, postLogEvent: { result, subscriberSDKs in
          // Make sure we log the event
          self.assertSuccess(result: result)

          // Make sure we logged an event and fetched settings
          XCTAssertTrue(self.mockSettings.updateSettingsCalled)
          XCTAssertNotNil(self.mockCoordinator.loggedEvent)

          // Make sure the Session ID changes between initiations
          XCTAssertNotEqual(lastLoggedSessionID, self.sessions.currentSessionDetails.sessionId)

          // Make sure the session ID logged to the coordinator has the
          // same Session ID as the currentSessionDetails passed to Subscribers
          assertEqualProtoString(
            self.mockCoordinator.loggedEvent?.proto.session_data.session_id,
            expected: self.sessions.currentSessionDetails.sessionId!, fieldName: "session_id"
          )

          lastLoggedSessionID = self.sessions.currentSessionDetails.sessionId!
          loggedCount += 1

          if loggedCount <= 1 {
            // The first time we log an event, put the app in the background,
            // travel forward in time loger than the Session Timeout, and
            // then bring the app to the foreground to generate another session.
            //
            // This postLogEvent callback will be called again after this
            self.postBackgroundedNotification()
            self.pausedClock.addTimeInterval(30 * 60 + 1)
            self.postForegroundedNotification()

          } else {
            loggedTwiceExpectation.fulfill()
          }
        }
      )

      wait(for: [loggedTwiceExpectation], timeout: 3)

      // Make sure we logged 2 events
      XCTAssertEqual(loggedCount, 2)
    }

  #endif // !os(watchOS)
}
