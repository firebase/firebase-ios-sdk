// Copyright 2025 Google LLC
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

@testable import FirebaseRemoteConfig
import XCTest

class UserDefaultsManagerTests: XCTestCase {
  let appName = "testApp"
  let bundleID = "com.example.testApp"
  let namespace = "namespace:app"
  let fullyQualifiedNamespace = "namespace:testApp"

  override func setUp() {
    super.setUp()
    // Clear for clean test state
    let persistentDomain = UserDefaultsManager.userDefaultsSuiteName(for: bundleID)
    UserDefaults.standard.removePersistentDomain(forName: persistentDomain)
  }

  func testSharedUserDefaultsForBundleIdentifier() {
    let defaults1 = UserDefaultsManager.sharedUserDefaultsForBundleIdentifier(bundleID)
    let defaults2 = UserDefaultsManager.sharedUserDefaultsForBundleIdentifier(bundleID)
    XCTAssertTrue(defaults1 === defaults2) // Should return the same instance each time
  }

  func testUserDefaultsSuiteName() {
    let suiteName = UserDefaultsManager.userDefaultsSuiteName(for: bundleID)
    XCTAssertEqual(suiteName, "group.\(bundleID).firebase")
  }

  func testLastETag() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    manager.lastETag = "eTag1"
    XCTAssertEqual(manager.lastETag, "eTag1")
  }

  func testSettingNilLastETagIsNoOp() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    manager.lastETag = "eTag1"
    XCTAssertEqual(manager.lastETag, "eTag1")
    manager.lastETag = nil
    XCTAssertEqual(manager.lastETag, "eTag1")
  }

  func testLastFetchedTemplateVersion() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    // Test default value
    // Default should be "0"
    XCTAssertEqual(manager.lastFetchedTemplateVersion, "0")
    manager.lastFetchedTemplateVersion = "123"
    XCTAssertEqual(manager.lastFetchedTemplateVersion, "123")
  }

  func testUserDefaultsSharedWithinBundleID() {
    let manager1 = UserDefaultsManager(appName: appName, bundleID: bundleID, namespace: namespace)
    let manager2 = UserDefaultsManager(appName: appName, bundleID: bundleID, namespace: namespace)
    let manager3 = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace + "1"
    )
    let manager4 = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID + "1",
      namespace: namespace
    )
    manager1.lastETag = "etag1"
    XCTAssertEqual(manager2.lastETag, "etag1")
    XCTAssertEqual(manager3.lastETag, "etag1")
    XCTAssertNil(manager4.lastETag)
  }

  func testLastActiveTemplateVersion() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    // Test default value
    // Default should be "0"
    XCTAssertEqual(manager.lastActiveTemplateVersion, "0")
    manager.lastActiveTemplateVersion = "456"
    XCTAssertEqual(manager.lastActiveTemplateVersion, "456")
  }

  func testLastETagUpdateTime() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    let time: TimeInterval = 1_678_886_400 // Example timestamp
    manager.lastETagUpdateTime = time
    XCTAssertEqual(manager.lastETagUpdateTime, time)
  }

  func testLastFetchTime() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    let time: TimeInterval = 1_678_886_400 // Example timestamp
    manager.lastFetchTime = time
    XCTAssertEqual(manager.lastFetchTime, time)
  }

  func testLastFetchStatus() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    manager.lastFetchStatus = "Success"
    XCTAssertEqual(manager.lastFetchStatus, "Success")
  }

  func testLastFetchStatusIsNoOp() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    manager.lastETag = "eTag1"
    XCTAssertEqual(manager.lastETag, "eTag1")
    manager.lastETag = nil
    XCTAssertEqual(manager.lastETag, "eTag1")
  }

  func testIsClientThrottledWithExponentialBackoff() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    manager.isClientThrottledWithExponentialBackoff = true
    XCTAssertTrue(manager.isClientThrottledWithExponentialBackoff)

    manager.isClientThrottledWithExponentialBackoff = false
    XCTAssertFalse(manager.isClientThrottledWithExponentialBackoff)
  }

  func testThrottleEndTime() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    let time: TimeInterval = 1_678_886_400 // Example timestamp
    manager.throttleEndTime = time
    XCTAssertEqual(manager.throttleEndTime, time)
  }

  func testCurrentThrottlingRetryIntervalSeconds() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    let interval: TimeInterval = 300 // Example interval
    manager.currentThrottlingRetryIntervalSeconds = interval
    XCTAssertEqual(manager.currentThrottlingRetryIntervalSeconds, interval)
  }

  func testRealtimeRetryCount() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )

    manager.realtimeRetryCount = 5
    XCTAssertEqual(manager.realtimeRetryCount, 5)
  }

  func testRealtimeThrottleEndTime() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    let time: TimeInterval = 1_678_886_400 // Example timestamp
    manager.realtimeThrottleEndTime = time
    XCTAssertEqual(manager.realtimeThrottleEndTime, time)
  }

  func testCurrentRealtimeThrottlingRetryIntervalSeconds() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    let interval: TimeInterval = 300 // Example interval
    manager.currentRealtimeThrottlingRetryIntervalSeconds = interval
    XCTAssertEqual(manager.currentRealtimeThrottlingRetryIntervalSeconds, interval)
  }

  func testResetUserDefaults() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: bundleID,
      namespace: namespace
    )
    manager.lastETag = "testValue"
    manager.resetUserDefaults()
    XCTAssertNil(manager.lastETag) // Check if value was removed
  }
}
