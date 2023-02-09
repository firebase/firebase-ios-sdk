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

final class FirebaseSessionsTestsBase_DataCollection: FirebaseSessionsTestsBase {
  // Ensure that for all subscribers, that the data collection state is correctly set.
  func assertEventDataCollectionCorrect(subscribedSDKs: [SessionsSubscriber]) {
    guard let loggedEvent = mockCoordinator.loggedEvent else {
      XCTFail(
        "Sessions had a successful result, but the mock Coordinator did not have a loggedEvent set"
      )
      return
    }
    let protoDataCollection = loggedEvent.proto.session_data.data_collection_status
    // Look through all possible subscribers, not just the ones subscribed in the test
    for subscriberSDK in allSubscribers {
      // Check if the subscriber was subscribed or not, because non-subscribers should
      // have their data collection state set to UNKNOWN
      let isSubscribed = subscribedSDKs.contains { subscriber in
        subscriber.sessionsSubscriberName == subscriberSDK.sessionsSubscriberName
      }

      switch subscriberSDK.sessionsSubscriberName {
      case .Crashlytics:
        assertEventDataCollectionProtoEqual(
          isDataCollectionEnabled: subscriberSDK.isDataCollectionEnabled,
          isSubscribed: isSubscribed,
          protoState: protoDataCollection.crashlytics
        )
      case .Performance:
        assertEventDataCollectionProtoEqual(
          isDataCollectionEnabled: subscriberSDK.isDataCollectionEnabled,
          isSubscribed: isSubscribed,
          protoState: protoDataCollection.performance
        )
      case .Unknown:
        XCTFail("Sessions subscribed to with 'Unknown' Subscriber Name")
      }
    }
  }

  func assertEventDataCollectionProtoEqual(isDataCollectionEnabled: Bool,
                                           isSubscribed: Bool,
                                           protoState: firebase_appquality_sessions_DataCollectionState) {
    if !isSubscribed {
      XCTAssertEqual(
        protoState,
        firebase_appquality_sessions_DataCollectionState_COLLECTION_SDK_NOT_INSTALLED
      )
    } else if isDataCollectionEnabled {
      XCTAssertEqual(
        protoState,
        firebase_appquality_sessions_DataCollectionState_COLLECTION_ENABLED
      )
    } else {
      XCTAssertEqual(
        protoState,
        firebase_appquality_sessions_DataCollectionState_COLLECTION_DISABLED
      )
    }
  }

  // MARK: - Test Data Collection

  func test_subscriberWithDataCollectionEnabled_logsSessionEvent() {
    runSessionsSDK(
      subscriberSDKs: [
        mockCrashlyticsSubscriber,

      ], preSessionsInit: { _ in
        // Nothing
      }, postSessionsInit: {
        sessions.register(subscriber: self.mockCrashlyticsSubscriber)

        // Sessions hasn't logged yet because no Subscriber SDKs have registered
        XCTAssertNil(self.mockCoordinator.loggedEvent)

      }, postLogEvent: { result, subscriberSDKs in
        // Make sure the SDK reported success, we logged an event and
        // Settings fetched new configs
        self.assertSuccess(result: result)
        self.assertEventDataCollectionCorrect(subscribedSDKs: subscriberSDKs)
        XCTAssertTrue(self.mockSettings.updateSettingsCalled)
        XCTAssertNotNil(self.mockCoordinator.loggedEvent)
      }
    )
  }

  func test_subscribersSomeDataCollectionDisabled_logsSessionEvent() {
    runSessionsSDK(
      subscriberSDKs: [
        mockCrashlyticsSubscriber,
        mockPerformanceSubscriber,

      ], preSessionsInit: { _ in
        // Same as above, but this time we've disabled data collection in
        // only one of the subscribers
        self.mockCrashlyticsSubscriber.isDataCollectionEnabled = false

      }, postSessionsInit: {
        // Register the subscribers
        sessions.register(subscriber: self.mockPerformanceSubscriber)
        sessions.register(subscriber: self.mockCrashlyticsSubscriber)

      }, postLogEvent: { result, subscriberSDKs in
        // Make sure the SDK reported success, we logged an event and
        // Settings fetched new configs
        self.assertSuccess(result: result)
        self.assertEventDataCollectionCorrect(subscribedSDKs: subscriberSDKs)
        XCTAssertTrue(self.mockSettings.updateSettingsCalled)
        XCTAssertNotNil(self.mockCoordinator.loggedEvent)
      }
    )
  }

  func test_subscribersAllDataCollectionDisabled_doesNotLogSessionEvent() {
    runSessionsSDK(
      subscriberSDKs: [
        mockCrashlyticsSubscriber,
        mockPerformanceSubscriber,

      ], preSessionsInit: { _ in
        // We've disabled data collection in all our Subscriber SDKs
        self.mockCrashlyticsSubscriber.isDataCollectionEnabled = false
        self.mockPerformanceSubscriber.isDataCollectionEnabled = false

      }, postSessionsInit: {
        // Register the subscribers
        sessions.register(subscriber: self.mockCrashlyticsSubscriber)
        sessions.register(subscriber: self.mockPerformanceSubscriber)

      }, postLogEvent: { result, subscriberSDKs in
        // Make sure we failed with the correct error
        self.assertFailure(result: result, expectedError: .DataCollectionError)

        // Make sure we didn't do any data collection
        XCTAssertFalse(self.mockSettings.updateSettingsCalled)
        XCTAssertNil(self.mockCoordinator.loggedEvent)
      }
    )
  }

  func test_defaultSamplingRate_isSetInProto() {
    runSessionsSDK(
      subscriberSDKs: [
        mockCrashlyticsSubscriber,

      ], preSessionsInit: { _ in
        // Nothing
      }, postSessionsInit: {
        sessions.register(subscriber: self.mockCrashlyticsSubscriber)
        // Nothing

      }, postLogEvent: { result, subscriberSDKs in
        // Make sure we set the sampling rate in the proto
        XCTAssertEqual(
          self.mockCoordinator.loggedEvent?.proto.session_data.data_collection_status
            .session_sampling_rate,
          1.0
        )
      }
    )
  }
}
