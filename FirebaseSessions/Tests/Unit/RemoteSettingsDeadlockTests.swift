// Copyright 2026 Google LLC
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

@testable import FirebaseSessions
import XCTest

#if SWIFT_PACKAGE
  internal import GoogleUtilities_Environment
#else
  internal import GoogleUtilities
#endif

// Mocks moved to top level and renamed to avoid collisions
final class DeadlockMockSettingsDownloadClient: SettingsDownloadClient, @unchecked Sendable {
  func fetch(completion: @escaping @Sendable (Result<[String: Any], SettingsDownloaderError>)
    -> Void) {
    // Simulate network delay and callback on background thread
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      completion(.success(["session_timeout_seconds": 20.0]))
    }
  }
}

final class MockDeadlockSettingsCache: SettingsCacheClient, @unchecked Sendable {
  var deadlockDetectedExpectation: XCTestExpectation?

  // Determine behavior
  var shouldBlockMainThread = false
  weak var remoteSettings: RemoteSettings?

  private var _cacheContent: [String: Any] = [:]
  private let lock = NSLock()

  func rootValue<T>(forKey key: String) -> T? {
    return value(forKey: key)
  }

  func namespacedValue<T>(forKey key: String) -> T? {
    return value(forKey: key)
  }

  private func value<T>(forKey key: String) -> T? {
    // Attempt to acquire lock.
    // If background thread holds it (during updateContents), try() will fail.
    // This simulates the deadlock condition without hanging the test runner forever.
    if lock.try() {
      defer { lock.unlock() }
      return _cacheContent[key] as? T
    } else {
      // Lock is held by background thread.
      // We are on Main Thread (triggered by main.sync).
      // This confirms the deadlock cycle.
      print("Deadlock detected. Main thread failed to acquire lock held by background thread.")
      // Fulfill expectation to signal deadlock was successfully reproduced
      deadlockDetectedExpectation?.fulfill()
      return nil
    }
  }

  func updateContents(_ content: [String: Any]) {
    lock.lock()
    defer { lock.unlock() }

    _cacheContent = content

    if shouldBlockMainThread {
      // Attempt to dispatch synchronously to the Main Thread.
      // If the caller holds a lock that the Main Thread is waiting on, this will cause a deadlock.
      DispatchQueue.main.sync {
        // This block will only execute if the Main Thread is free.
        print("Successfully dispatched to Main Thread from background write.")

        // Attempt to access sessionTimeout on Main Thread
        // This calls value(forKey:), which tries to acquire the lock.
        _ = self.remoteSettings?.sessionTimeout
      }
    }
  }

  func updateMetadata(_ metadata: CacheKey) {
    // No-op for test
  }

  func removeCache() {}

  // Always return expired to force a fetch
  func isExpired(for appInfo: ApplicationInfoProtocol, time: Date) -> Bool {
    return true
  }
}

final class DeadlockMockNetworkInfo: NetworkInfoProtocol, @unchecked Sendable {
  var networkType: GULNetworkType = .WIFI
  var mobileSubtype: String = "testMobileSubtype"
}

final class DeadlockMockAppInfo: ApplicationInfoProtocol, @unchecked Sendable {
  var appID: String = "testAppID"
  var sdkVersion: String = "testSDKVersion"
  var osName: String = "testOSName"
  var deviceModel: String = "testDeviceModel"
  var networkInfo: NetworkInfoProtocol = DeadlockMockNetworkInfo()
  var environment: DevEnvironment = .prod
  var appBuildVersion: String = "testAppBuildVersion"
  var appDisplayVersion: String = "testAppDisplayVersion"
  var osBuildVersion: String = "testOSBuildVersion"
  var osDisplayVersion: String = "testOSDisplayVersion"
}

final class RemoteSettingsDeadlockTests: XCTestCase {
  @MainActor
  func testDeadlockScenario() {
    let deadlockDetected = expectation(description: "Deadlock detected (Lock contention confirmed)")

    // Setup Mocks
    let mockDownloader = DeadlockMockSettingsDownloadClient()
    let mockCache = MockDeadlockSettingsCache()
    mockCache.deadlockDetectedExpectation = deadlockDetected
    mockCache.shouldBlockMainThread = true

    let appInfo = DeadlockMockAppInfo()
    let remoteSettings = RemoteSettings(
      appInfo: appInfo,
      downloader: mockDownloader,
      cache: mockCache
    )
    mockCache.remoteSettings = remoteSettings

    // 1. Trigger updateSettings on a background thread (implicitly via downloader callback)
    remoteSettings.updateSettings(currentTime: Date())

    // 2. Wait for the deadlock to be detected
    // If the logic is correct, `value(forKey:)` will be called on Main Thread, fail to acquire
    // lock, and fulfill expectation.
    wait(for: [deadlockDetected], timeout: 5.0)
  }
}
