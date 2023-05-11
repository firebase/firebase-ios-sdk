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

 // @_implementationOnly import FirebaseCoreExtension

  #if SWIFT_PACKAGE
    @_implementationOnly import GoogleUtilities_Environment
  #else
    @_implementationOnly import GoogleUtilities
  #endif // SWIFT_PACKAGE

  @objc public protocol AuthAPNSTokenApplication {
    func registerForRemoteNotifications()
  }

  extension UIApplication: AuthAPNSTokenApplication {}

  /** @class AuthAPNSToken
      @brief A data structure for an APNs token.
   */
  @objc(FIRAuthAPNSTokenManager) public class AuthAPNSTokenManager: NSObject {
    /** @property timeout
        @brief The timeout for registering for remote notification.
        @remarks Only tests should access this property.
     */
    @objc public var timeout = 5

    /** @fn initWithApplication:
        @brief Initializes the instance.
        @param application The @c UIApplication to request the token from.
        @return The initialized instance.
     */
    @objc public init(withApplication application: UIApplication) {
      self.application = application
    }

    /** @fn getTokenWithCallback:
        @brief Attempts to get the APNs token.
        @param callback The block to be called either immediately or in future, either when a token
            becomes available, or when timeout occurs, whichever happens earlier.
     */
    @objc public func getToken(callback: @escaping (AuthAPNSToken?, Error?) -> Void) {
      if failFastForTesting {
        let error = NSError(domain: "dummy domain", code: AuthErrorCode.missingAppToken.rawValue)
        callback(nil, error)
        return
      }
      if let token = tokenStore {
        callback(token, nil)
        return
      }
      if pendingCallbacks.count > 0 {
        pendingCallbacks.append(callback)
        return
      }
      pendingCallbacks = [callback]

      DispatchQueue.main.async {
        self.application.registerForRemoteNotifications()
      }
      let applicableCallbacks = pendingCallbacks
      let deadline = DispatchTime.now() + .seconds(timeout)
      kAuthGlobalWorkQueue.asyncAfter(deadline: deadline) {
        // Only cancel if the pending callbacks remain the same, i.e., not triggered yet.
        if applicableCallbacks.count == self.pendingCallbacks.count {
          self.callback(withToken: nil, error: nil)
        }
      }
    }

    /** @property token
        @brief The APNs token, if one is available.
        @remarks Setting a token with AuthAPNSTokenTypeUnknown will automatically converts it to
            a token with the automatically detected type.
     */
    @objc public var token: AuthAPNSToken? {
      get {
        return tokenStore
      }
      @objc(setToken:)
      set(setToken) {
        guard let setToken else {
          self.tokenStore = nil
          return
        }
        var newToken = setToken
        if setToken.type == AuthAPNSTokenType.unknown {
          let detectedTokenType = isProductionApp() ? AuthAPNSTokenType.prod : AuthAPNSTokenType
            .sandbox
          newToken = AuthAPNSToken(withData: setToken.data, type: detectedTokenType)
        }
        self.tokenStore = newToken
        self.callback(withToken: newToken, error: nil)
      }
    }

    // Should only be written to in tests
    var tokenStore: AuthAPNSToken?

    /** @fn cancelWithError:
        @brief Cancels any pending `getTokenWithCallback:` request.
        @param error The error to return.
     */
    @objc public func cancel(withError error: Error) {
      callback(withToken: nil, error: error)
    }

    var failFastForTesting: Bool = false

    // TODO: remove public.
    // `application` is a var to enable unit test faking.
    public var application: AuthAPNSTokenApplication
    private var pendingCallbacks: [(AuthAPNSToken?, Error?) -> Void] = []

    private func callback(withToken token: AuthAPNSToken?, error: Error?) {
      let pendingCallbacks = self.pendingCallbacks
      self.pendingCallbacks = []
      let i = pendingCallbacks.count
      print("starting callbacks \(i)")
      for callback in pendingCallbacks {
        callback(token, error)
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
      if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
        // Distributed via TestFlight
        return defaultAppTypeProd
      }

      let path = Bundle.main.bundlePath + "embedded.mobileprovision"
      guard let url = URL(string: path) else {
        AuthLog.logInfo(code: "I-AUT000007", message: "\(path) does not exist")
        return defaultAppTypeProd
      }
      do {
        let profileData = try Data(contentsOf: url)

        // The "embedded.mobileprovision" sometimes contains characters with value 0, which signals the
        // end of a c-string and halts the ASCII parser, or with value > 127, which violates strict 7-bit
        // ASCII. Replace any 0s or invalid characters in the input.
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
                          message: "Error while reading embedded mobileprovision. Failed to convert to String")
          return defaultAppTypeProd
        }

        // TODO: This code needs iOS 13. Use split instead?
//        let scanner = Scanner(string: embeddedProfile)
//        if scanner.scanUpToString("<plist") != nil {
//          if let plistContents = scanner.scanUpToString("</plist>")
//        }

      } catch {
        AuthLog.logInfo(code: "I-AUT000008",
                        message: "Error while reading embedded mobileprovision \(error)")
        return defaultAppTypeProd
      }

      // TODO: Finish this port

//      NSMutableData *profileData = [NSMutableData dataWithContentsOfFile:path options:0 error:&error];
//
//      if (!profileData.length || error) {
//        FIRLogInfo(kFIRLoggerAuth, @"I-AUT000007", @"Error while reading embedded mobileprovision %@",
//                   error);
//        return defaultAppTypeProd;
//      }

//      NSScanner *scanner = [NSScanner scannerWithString:embeddedProfile];
//      NSString *plistContents;
//      if ([scanner scanUpToString:@"<plist" intoString:nil]) {
//        if ([scanner scanUpToString:@"</plist>" intoString:&plistContents]) {
      // TODO: how does a file name get read with this append?
//          plistContents = [plistContents stringByAppendingString:@"</plist>"];
//        }
//      }
//
//      if (!plistContents.length) {
//        return defaultAppTypeProd;
//      }
//
//      NSData *data = [plistContents dataUsingEncoding:NSUTF8StringEncoding];
//      if (!data.length) {
//        FIRLogInfo(kFIRLoggerAuth, @"I-AUT000009",
//                   @"Couldn't read plist fetched from embedded mobileprovision");
//        return defaultAppTypeProd;
//      }
//
//      NSError *plistMapError;
//      id plistData = [NSPropertyListSerialization propertyListWithData:data
//                                                               options:NSPropertyListImmutable
//                                                                format:nil
//                                                                 error:&plistMapError];
//      if (plistMapError || ![plistData isKindOfClass:[NSDictionary class]]) {
//        FIRLogInfo(kFIRLoggerAuth, @"I-AUT000010", @"Error while converting assumed plist to dict %@",
//                   plistMapError.localizedDescription);
//        return defaultAppTypeProd;
//      }
//      NSDictionary *plistMap = (NSDictionary *)plistData;
//
//      if ([plistMap valueForKeyPath:@"ProvisionedDevices"]) {
//        FIRLogInfo(kFIRLoggerAuth, @"I-AUT000011",
//                   @"Provisioning profile has specifically provisioned devices, "
//                   @"most likely a Dev profile.");
//      }
//
//      NSString *apsEnvironment = [plistMap valueForKeyPath:@"Entitlements.aps-environment"];
//      FIRLogDebug(kFIRLoggerAuth, @"I-AUT000012", @"APNS Environment in profile: %@", apsEnvironment);
//
//      // No aps-environment in the profile.
//      if (!apsEnvironment.length) {
//        FIRLogInfo(kFIRLoggerAuth, @"I-AUT000013",
//                   @"No aps-environment set. If testing on a device APNS is not "
//                   @"correctly configured. Please recheck your provisioning profiles.");
//        return defaultAppTypeProd;
//      }
//
//      if ([apsEnvironment isEqualToString:@"development"]) {
//        return NO;
//      }

      return defaultAppTypeProd
    }
  }
#endif
