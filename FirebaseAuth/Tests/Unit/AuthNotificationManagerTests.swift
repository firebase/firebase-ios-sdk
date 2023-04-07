// Copyright 2023 Google LLC
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

#if os(iOS)
  import Foundation
  import XCTest

  @testable import FirebaseAuth

class AuthNotificationManagerTests: XCTestCase {
  /** @var kReceipt
      @brief A fake receipt used for testing.
   */
  private let kReceipt = "FAKE_RECEIPT"

  /** @var kSecret
      @brief A fake secret used for testing.
   */
  private let kSecret = "FAKE_SECRET"

  /** @property notificationManager
      @brief The notification manager to forward.
   */
  private var notificationManager: AuthNotificationManager?

  /** @var _modernDelegate
      @brief The modern fake UIApplicationDelegate for testing.
   */
  private var modernDelegate: FakeForwardingDelegate?

  override func setUp() {
    let fakeKeychain = FakeAuthKeychainServices()
    let manager = AuthAppCredentialManager(withKeychain: fakeKeychain)
    let application = FakeApplication()
    notificationManager = AuthNotificationManager(withApplication: application,
                                                  appCredentialManager: manager)
    modernDelegate = FakeForwardingDelegate(notificationManager!)
    application.delegate = modernDelegate
  }

  /** @fn testForwardingModernDelegate
      @brief Tests checking notification forwarding on modern fake delegate.
   */
  func testForwardingModernDelegate() throws {
    try self.verify(forwarding: true, delegate: try XCTUnwrap(modernDelegate))
  }

  /** @fn testNotForwardingModernDelegate
      @brief Tests checking notification not forwarding on modern fake delegate.
   */
  func testNotForwardingModernDelegate() throws {
    try self.verify(forwarding: false, delegate: try XCTUnwrap(modernDelegate))
  }

  private func verify(forwarding: Bool, delegate: FakeForwardingDelegate) throws {
    delegate.forwardsNotification = forwarding
    let expectation = self.expectation(description: "callback")
    notificationManager?.checkNotificationForwarding() { forwarded in
      XCTAssertEqual(forwarded, forwarding)
      expectation.fulfill()
    }
    XCTAssertFalse(delegate.notificationReceived)
    let timeout = try XCTUnwrap(notificationManager?.timeout) * (forwarding ? 0.5 : 1.5)
    waitForExpectations(timeout: timeout)
    XCTAssertTrue(delegate.notificationReceived)
    XCTAssertEqual(delegate.notificationHandled, forwarding)
  }

  /** @fn testCachedResult
      @brief Test notification forwarding is only checked once.
   */
  func testNotestCachedResulttForwardingModernDelegate() throws {
    try self.verify(forwarding: false, delegate: try XCTUnwrap(modernDelegate))
    modernDelegate?.notificationReceived = false
  }

  private class FakeApplication: Application {
    var delegate: UIApplicationDelegate?
  }

  private class FakeForwardingDelegate: NSObject, UIApplicationDelegate {
    let notificationManager: AuthNotificationManager
    var forwardsNotification = false
    var notificationReceived = false
    var notificationHandled = false
    init(_ notificationManager: AuthNotificationManager, forwardsNotification: Bool = false,
         notificationReceived: Bool = false, notificationHandled: Bool = false) {
      self.notificationManager = notificationManager
      self.forwardsNotification = forwardsNotification
      self.notificationReceived = notificationReceived
      self.notificationHandled = notificationHandled
    }

    func application(_ application: UIApplication,
      didReceiveRemoteNotification userInfo: [AnyHashable : Any],
      fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        self.notificationReceived = true
        if self.forwardsNotification {
          self.notificationHandled = self.notificationManager.canHandle(notification: userInfo)
        }
      }
  }
}
#endif
