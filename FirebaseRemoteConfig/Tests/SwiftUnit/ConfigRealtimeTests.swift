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

import FirebaseCore
import FirebaseInstallations
@testable import FirebaseRemoteConfig
import GoogleUtilities
import XCTest

typealias ConfigFetchCompletion = (RemoteConfigFetchStatus, RemoteConfigUpdate?, Error?) -> Void

class ConfigRealtimeTests: XCTestCase {
  // Fake ConfigFetch - Simulates successful fetch with controllable version number
  private class FakeConfigFetch: ConfigFetch {
    var fakeTemplateVersionNumber: String = "0"
    var fetchCompletionHandler: ConfigFetchCompletion?

    override func realtimeFetchConfig(fetchAttemptNumber: Int,
                                      completionHandler: @escaping ConfigFetchCompletion) {
      fetchCompletionHandler = completionHandler
    }
  }

  public typealias FIRInstallationsTokenHandler = (InstallationsAuthTokenResult?, Error?) -> Void
  public typealias FIRInstallationsIDHandler = (String?, Error?) -> Void

  // Fake Installations - Simulates Installations token retrieval
  private class FakeInstallations: InstallationsProtocol {
    var fakeAuthToken: String?
    var fakeInstallationID: String?
    var authTokenCompletion: FIRInstallationsTokenHandler?
    var installationIDCompletion: FIRInstallationsIDHandler?

    func authToken(completion: @escaping FIRInstallationsTokenHandler) {
      authTokenCompletion = completion
    }

    func installationID(completion: @escaping FIRInstallationsIDHandler) {
      installationIDCompletion = completion
    }
  }

  var realtime: ConfigRealtime!
  private var fakeFetch: FakeConfigFetch!
  var fakeSettings: ConfigSettings!
  private var fakeInstallations: FakeInstallations!
  var options: FirebaseOptions!
  let namespace = "test_namespace:test_app"
  let expectationTimeout: TimeInterval = 2

  override func setUp() {
    super.setUp()
    options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef1234567890",
                              gcmSenderID: "1234567890")
    options.apiKey = "fake_api_key"
    fakeFetch = FakeConfigFetch(
      content: ConfigContent.sharedInstance,
      DBManager: ConfigDBManager.sharedInstance,
      settings: ConfigSettings(databaseManager: ConfigDBManager.sharedInstance,
                               namespace: namespace, firebaseAppName: "test_app",
                               googleAppID: options.googleAppID),
      analytics: nil,
      experiment: nil,
      queue: DispatchQueue.main,
      namespace: namespace,
      options: options
    )
    fakeSettings = ConfigSettings(databaseManager: ConfigDBManager.sharedInstance,
                                  namespace: namespace, firebaseAppName: "test_app",
                                  googleAppID: options.googleAppID)

    fakeInstallations = FakeInstallations()
    realtime = ConfigRealtime(configFetch: fakeFetch,
                              settings: fakeSettings, namespace: namespace,
                              options: options, installations: fakeInstallations)
  }

  override func tearDown() {
    realtime = nil
    fakeFetch = nil
    fakeSettings = nil
    options = nil
    fakeInstallations = nil
    super.tearDown()
  }

  private let fetchResponseHTTPStatusOK = 200
  private let fetchResponseHTTPStatusClientTimeout = 429
  private let fetchResponseHTTPStatusCodeBadGateway = 502
  private let fetchResponseHTTPStatusCodeServiceUnavailable = 503
  private let fetchResponseHTTPStatusCodeGatewayTimeout = 504

  func testIsStatusCodeRetryable() {
    XCTAssertTrue(realtime.isStatusCodeRetryable(fetchResponseHTTPStatusClientTimeout))
    XCTAssertTrue(realtime.isStatusCodeRetryable(fetchResponseHTTPStatusCodeServiceUnavailable))
    XCTAssertTrue(realtime.isStatusCodeRetryable(fetchResponseHTTPStatusCodeBadGateway))
    XCTAssertTrue(realtime.isStatusCodeRetryable(fetchResponseHTTPStatusCodeGatewayTimeout))
    XCTAssertFalse(realtime.isStatusCodeRetryable(fetchResponseHTTPStatusOK))
    XCTAssertFalse(realtime.isStatusCodeRetryable(400)) // Example non-retryable code
  }

  func testInBackground() {
    realtime.isInBackground = true // Set background state
    XCTAssertFalse(realtime.canMakeConnection()) // Should not be able to connect
  }

  func testRealtimeDisabled() {
    realtime.isRealtimeDisabled = true // Disable realtime updates
    XCTAssertFalse(realtime.canMakeConnection()) // Should not be able to connect
  }
}
