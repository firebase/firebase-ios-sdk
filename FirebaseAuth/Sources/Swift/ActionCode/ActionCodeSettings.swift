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

import FirebaseCoreInternal
import Foundation

// TODO(Swift 6 Breaking): Consider breaking up into a checked Sendable Swift
// type and unchecked Sendable ObjC wrapper class.

/// Used to set and retrieve settings related to handling action codes.
@objc(FIRActionCodeSettings) open class ActionCodeSettings: NSObject,
  @unchecked Sendable {
  /// This URL represents the state/Continue URL in the form of a universal link.
  ///
  /// This URL can should be constructed as a universal link that would either directly open
  /// the app where the action code would be handled or continue to the app after the action code
  /// is handled by Firebase.
  @objc(URL) open var url: URL? {
    get { impl.url.value() }
    set { impl.url.withLock { $0 = newValue } }
  }

  /// Indicates whether the action code link will open the app directly or after being
  /// redirected from a Firebase owned web widget.
  @objc open var handleCodeInApp: Bool {
    get { impl.handleCodeInApp.value() }
    set { impl.handleCodeInApp.withLock { $0 = newValue } }
  }

  /// The iOS bundle ID, if available. The default value is the current app's bundle ID.
  @objc open var iOSBundleID: String? {
    get { impl.iOSBundleID.value() }
    set { impl.iOSBundleID.withLock { $0 = newValue } }
  }

  /// The Android package name, if available.
  @objc open var androidPackageName: String? {
    get { impl.androidPackageName.value() }
    set { impl.androidPackageName.withLock { $0 = newValue } }
  }

  /// The minimum Android version supported, if available.
  @objc open var androidMinimumVersion: String? {
    get { impl.androidMinimumVersion.value() }
    set { impl.androidMinimumVersion.withLock { $0 = newValue } }
  }

  /// Indicates whether the Android app should be installed on a device where it is not available.
  @objc open var androidInstallIfNotAvailable: Bool {
    get { impl.androidInstallIfNotAvailable.value() }
    set { impl.androidInstallIfNotAvailable.withLock { $0 = newValue } }
  }

  /// The Firebase Dynamic Link domain used for out of band code flow.
  #if !FIREBASE_CI
    @available(
      *,
      deprecated,
      message: "Firebase Dynamic Links is deprecated. Migrate to use Firebase Hosting link and use `linkDomain` to set a custom domain instead."
    )
  #endif // !FIREBASE_CI
  @objc open var dynamicLinkDomain: String? {
    get { impl.dynamicLinkDomain.value() }
    set { impl.dynamicLinkDomain.withLock { $0 = newValue } }
  }

  /// The out of band custom domain for handling code in app.
  @objc public var linkDomain: String? {
    get { impl.linkDomain.value() }
    set { impl.linkDomain.withLock { $0 = newValue } }
  }

  private let impl: SendableActionCodeSettings

  /// Sets the iOS bundle ID.
  @objc override public init() {
    impl = .init()
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
    impl
      .setAndroidPackageName(
        androidPackageName,
        installIfNotAvailable: installIfNotAvailable,
        minimumVersion: minimumVersion
      )
  }

  /// Sets the iOS bundle ID.
  open func setIOSBundleID(_ bundleID: String) {
    impl.setIOSBundleID(bundleID)
  }
}

private extension ActionCodeSettings {
  /// Checked Sendable implementation of `ActionCodeSettings`.
  final class SendableActionCodeSettings: Sendable {
    let url = FIRAllocatedUnfairLock<URL?>(initialState: nil)

    let handleCodeInApp = FIRAllocatedUnfairLock<Bool>(initialState: false)

    let iOSBundleID: FIRAllocatedUnfairLock<String?>

    let androidPackageName = FIRAllocatedUnfairLock<String?>(initialState: nil)

    let androidMinimumVersion = FIRAllocatedUnfairLock<String?>(initialState: nil)

    let androidInstallIfNotAvailable = FIRAllocatedUnfairLock<Bool>(initialState: false)

    #if !FIREBASE_CI
      @available(
        *,
        deprecated,
        message: "Firebase Dynamic Links is deprecated. Migrate to use Firebase Hosting link and use `linkDomain` to set a custom domain instead."
      )
    #endif // !FIREBASE_CI
    let dynamicLinkDomain = FIRAllocatedUnfairLock<String?>(initialState: nil)

    let linkDomain = FIRAllocatedUnfairLock<String?>(initialState: nil)

    init() {
      iOSBundleID = FIRAllocatedUnfairLock<String?>(initialState: Bundle.main.bundleIdentifier)
    }

    func setAndroidPackageName(_ androidPackageName: String,
                               installIfNotAvailable: Bool,
                               minimumVersion: String?) {
      self.androidPackageName.withLock { $0 = androidPackageName }
      androidInstallIfNotAvailable.withLock { $0 = installIfNotAvailable }
      androidMinimumVersion.withLock { $0 = minimumVersion }
    }

    func setIOSBundleID(_ bundleID: String) {
      iOSBundleID.withLock { $0 = bundleID }
    }
  }
}
