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

final class FirebaseSessionsTestsBase_Subscribers: FirebaseSessionsTestsBase {
  // Check that the Session ID that was passed to the Subscriber SDK
  // matches the Session ID that the Sessions SDK logged, and ensure
  // both are not empty.
  func assertValidChangedSessionID() {
    let expectedSessionID = sessions.currentSessionDetails.sessionId
    XCTAssert(expectedSessionID!.count > 0)
    for mock in [mockCrashlyticsSubscriber, mockPerformanceSubscriber] {
      let mocksChangedSessionID = mock?.sessionThatChanged?.sessionId!
      XCTAssert(mocksChangedSessionID!.count > 0)
      XCTAssertEqual(expectedSessionID, mocksChangedSessionID)
    }
  }

  // MARK: - Test Subscriber Callbacks

  func test_registerSubscriber_callsOnSessionChanged() {
    runSessionsSDK(
      subscriberSDKs: [
        mockCrashlyticsSubscriber,
        mockPerformanceSubscriber,

      ], preSessionsInit: { _ in
        // Nothing

      }, postSessionsInit: {
        // Register the subscribers
        sessions.register(subscriber: self.mockPerformanceSubscriber)
        sessions.register(subscriber: self.mockCrashlyticsSubscriber)

      }, postLogEvent: { result, subscriberSDKs in
        // Ensure the subscribers still get a Session ID from their subscription
        self.assertValidChangedSessionID()
      }
    )
  }

  // Make sure that even if the Sessions SDK is disabled, and data collection
  // is disabled, the Sessions SDK still generates Session IDs and provides
  // them to Subscribers
  func test_subscribersDataCollectionDisabled_callsOnSessionChanged() {
    runSessionsSDK(
      subscriberSDKs: [
        mockCrashlyticsSubscriber,
        mockPerformanceSubscriber,

      ], preSessionsInit: { _ in
        // Disable the Sessions SDK in all possible ways
        self.mockCrashlyticsSubscriber.isDataCollectionEnabled = false
        self.mockCrashlyticsSubscriber.isDataCollectionEnabled = false
        self.mockSettings.sessionsEnabled = false
        self.mockSettings.samplingRate = 0.0

      }, postSessionsInit: {
        // Register the subscribers
        sessions.register(subscriber: self.mockPerformanceSubscriber)
        sessions.register(subscriber: self.mockCrashlyticsSubscriber)

      }, postLogEvent: { result, subscriberSDKs in
        // Ensure the subscribers still get a Session ID from their subscription
        self.assertValidChangedSessionID()
      }
    )
  }

  func test_noDependencies_doesNotLogSessionEvent() {
    runSessionsSDK(
      subscriberSDKs: [],
      preSessionsInit: { _ in
        // Nothing
      }, postSessionsInit: {
        // Nothing
      }, postLogEvent: { result, subscriberSDKs in
        // Make sure we didn't do any data collection
        self.assertFailure(result: result, expectedError: .NoDependenciesError)
        XCTAssertFalse(self.mockSettings.updateSettingsCalled)
        XCTAssertNil(self.mockCoordinator.loggedEvent)
      }
    )
  }

  func test_noSubscribersWithRegistrations_doesNotCrash() {
    runSessionsSDK(
      subscriberSDKs: [],
      preSessionsInit: { _ in
        // Nothing
      }, postSessionsInit: {
        // Register the subscribers even though they didn't
        // add themselves as dependencies.
        // This case shouldn't happen but if it did we don't want
        // to have any unexpected behavior
        sessions.register(subscriber: self.mockPerformanceSubscriber)
        sessions.register(subscriber: self.mockCrashlyticsSubscriber)

      }, postLogEvent: { result, subscriberSDKs in
        // Make sure we didn't do any data collection
        self.assertFailure(result: result, expectedError: .NoDependenciesError)
        XCTAssertFalse(self.mockSettings.updateSettingsCalled)
        XCTAssertNil(self.mockCoordinator.loggedEvent)
      }
    )
  }
}
