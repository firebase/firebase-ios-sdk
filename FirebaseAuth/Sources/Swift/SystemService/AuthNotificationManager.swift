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

#if !os(macOS) && !os(watchOS)
  import Foundation
  import UIKit

  /// A class represents a credential that proves the identity of the app.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @preconcurrency
  class AuthNotificationManager {
    /// The key to locate payload data in the remote notification.
    private let kNotificationDataKey = "com.google.firebase.auth"

    /// The key for the receipt in the remote notification payload data.
    private let kNotificationReceiptKey = "receipt"

    /// The key for the secret in the remote notification payload data.
    private let kNotificationSecretKey = "secret"

    /// The key for marking the prober in the remote notification payload data.
    private let kNotificationProberKey = "warning"

    /// Timeout for probing whether the app delegate forwards the remote notification to us.
    private let kProbingTimeout = 1.0

    /// The application.
    private let application: UIApplication

    /// The object to handle app credentials delivered via notification.
    private let appCredentialManager: AuthAppCredentialManager

    /// Whether notification forwarding has been checked or not.
    private var hasCheckedNotificationForwarding: Bool = false

    /// Whether or not notification is being forwarded
    private var isNotificationBeingForwarded: Bool = false

    /// The timeout for checking for notification forwarding.
    ///
    /// Only tests should access this property.
    let timeout: TimeInterval

    /// Disable callback waiting for tests.
    ///
    /// Only tests should access this property.
    var immediateCallbackForTestFaking: (() -> Bool)?

    private let condition: AuthCondition

    /// Initializes the instance.
    /// - Parameter application: The application.
    /// - Parameter appCredentialManager: The object to handle app credentials delivered via
    /// notification.
    /// - Returns: The initialized instance.
    init(withApplication application: UIApplication,
         appCredentialManager: AuthAppCredentialManager) {
      self.application = application
      self.appCredentialManager = appCredentialManager
      timeout = kProbingTimeout
      condition = AuthCondition()
    }

    private actor PendingCount {
      private var count = 0
      func increment() -> Int {
        count = count + 1
        return count
      }
    }

    private let pendingCount = PendingCount()

    /// Checks whether or not remote notifications are being forwarded to this class.
    func checkNotificationForwarding() async -> Bool {
      if let getValueFunc = immediateCallbackForTestFaking {
        return getValueFunc()
      }
      if hasCheckedNotificationForwarding {
        return isNotificationBeingForwarded
      }
      if await pendingCount.increment() == 1 {
        DispatchQueue.main.async {
          let proberNotification = [self.kNotificationDataKey: [self.kNotificationProberKey:
              "This fake notification should be forwarded to Firebase Auth."]]
          if let delegate = self.application.delegate,
             delegate
             .responds(to: #selector(UIApplicationDelegate
                 .application(_:didReceiveRemoteNotification:fetchCompletionHandler:))) {
            delegate.application?(self.application,
                                  didReceiveRemoteNotification: proberNotification) { _ in
            }
          } else {
            AuthLog.logWarning(
              code: "I-AUT000015",
              message: "The UIApplicationDelegate must handle " +
                "remote notification for phone number authentication to work."
            )
          }
          kAuthGlobalWorkQueue.asyncAfter(deadline: .now() + .seconds(Int(self.timeout))) {
            self.condition.signal()
          }
        }
      }
      await condition.wait()
      hasCheckedNotificationForwarding = true
      return isNotificationBeingForwarded
    }

    /// Attempts to handle the remote notification.
    /// - Parameter notification: The notification in question.
    /// - Returns: Whether or the notification has been handled.
    func canHandle(notification: [AnyHashable: Any]) -> Bool {
      var stringDictionary: [String: Any]?
      let data = notification[kNotificationDataKey]
      if let jsonString = data as? String {
        // Deserialize in case the data is a JSON string.
        guard let jsonData = jsonString.data(using: .utf8),
              let dictionary = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
          return false
        }
        stringDictionary = dictionary
      }
      guard let dictionary = stringDictionary ?? data as? [String: Any] else {
        return false
      }
      if dictionary[kNotificationProberKey] != nil {
        if hasCheckedNotificationForwarding {
          // The prober notification probably comes from another instance, so pass it along.
          return false
        }
        isNotificationBeingForwarded = true
        condition.signal()
        return true
      }
      guard let receipt = dictionary[kNotificationReceiptKey] as? String,
            let secret = dictionary[kNotificationSecretKey] as? String else {
        return false
      }
      return appCredentialManager.canFinishVerification(withReceipt: receipt, secret: secret)
    }
  }
#endif
