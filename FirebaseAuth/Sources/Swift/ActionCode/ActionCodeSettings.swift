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

/// Used to set and retrieve settings related to handling action codes.
@objc(FIRActionCodeSettings) open class ActionCodeSettings: NSObject {
  /// This URL represents the state/Continue URL in the form of a universal link.
  ///
  /// This URL can should be constructed as a universal link that would either directly open
  /// the app where the action code would be handled or continue to the app after the action code
  /// is handled by Firebase.
  @objc(URL) open var url: URL?

  /// Indicates whether the action code link will open the app directly or after being
  /// redirected from a Firebase owned web widget.
  @objc open var handleCodeInApp: Bool = false

  /// The iOS bundle ID, if available. The default value is the current app's bundle ID.
  @objc open var iOSBundleID: String?

  /// The Android package name, if available.
  @objc open var androidPackageName: String?

  /// The minimum Android version supported, if available.
  @objc open var androidMinimumVersion: String?

  /// Indicates whether the Android app should be installed on a device where it is not available.
  @objc open var androidInstallIfNotAvailable: Bool = false

  /// The Firebase Dynamic Link domain used for out of band code flow.
  @objc open var dynamicLinkDomain: String?

  /// Sets the iOS bundle ID.
  @objc override public init() {
    iOSBundleID = Bundle.main.bundleIdentifier
  }

  /// Sets the Android package name, the flag to indicate whether or not to install the app,
  /// and the minimum Android version supported.
  ///
  /// If `installIfNotAvailable` is set to `true` and the link is opened on an android device, it
  /// will try to install the app if not already available. Otherwise the web URL is used.
  /// - Parameters:
  ///   - androidPackageName: The Android package name.
  ///   - installIfNotAvailable: Indicates whether or not the app should be installed if not
  /// available.
  ///   - minimumVersion: The minimum version of Android supported.
  @objc open func setAndroidPackageName(_ androidPackageName: String,
                                        installIfNotAvailable: Bool,
                                        minimumVersion: String?) {
    self.androidPackageName = androidPackageName
    androidInstallIfNotAvailable = installIfNotAvailable
    androidMinimumVersion = minimumVersion
  }

  /// Sets the iOS bundle ID.
  open func setIOSBundleID(_ bundleID: String) {
    iOSBundleID = bundleID
  }
}
