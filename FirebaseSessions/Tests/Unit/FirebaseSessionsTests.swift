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

final class MockSubscriber: SessionsSubscriber {
  var sessionThatChanged: FirebaseSessions.SessionPayload?

  init(name: SessionsSubscriberName) {
    sessionsSubscriberName = name
  }

  func onSessionChanged(_ session: FirebaseSessions.SessionPayload) {
    self.sessionThatChanged = session
  }

  var isDataCollectionEnabled: Bool = true

  var sessionsSubscriberName: FirebaseSessions.SessionsSubscriberName
}

class FirebaseSessionsTests: XCTestCase {
  let testAppID = "testAppID"

  // Mocks
  var mockCoordinator: MockSessionCoordinator!
  var mockAppInfo: MockApplicationInfo!
  var mockSettings: MockSettingsProtocol!

  // Non-mock dependencies
  var initiator: SessionInitiator!
  var generator: SessionGenerator!

  // Class under test
  var sessions: Sessions!

  // Example subscribers
  var mockCrashlyticsSubscriber: MockSubscriber!
  var mockPerformanceSubscriber: MockSubscriber!
  var allSubscribers: [SessionsSubscriber] {
    return [self.mockCrashlyticsSubscriber, self.mockPerformanceSubscriber]
  }

  // Mock controllers
  var pausedClock = Date(timeIntervalSince1970: 1_635_739_200)

  override func setUp() {
    // Reset the subscribers between tests
    mockCrashlyticsSubscriber = MockSubscriber(name: SessionsSubscriberName.Crashlytics)
    mockPerformanceSubscriber = MockSubscriber(name: SessionsSubscriberName.Performance)
  }

  /// This function forms the basis for all tests of type `FirebaseSessionsTests`. It's written
  /// so that you don't need to setup expectations for each test individually.
  ///
  /// It has 4 parts:
  ///  - `subscriberSDKs` tells the test to expect the list of subscriber SDKs
  ///  - `preSessionsInit`  is before Sessions or any Subscriber SDKs start up. This is a good
  /// place to mock variables in any dependencies (eg. Settings, or mocking any Subscribers themselves)
  ///  - `postSessionsInit` is after Sessions has started up, but before logging any events. This
  /// is a good place for Subscribers to call register on the Sessions SDK
  ///  - `postLogEvent` is called whenever an event is logged via the Sessions SDK. This is where
  /// most assertions will happen.
  func runSessionsSDK(subscriberSDKs: [SessionsSubscriber],
                      preSessionsInit: (MockSettingsProtocol) -> Void,
                      postSessionsInit: () -> Void,
                      postLogEvent: @escaping (Result<Void, FirebaseSessionsError>, [SessionsSubscriber]) -> Void) {
    // This class is static, so we need to clear global state
    SessionsDependencies.dependencies.removeAll()

    for subscriberSDK in subscriberSDKs {
      SessionsDependencies.addDependency(name: subscriberSDK.sessionsSubscriberName)
    }

    // Setup an expectation so we can wait for loggedEventCallback to be called.
    // We need the expectation because the callback is called in the background
    let loggedEventExpectation = XCTestExpectation(description: "Called loggedEventCallback")

    mockCoordinator = MockSessionCoordinator()

    mockAppInfo = MockApplicationInfo()

    mockSettings = MockSettingsProtocol()

    // Allow tests to configure settings before it is used during
    // initialization of other classes
    preSessionsInit(mockSettings)

    generator = SessionGenerator(settings: mockSettings)
    initiator = SessionInitiator(settings: mockSettings, currentTimeProvider: {
      self.pausedClock
    })

    sessions = Sessions(appID: testAppID,
                        sessionGenerator: generator,
                        coordinator: mockCoordinator,
                        initiator: initiator,
                        appInfo: mockAppInfo,
                        settings: mockSettings) { result in

      // Provide the result for tests to test against
      postLogEvent(result, subscriberSDKs)

      // Fulfil the expectation so the test can continue
      loggedEventExpectation.fulfill()
    }

    // Execute test cases after Sessions is initialized. This is a good
    // place register Subscriber SDKs
    postSessionsInit()

    // Wait for the Sessions SDK to log the session before finishing
    // the test.
    wait(for: [loggedEventExpectation], timeout: 3)
  }

  func assertSuccess(result: Result<Void, FirebaseSessionsError>) {
    switch result {
    case .success(()): break
    case let .failure(error):
      XCTFail("Expected success but got failure with error: \(error)")
    }
  }

  func assertFailure(result: Result<Void, FirebaseSessionsError>,
                     expectedError: FirebaseSessionsError) {
    switch result {
    case .success(()):
      XCTFail("Expected failure but got success")
    case let .failure(error):
      XCTAssertEqual(error, expectedError)
    }
  }

  // MARK: - Test Settings & Sampling

  func test_settingsDisabled_doesNotLogSessionEventButDoesFetchSettings() {
    runSessionsSDK(
      subscriberSDKs: [
        self.mockPerformanceSubscriber,

      ], preSessionsInit: { _ in
        self.mockSettings.sessionsEnabled = false

      }, postSessionsInit: {
        sessions.register(subscriber: self.mockPerformanceSubscriber)

      }, postLogEvent: { (result, subscriberSDKs)  in
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
        self.mockPerformanceSubscriber,

      ], preSessionsInit: { _ in
        self.mockSettings.samplingRate = 0.0

      }, postSessionsInit: {
        sessions.register(subscriber: self.mockPerformanceSubscriber)

      }, postLogEvent: { (result, subscriberSDKs)  in
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

  // MARK: - Test Subscriber Callbacks

  func test_subscribersDataCollectionDisabled_callsOnSessionChanged() {
    runSessionsSDK(
      subscriberSDKs: [
        mockCrashlyticsSubscriber,
        mockPerformanceSubscriber,

      ], preSessionsInit: { _ in
        // Same as above, but this time we've disabled data collection in
        // only one of the subscribers
        self.mockCrashlyticsSubscriber.isDataCollectionEnabled = false
        self.mockCrashlyticsSubscriber.isDataCollectionEnabled = false

      }, postSessionsInit: {
        // Register the subscribers
        sessions.register(subscriber: self.mockPerformanceSubscriber)
        sessions.register(subscriber: self.mockCrashlyticsSubscriber)

      }, postLogEvent: { (result, subscriberSDKs) in
        let protoSessionID = self.mockCoordinator.loggedEvent?.proto.session_data.session_id
        for mock in [self.mockCrashlyticsSubscriber, self.mockPerformanceSubscriber] {
          let changedSessionID = mock?.sessionThatChanged?.sessionId ?? ""
          assertEqualProtoString(protoSessionID, expected: changedSessionID, fieldName: "session_id")
        }
      }
    )
  }

  func test_subscribersDataCollectionDisabled_callsOnSessionChanged() {
    sadasdsa
    Need to handle NoDependenciesError
//    runSessionsSDK(
//      subscriberSDKs: [
//        mockCrashlyticsSubscriber,
//        mockPerformanceSubscriber,
//
//      ], preSessionsInit: { _ in
//        // Same as above, but this time we've disabled data collection in
//        // only one of the subscribers
//        self.mockCrashlyticsSubscriber.isDataCollectionEnabled = false
//        self.mockCrashlyticsSubscriber.isDataCollectionEnabled = false
//
//      }, postSessionsInit: {
//        // Register the subscribers
//        sessions.register(subscriber: self.mockPerformanceSubscriber)
//        sessions.register(subscriber: self.mockCrashlyticsSubscriber)
//
//      }, postLogEvent: { (result, subscriberSDKs) in
//        let protoSessionID = self.mockCoordinator.loggedEvent?.proto.session_data.session_id
//        for mock in [self.mockCrashlyticsSubscriber, self.mockPerformanceSubscriber] {
//          let changedSessionID = mock?.sessionThatChanged?.sessionId ?? ""
//          assertEqualProtoString(protoSessionID, expected: changedSessionID, fieldName: "session_id")
//        }
//      }
//    )
  }


  // MARK: - Test Multiple Initiation

  // This test ensures that if we go into the background for longer than
  // the Session Timeout, we log another event when we come to the foreground.
  //
  // We wanted to make sure that since we've introduced promises,
  // once the promise has been fulfilled, that .then'ing on the promise
  // in future initiations still results in a log
  func test_multipleInitiatiations_logsSessionEventEachInitiation() {
    var loggedCount = 0
    var lastLoggedSessionID = ""
    let loggedTwiceExpectation = expectation(description: "Sessions SDK logged events twice")

    runSessionsSDK(
      subscriberSDKs: [
        self.mockPerformanceSubscriber,

      ], preSessionsInit: { _ in

      }, postSessionsInit: {
        sessions.register(subscriber: self.mockPerformanceSubscriber)

      }, postLogEvent: { (result, subscriberSDKs)  in
        // Make sure we log the event
        self.assertSuccess(result: result)

        // Make sure we logged an event and fetched settings
        XCTAssertTrue(self.mockSettings.updateSettingsCalled)
        XCTAssertNotNil(self.mockCoordinator.loggedEvent)

        // Make sure the Session ID changes between initiations
        XCTAssertNotEqual(lastLoggedSessionID, self.sessions.currentSessionPayload.sessionId)

        // Make sure the session ID logged to the coordinator has the
        // same Session ID as the currentSessionPayload passed to Subscribers
        assertEqualProtoString(
          self.mockCoordinator.loggedEvent?.proto.session_data.session_id, expected: self.sessions.currentSessionPayload.sessionId, fieldName: "session_id")

        lastLoggedSessionID = self.sessions.currentSessionPayload.sessionId
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

    self.wait(for: [loggedTwiceExpectation], timeout: 3)

    // Make sure we logged 2 events
    XCTAssertEqual(loggedCount, 2)
  }
}
