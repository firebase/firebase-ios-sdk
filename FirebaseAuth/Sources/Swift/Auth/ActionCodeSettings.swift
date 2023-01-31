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

import Foundation

// When building for CocoaPods, non-public headers are exposed to Swift via a
// private module map.
#if COCOAPODS
  @_implementationOnly import FirebaseAuth_Private
#endif // COCOAPODS

/** @class FIRActionCodeSettings
    @brief Used to set and retrieve settings related to handling action codes.
 */
@objc(FIRActionCodeSettings) public class ActionCodeSettings: NSObject {
  /** @property URL
      @brief This URL represents the state/Continue URL in the form of a universal link.
      @remarks This URL can should be constructed as a universal link that would either directly open
          the app where the action code would be handled or continue to the app after the action code
          is handled by Firebase.
   */
  @objc public var URL: URL?

  /** @property handleCodeInApp
      @brief Indicates whether the action code link will open the app directly or after being
          redirected from a Firebase owned web widget.
   */
  @objc public var handleCodeInApp: Bool = false

  /** @property iOSBundleID
      @brief The iOS bundle ID, if available. The default value is the current app's bundle ID.
   */
  @objc public var iOSBundleID: String?

  /** @property androidPackageName
      @brief The Android package name, if available.
   */
  @objc public var androidPackageName: String?

  /** @property androidMinimumVersion
      @brief The minimum Android version supported, if available.
   */
  @objc public var androidMinimumVersion: String?

  /** @property androidInstallIfNotAvailable
      @brief Indicates whether the Android app should be installed on a device where it is not
         available.
   */
  @objc public var androidInstallIfNotAvailable: Bool = false

  /** @property dynamicLinkDomain
      @brief The Firebase Dynamic Link domain used for out of band code flow.
   */
  @objc public var dynamicLinkDomain: String?

  /** @fn
      @brief Sets the iOS bundle Id.
   */

  @objc override public init() {
    iOSBundleID = Bundle.main.bundleIdentifier
  }

  /** @fn
      @brief Sets the Android package name, the flag to indicate whether or not to install the app
          and the minimum Android version supported.
      @param androidPackageName The Android package name.
      @param installIfNotAvailable Indicates whether or not the app should be installed if not
          available.
      @param minimumVersion The minimum version of Android supported.
      @remarks If installIfNotAvailable is set to YES and the link is opened on an android device, it
          will try to install the app if not already available. Otherwise the web URL is used.
   */
  @objc public func setAndroidPackageName(_ androidPackageName: String,
                                          installIfNotAvailable: Bool,
                                          minimumVersion: String?) {
    _ = MyPrivateClass()
    self.androidPackageName = androidPackageName
    androidInstallIfNotAvailable = installIfNotAvailable
    androidMinimumVersion = minimumVersion
  }
}
