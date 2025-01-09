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

private let appName = "testApp"
private let fqNamespace1 = "testNamespace1:testApp"
private let fqNamespace2 = "testNamespace2:testApp"
private var userDefaultsSampleTimestamp: TimeInterval = 0

class UserDefaultsManagerOrigTests: XCTestCase {
  override func setUp() {
    super.setUp()
    // Clear UserDefaults before each test.
    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    userDefaultsSampleTimestamp = Date().timeIntervalSince1970
  }

  func testUserDefaultsEtagWriteAndRead() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)
    manager.lastETag = "eTag1"
    XCTAssertEqual(manager.lastETag, "eTag1")

    manager.lastETag = "eTag2"
    XCTAssertEqual(manager.lastETag, "eTag2")
  }

  func testUserDefaultsLastFetchTimeWriteAndRead() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)
    manager.lastFetchTime = userDefaultsSampleTimestamp
    XCTAssertEqual(manager.lastFetchTime, userDefaultsSampleTimestamp)

    manager.lastFetchTime = userDefaultsSampleTimestamp - 1000
    XCTAssertEqual(manager.lastFetchTime, userDefaultsSampleTimestamp - 1000)
  }

  func testUserDefaultsLastETagUpdateTimeWriteAndRead() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)
    manager.lastETagUpdateTime = userDefaultsSampleTimestamp
    XCTAssertEqual(manager.lastETagUpdateTime, userDefaultsSampleTimestamp)

    manager.lastETagUpdateTime = userDefaultsSampleTimestamp - 1000
    XCTAssertEqual(manager.lastETagUpdateTime, userDefaultsSampleTimestamp - 1000)
  }

  func testUserDefaultsLastFetchStatusWriteAndRead() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)
    manager.lastFetchStatus = "Success"
    XCTAssertEqual(manager.lastFetchStatus, "Success")

    manager.lastFetchStatus = "Error"
    XCTAssertEqual(manager.lastFetchStatus, "Error")
  }

  func testUserDefaultsIsClientThrottledWriteAndRead() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)
    manager.isClientThrottledWithExponentialBackoff = true
    XCTAssertEqual(manager.isClientThrottledWithExponentialBackoff, true)

    manager.isClientThrottledWithExponentialBackoff = false
    XCTAssertEqual(manager.isClientThrottledWithExponentialBackoff, false)
  }

  func testUserDefaultsThrottleEndTimeWriteAndRead() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)

    manager.throttleEndTime = userDefaultsSampleTimestamp - 7.0
    XCTAssertEqual(manager.throttleEndTime, userDefaultsSampleTimestamp - 7.0)

    manager.throttleEndTime = userDefaultsSampleTimestamp - 8.0
    XCTAssertEqual(manager.throttleEndTime, userDefaultsSampleTimestamp - 8.0)
  }

  func testUserDefaultsCurrentThrottlingRetryIntervalWriteAndRead() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)
    manager.currentThrottlingRetryIntervalSeconds = userDefaultsSampleTimestamp - 1.0
    XCTAssertEqual(
      manager.currentThrottlingRetryIntervalSeconds,
      userDefaultsSampleTimestamp - 1.0
    )

    manager.currentThrottlingRetryIntervalSeconds = userDefaultsSampleTimestamp - 2.0
    XCTAssertEqual(
      manager.currentThrottlingRetryIntervalSeconds,
      userDefaultsSampleTimestamp - 2.0
    )
  }

  func testUserDefaultsTemplateVersionWriteAndRead() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)
    manager.lastFetchedTemplateVersion = "1"
    XCTAssertEqual(manager.lastFetchedTemplateVersion, "1")
  }

  func testUserDefaultsActiveTemplateVersionWriteAndRead() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)
    manager.lastActiveTemplateVersion = "1"
    XCTAssertEqual(manager.lastActiveTemplateVersion, "1")
  }

  func testUserDefaultsRealtimeThrottleEndTimeWriteAndRead() {
    let manager = UserDefaultsManager(
      appName: appName,
      bundleID: Bundle.main.bundleIdentifier!,
      namespace: fqNamespace1
    )

    manager.realtimeThrottleEndTime = userDefaultsSampleTimestamp - 7.0
    XCTAssertEqual(manager.realtimeThrottleEndTime, userDefaultsSampleTimestamp - 7.0)

    manager.realtimeThrottleEndTime = userDefaultsSampleTimestamp - 8.0
    XCTAssertEqual(manager.realtimeThrottleEndTime, userDefaultsSampleTimestamp - 8.0)
  }

  func testUserDefaultsCurrentRealtimeThrottlingRetryIntervalWriteAndRead() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)
    manager.currentRealtimeThrottlingRetryIntervalSeconds = userDefaultsSampleTimestamp - 1.0
    XCTAssertEqual(manager.currentRealtimeThrottlingRetryIntervalSeconds,
                   userDefaultsSampleTimestamp - 1.0)

    manager.currentRealtimeThrottlingRetryIntervalSeconds = userDefaultsSampleTimestamp - 2.0
    XCTAssertEqual(manager.currentRealtimeThrottlingRetryIntervalSeconds,
                   userDefaultsSampleTimestamp - 2.0)
  }

  func testUserDefaultsForMultipleNamespaces() {
    let manager1 = UserDefaultsManager(appName: appName,
                                       bundleID: Bundle.main.bundleIdentifier!,
                                       namespace: fqNamespace1)
    let manager2 = UserDefaultsManager(appName: appName,
                                       bundleID: Bundle.main.bundleIdentifier!,
                                       namespace: fqNamespace2)

    manager1.lastETag = "eTag1ForNamespace1"
    manager2.lastETag = "eTag1ForNamespace2"
    XCTAssertEqual(manager1.lastETag, "eTag1ForNamespace1")
    XCTAssertEqual(manager2.lastETag, "eTag1ForNamespace2")

    manager1.lastFetchTime = userDefaultsSampleTimestamp - 1000
    manager2.lastFetchTime = userDefaultsSampleTimestamp - 7000
    XCTAssertEqual(manager1.lastFetchTime, userDefaultsSampleTimestamp - 1000)
    XCTAssertEqual(manager2.lastFetchTime, userDefaultsSampleTimestamp - 7000)

    manager1.lastFetchStatus = "Success"
    manager2.lastFetchStatus = "Error"
    XCTAssertEqual(manager1.lastFetchStatus, "Success")
    XCTAssertEqual(manager2.lastFetchStatus, "Error")

    manager1.isClientThrottledWithExponentialBackoff = true
    manager2.isClientThrottledWithExponentialBackoff = false
    XCTAssertEqual(manager1.isClientThrottledWithExponentialBackoff, true)
    XCTAssertEqual(manager2.isClientThrottledWithExponentialBackoff, false)

    manager1.throttleEndTime = userDefaultsSampleTimestamp - 7.0
    manager2.throttleEndTime = userDefaultsSampleTimestamp - 8.0
    XCTAssertEqual(manager1.throttleEndTime, userDefaultsSampleTimestamp - 7.0)
    XCTAssertEqual(manager2.throttleEndTime, userDefaultsSampleTimestamp - 8.0)

    manager1.currentThrottlingRetryIntervalSeconds = userDefaultsSampleTimestamp - 1.0
    manager2.currentThrottlingRetryIntervalSeconds = userDefaultsSampleTimestamp - 2.0
    XCTAssertEqual(
      manager1.currentThrottlingRetryIntervalSeconds,
      userDefaultsSampleTimestamp - 1.0
    )
    XCTAssertEqual(
      manager2.currentThrottlingRetryIntervalSeconds,
      userDefaultsSampleTimestamp - 2.0
    )

    manager1.realtimeThrottleEndTime = userDefaultsSampleTimestamp - 7.0
    manager2.realtimeThrottleEndTime = userDefaultsSampleTimestamp - 8.0
    XCTAssertEqual(manager1.realtimeThrottleEndTime, userDefaultsSampleTimestamp - 7.0)
    XCTAssertEqual(manager2.realtimeThrottleEndTime, userDefaultsSampleTimestamp - 8.0)

    manager1.currentRealtimeThrottlingRetryIntervalSeconds = userDefaultsSampleTimestamp - 1.0
    manager2.currentRealtimeThrottlingRetryIntervalSeconds = userDefaultsSampleTimestamp - 2.0
    XCTAssertEqual(
      manager1.currentRealtimeThrottlingRetryIntervalSeconds,
      userDefaultsSampleTimestamp - 1.0
    )
    XCTAssertEqual(
      manager2.currentRealtimeThrottlingRetryIntervalSeconds,
      userDefaultsSampleTimestamp - 2.0
    )

    manager1.realtimeRetryCount = 1
    manager2.realtimeRetryCount = 2
    XCTAssertEqual(manager1.realtimeRetryCount, 1)
    XCTAssertEqual(manager2.realtimeRetryCount, 2)

    manager1.lastFetchedTemplateVersion = "1"
    manager2.lastFetchedTemplateVersion = "2"
    XCTAssertEqual(manager1.lastFetchedTemplateVersion, "1")
    XCTAssertEqual(manager2.lastFetchedTemplateVersion, "2")

    manager1.lastActiveTemplateVersion = "1"
    manager2.lastActiveTemplateVersion = "2"
    XCTAssertEqual(manager1.lastActiveTemplateVersion, "1")
    XCTAssertEqual(manager2.lastActiveTemplateVersion, "2")
  }

  func testUserDefaultsReset() {
    let manager = UserDefaultsManager(appName: appName,
                                      bundleID: Bundle.main.bundleIdentifier!,
                                      namespace: fqNamespace1)
    manager.lastETag = "testETag"
    manager.resetUserDefaults()
    XCTAssertNil(manager.lastETag)
  }
}
