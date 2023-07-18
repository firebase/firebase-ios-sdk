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

///
/// This is the parent class for tests that test against the Sessions internal
/// API or test Sessions `init` functionality.
///
/// Test cases should only go in subclasses because all tests in the parent
/// class will be run by subclasses.
///
class FirebaseSessionsTestsBase: XCTestCase {
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
    return [mockCrashlyticsSubscriber, mockPerformanceSubscriber]
  }

  // Mock controllers
  var pausedClock = Date(timeIntervalSince1970: 1_635_739_200)

  override func setUp() {
    // Reset the subscribers between tests
    mockCrashlyticsSubscriber = MockSubscriber(name: SessionsSubscriberName.Crashlytics)
    mockPerformanceSubscriber = MockSubscriber(name: SessionsSubscriberName.Performance)
  }

  /// This function forms the basis for all tests of type `FirebaseSessionsTestsBase`. It's written
  /// so that you don't need to setup expectations for each test individually.
  ///
  /// It has 4 parts:
  ///  - `subscriberSDKs` tells the test to expect the list of subscriber SDKs
  ///  - `preSessionsInit`  is before Sessions or any Subscriber SDKs start up. This is a good
  /// place to mock variables in any dependencies (eg. Settings, or mocking any Subscribers
  /// themselves)
  ///  - `postSessionsInit` is after Sessions has started up, but before logging any events. This
  /// is a good place for Subscribers to call register on the Sessions SDK
  ///  - `postLogEvent` is called whenever an event is logged via the Sessions SDK. This is where
  /// most assertions will happen.
  func runSessionsSDK(subscriberSDKs: [SessionsSubscriber],
                      preSessionsInit: (MockSettingsProtocol) -> Void,
                      postSessionsInit: () -> Void,
                      postLogEvent: @escaping (Result<Void, FirebaseSessionsError>,
                                               [SessionsSubscriber]) -> Void) {
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

    generator = SessionGenerator(collectEvents: Sessions
      .shouldCollectEvents(settings: mockSettings))
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

  // Do not add tests to this class because they will be run by all subclasses
}
