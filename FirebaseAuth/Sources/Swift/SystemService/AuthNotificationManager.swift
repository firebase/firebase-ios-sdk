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

  /** @class FIRAuthAppCredential
      @brief A class represents a credential that proves the identity of the app.
   */
  @objc(FIRAuthNotificationManager) public class AuthNotificationManager: NSObject {
    /** @var kNotificationKey
        @brief The key to locate payload data in the remote notification.
     */
    private let kNotificationDataKey = "com.google.firebase.auth"

    /** @var kNotificationReceiptKey
        @brief The key for the receipt in the remote notification payload data.
     */
    private let kNotificationReceiptKey = "receipt"

    /** @var kNotificationSecretKey
        @brief The key for the secret in the remote notification payload data.
     */
    private let kNotificationSecretKey = "secret"

    /** @var kNotificationProberKey
        @brief The key for marking the prober in the remote notification payload data.
     */
    private let kNotificationProberKey = "warning"

    /** @var kProbingTimeout
        @brief Timeout for probing whether the app delegate forwards the remote notification to us.
     */
    private let kProbingTimeout = 1.0

    /** @var _application
        @brief The application.
     */
    private let application: Application

    /** @var _appCredentialManager
        @brief The object to handle app credentials delivered via notification.
     */
    private let appCredentialManager: AuthAppCredentialManager

    /** @var _hasCheckedNotificationForwarding
        @brief Whether notification forwarding has been checked or not.
     */
    private var hasCheckedNotificationForwarding: Bool = false

    /** @var _isNotificationBeingForwarded
        @brief Whether or not notification is being forwarded
     */
    private var isNotificationBeingForwarded: Bool = false

    /** @property timeout
        @brief The timeout for checking for notification forwarding.
        @remarks Only tests should access this property.
     */
    @objc public let timeout: TimeInterval

    /** @property immediateCallbackForTestFaking
        @brief Disable callback waiting for tests.
        @remarks Only tests should access this property.
     */
    var immediateCallbackForTestFaking = false

    /** @var _pendingCallbacks
        @brief All pending callbacks while a check is being performed.
     */
    private var pendingCallbacks: [(Bool) -> Void]?

    /** @fn initWithApplication:appCredentialManager:
        @brief Initializes the instance.
        @param application The application.
        @param appCredentialManager The object to handle app credentials delivered via notification.
        @return The initialized instance.
     */
    @objc public init(withApplication application: Application,
                      appCredentialManager: AuthAppCredentialManager) {
      self.application = application
      self.appCredentialManager = appCredentialManager
      timeout = kProbingTimeout
    }

    /** @fn checkNotificationForwardingWithCallback:
        @brief Checks whether or not remote notifications are being forwarded to this class.
        @param callback The block to be called either immediately or in future once a result
            is available.
     */
    @objc public func checkNotificationForwarding(withCallback callback: @escaping (Bool) -> Void) {
      if pendingCallbacks != nil {
        pendingCallbacks?.append(callback)
        return
      }
      if immediateCallbackForTestFaking {
        callback(true)
        return
      }
      if hasCheckedNotificationForwarding {
        callback(isNotificationBeingForwarded)
        return
      }
      hasCheckedNotificationForwarding = true
      pendingCallbacks = [callback]

      DispatchQueue.main.async {
        let proberNotification = [self.kNotificationDataKey: [self.kNotificationProberKey:
            "This fake notification should be forwarded to Firebase Auth."]]
        if let delegate = self.application.delegate {
          delegate.application!(
            UIApplication.shared,
            didReceiveRemoteNotification: proberNotification
          ) { _ in
          }
        } else {
          AuthLog.logWarning(
            code: "I-AUT000015",
            message: "The UIApplicationDelegate must handle " +
              "remote notification for phone number authentication to work."
          )
        }
        kAuthGlobalWorkQueue.asyncAfter(deadline: .now() + .seconds(Int(self.timeout))) {
          self.callback()
        }
      }
    }

    /** @fn canHandleNotification:
        @brief Attempts to handle the remote notification.
        @param notification The notification in question.
        @return Whether or the notification has been handled.
     */
    @objc(canHandleNotification:) public func canHandle(notification: [AnyHashable: Any]) -> Bool {
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
        if pendingCallbacks == nil {
          // The prober notification probably comes from another instance, so pass it along.
          return false
        }
        isNotificationBeingForwarded = true
        callback()
        return true
      }
      guard let receipt = dictionary[kNotificationReceiptKey] as? String,
            let secret = dictionary[kNotificationSecretKey] as? String else {
        return false
      }
      return appCredentialManager.canFinishVerification(withReceipt: receipt, secret: secret)
    }

    // MARK: Internal methods

    private func callback() {
      guard let pendingCallbacks else {
        return
      }
      self.pendingCallbacks = nil
      for callback in pendingCallbacks {
        callback(isNotificationBeingForwarded)
      }
    }
  }

  // Protocol for UIApplication to enable unit testing
  @objc public protocol ApplicationDelegate {
    @objc optional func application(_ application: Application,
                                    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult)
                                      -> Void)
  }

  @objc public protocol Application {
    var delegate: UIApplicationDelegate? { get set }
  }

  extension UIApplication: Application {}
#endif
