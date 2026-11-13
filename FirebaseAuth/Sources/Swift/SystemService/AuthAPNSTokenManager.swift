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

  #if COCOAPODS
    internal import GoogleUtilities
  #else
    internal import GoogleUtilities_Environment
  #endif // COCOAPODS

  // Protocol to help with unit tests.
  protocol AuthAPNSTokenApplication {
    @MainActor func registerForRemoteNotifications()
  }

  extension UIApplication: AuthAPNSTokenApplication {}

  /// A class to manage APNs token in memory.
  class AuthAPNSTokenManager: @unchecked Sendable /* TODO: sendable */ {
    /// The timeout for registering for remote notification.
    ///
    /// Only tests should access this property.
    let timeout: TimeInterval

    /// Initializes the instance.
    /// - Parameter application: The  `UIApplication` to request the token from.
    /// - Returns: The initialized instance.
    init(withApplication application: sending AuthAPNSTokenApplication, timeout: TimeInterval = 5) {
      self.application = application
      self.timeout = timeout
    }

    /// Attempts to get the APNs token.
    /// - Parameter callback: The block to be called either immediately or in future, either when a
    /// token becomes available, or when timeout occurs, whichever happens earlier.
    ///
    /// This function is internal to make visible for tests.
    func getTokenInternal(callback: @escaping @Sendable (Result<AuthAPNSToken, Error>) -> Void) {
      enum Action {
        case invokeImmediately(AuthAPNSToken)
        case appendOnly
        case startRegistration(Int)
      }
      let action: Action = lock.withLock {
        if let token = _tokenStore {
          return .invokeImmediately(token)
        }
        if !pendingCallbacks.isEmpty {
          pendingCallbacks.append(callback)
          return .appendOnly
        }
        pendingRequestGeneration += 1
        pendingCallbacks = [callback]
        return .startRegistration(pendingRequestGeneration)
      }

      switch action {
      case let .invokeImmediately(token):
        callback(.success(token))
      case .appendOnly:
        return
      case let .startRegistration(requestGeneration):
        DispatchQueue.main.async {
          self.application.registerForRemoteNotifications()
        }
        let deadline = DispatchTime.now() + timeout
        // Capture `self` strongly. The pending callbacks live in this manager, so if it were
        // released before the deadline, they would never be called.
        kAuthGlobalWorkQueue.asyncAfter(deadline: deadline) {
          // Only cancel if this is still the active request and it has not completed.
          let callbacksToCancel: [(Result<AuthAPNSToken, Error>) -> Void] = self.lock.withLock {
            guard requestGeneration == self.pendingRequestGeneration,
                  !self.pendingCallbacks.isEmpty else { return [] }
            let callbacks = self.pendingCallbacks
            self.pendingCallbacks = []
            return callbacks
          }
          guard !callbacksToCancel.isEmpty else { return }
          let error = AuthErrorUtils.missingAppTokenError(underlyingError: nil)
          for callback in callbacksToCancel {
            callback(.failure(error))
          }
        }
      }
    }

    func getToken() async throws -> AuthAPNSToken {
      return try await withUnsafeThrowingContinuation { continuation in
        self.getTokenInternal { result in
          switch result {
          case let .success(token):
            continuation.resume(returning: token)
          case let .failure(error):
            continuation.resume(throwing: error)
          }
        }
      }
    }

    /// The APNs token, if one is available.
    ///
    /// Setting a token with AuthAPNSTokenTypeUnknown will automatically converts it to
    /// a token with the automatically detected type.
    var token: AuthAPNSToken? {
      get {
        lock.withLock { _tokenStore }
      }
      set(setToken) {
        guard let setToken else {
          lock.withLock { _tokenStore = nil }
          return
        }
        var newToken = setToken
        if setToken.type == AuthAPNSTokenType.unknown {
          let detectedTokenType = isProductionApp() ? AuthAPNSTokenType.prod : AuthAPNSTokenType
            .sandbox
          newToken = AuthAPNSToken(withData: setToken.data, type: detectedTokenType)
        }
        let callbacksToInvoke: [(Result<AuthAPNSToken, Error>) -> Void] = lock.withLock {
          _tokenStore = newToken
          let callbacks = pendingCallbacks
          pendingCallbacks = []
          return callbacks
        }
        for callback in callbacksToInvoke {
          callback(.success(newToken))
        }
      }
    }

    /// Should only be written to in tests
    var tokenStore: AuthAPNSToken? {
      get { lock.withLock { _tokenStore } }
      set { lock.withLock { _tokenStore = newValue } }
    }

    /// Cancels any pending `getTokenWithCallback:` request.
    /// - Parameter error: The error to return .
    func cancel(withError error: Error) {
      callback(.failure(error))
    }

    /// Enable unit test faking.
    var application: AuthAPNSTokenApplication
    private let lock = NSLock()
    private var _tokenStore: AuthAPNSToken?
    private var pendingCallbacks: [(Result<AuthAPNSToken, Error>) -> Void] = []
    private var pendingRequestGeneration = 0

    private func callback(_ result: Result<AuthAPNSToken, Error>) {
      let pendingCallbacks: [(Result<AuthAPNSToken, Error>) -> Void] = lock.withLock {
        let callbacks = self.pendingCallbacks
        self.pendingCallbacks = []
        return callbacks
      }
      for callback in pendingCallbacks {
        callback(result)
      }
    }

    private func isProductionApp() -> Bool {
      let defaultAppTypeProd = true
      if GULAppEnvironmentUtil.isSimulator() {
        AuthLog.logInfo(code: "I-AUT000006", message: "Assuming prod APNs token type on simulator.")
        return defaultAppTypeProd
      }
      // Apps distributed via AppStore or TestFlight use the Production APNS certificates.
      if GULAppEnvironmentUtil.isFromAppStore() {
        return defaultAppTypeProd
      }

      // TODO: resolve https://github.com/firebase/firebase-ios-sdk/issues/10921
      // to support TestFlight

      let path = Bundle.main.bundlePath + "/" + "embedded.mobileprovision"
      do {
        let profileData = try NSData(contentsOfFile: path) as Data

        // The "embedded.mobileprovision" sometimes contains characters with value 0, which signals
        // the end of a c-string and halts the ASCII parser, or with value > 127, which violates
        // strict 7-bit ASCII. Replace any 0s or invalid characters in the input.
        let byteArray = [UInt8](profileData)
        var outBytes: [UInt8] = []
        for byte in byteArray {
          if byte == 0 || byte > 127 {
            outBytes.append(46) // ASCII '.'
          } else {
            outBytes.append(byte)
          }
        }
        guard let embeddedProfile = String(bytes: outBytes, encoding: .utf8) else {
          AuthLog.logInfo(code: "I-AUT000008",
                          message: "Error while reading embedded mobileprovision. " +
                            "Failed to convert to String")
          return defaultAppTypeProd
        }

        let scanner = Scanner(string: embeddedProfile)
        if scanner.scanUpToString("<plist") != nil {
          guard let plistContents = scanner.scanUpToString("</plist>")?.appending("</plist>"),
                let data = plistContents.data(using: .utf8) else {
            return defaultAppTypeProd
          }

          do {
            let plistData = try PropertyListSerialization.propertyList(from: data, format: nil)
            guard let plistMap = plistData as? [String: Any] else {
              AuthLog.logInfo(code: "I-AUT000008",
                              message: "Error while converting assumed plist to dictionary.")
              return defaultAppTypeProd
            }
            if plistMap["ProvisionedDevices"] != nil {
              AuthLog.logInfo(code: "I-AUT000011",
                              message: "Provisioning profile has specifically provisioned devices, " +
                                "most likely a Dev profile.")
            }
            guard let entitlements = plistMap["Entitlements"] as? [String: Any],
                  let apsEnvironment = entitlements["aps-environment"] as? String else {
              AuthLog.logInfo(code: "I-AUT000013",
                              message: "No aps-environment set. If testing on a device APNS is not " +
                                "correctly configured. Please recheck your provisioning profiles.")
              return defaultAppTypeProd
            }
            AuthLog.logDebug(code: "I-AUT000012",
                             message: "APNS Environment in profile: \(apsEnvironment)")

            if apsEnvironment == "development" {
              return false
            }

          } catch {
            AuthLog.logInfo(code: "I-AUT000008",
                            message: "Error while converting assumed plist to dict " +
                              "\(error.localizedDescription)")
          }
        }
      } catch {
        AuthLog.logInfo(code: "I-AUT000008",
                        message: "Error while reading embedded mobileprovision \(error)")
      }
      return defaultAppTypeProd
    }
  }
#endif
