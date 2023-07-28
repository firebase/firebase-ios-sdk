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

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
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

    /** @var modernDelegate
        @brief The modern fake UIApplicationDelegate for testing.
     */
    private var modernDelegate: FakeForwardingDelegate?

    /** @var appCredentialManager
        @brief A stubbed AppCredentialManager for testing.
     */
    private var appCredentialManager: AuthAppCredentialManager?

    override func setUp() {
      let fakeKeychain = AuthKeychainServices(
        service: "AuthNotificationManagerTests",
        storage: FakeAuthKeychainStorage()
      )
      appCredentialManager = AuthAppCredentialManager(withKeychain: fakeKeychain)
      let application = UIApplication.shared
      notificationManager = AuthNotificationManager(withApplication: application,
                                                    appCredentialManager: appCredentialManager!)
      modernDelegate = FakeForwardingDelegate(notificationManager!)
      application.delegate = modernDelegate
    }

    /** @fn testForwardingModernDelegate
        @brief Tests checking notification forwarding on modern fake delegate.
     */
    func testForwardingModernDelegate() throws {
      try verify(forwarding: true, delegate: XCTUnwrap(modernDelegate))
    }

    /** @fn testNotForwardingModernDelegate
        @brief Tests checking notification not forwarding on modern fake delegate.
     */
    func testNotForwardingModernDelegate() throws {
      try verify(forwarding: false, delegate: XCTUnwrap(modernDelegate))
    }

    private func verify(forwarding: Bool, delegate: FakeForwardingDelegate) throws {
      delegate.forwardsNotification = forwarding
      let expectation = self.expectation(description: "callback")
      notificationManager?.checkNotificationForwardingInternal { forwarded in
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
    func testCachedResult() throws {
      let delegate = try XCTUnwrap(modernDelegate)
      try verify(forwarding: false, delegate: delegate)
      modernDelegate?.notificationReceived = false
      var calledBack = false
      notificationManager?.checkNotificationForwardingInternal { isNotificationBeingForwarded in
        XCTAssertFalse(isNotificationBeingForwarded)
        calledBack = true
      }
      XCTAssertTrue(calledBack)
      XCTAssertFalse(delegate.notificationReceived)
    }

    /** @fn testPassingToCredentialManager
        @brief Test notification with the right structure is passed to credential manager.
     */
    func testPassingToCredentialManager() async throws {
      let payload = ["receipt": kReceipt, "secret": kSecret]
      let notification = ["com.google.firebase.auth": payload]
      // Stub appCredentialManager
      let _ = await appCredentialManager?.didStartVerification(withReceipt: kReceipt, timeout: 0)
      XCTAssertTrue(try XCTUnwrap(notificationManager?.canHandle(notification: notification)))

      // JSON string form
      let data = try JSONSerialization.data(withJSONObject: payload)
      let string = String(data: data, encoding: .utf8)
      let jsonNotification = ["com.google.firebase.auth": string as Any] as [AnyHashable: Any]
      let _ = await appCredentialManager?.didStartVerification(withReceipt: kReceipt, timeout: 0)
      XCTAssertTrue(try XCTUnwrap(notificationManager?.canHandle(notification: jsonNotification)))
    }

    /** @fn testNotHandling
        @brief Test unrecognized notifications are not handled.
     */
    func testNotHandling() throws {
      let manager = try XCTUnwrap(notificationManager)
      XCTAssertFalse(manager.canHandle(notification: ["random": "string"]))
      XCTAssertFalse(manager
        .canHandle(notification: ["com.google.firebase.auth": "something wrong"]))
      // Missing secret.
      XCTAssertFalse(manager
        .canHandle(notification: ["com.google.firebase.auth": ["receipt": kReceipt]]))
      // Missing receipt.
      XCTAssertFalse(manager
        .canHandle(notification: ["com.google.firebase.auth": ["secret": kSecret]]))
      // Probing notification does not belong to this instance.
      XCTAssertFalse(manager
        .canHandle(notification: ["com.google.firebase.auth": ["warning": "asdf"]]))
    }

    private class FakeApplication: UIApplication {}

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
                       didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                       fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult)
                         -> Void) {
        notificationReceived = true
        if forwardsNotification {
          notificationHandled = notificationManager.canHandle(notification: userInfo)
        }
      }
    }
  }
#endif
