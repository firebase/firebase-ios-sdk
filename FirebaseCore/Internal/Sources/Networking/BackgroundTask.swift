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

import Foundation

/// The `UIApplication` methods that `FirebaseHTTPClient` uses to finish requests after the app
/// moves to the background.
protocol BackgroundTaskApplication: Sendable {
  /// Returns the task identifier, or `invalidBackgroundTaskIdentifier` if the system didn't grant
  /// a task.
  func beginBackgroundTask(withName name: String,
                           expirationHandler: @escaping @Sendable () -> Void) -> Int

  func endBackgroundTask(_ identifier: Int)
}

/// The value of `UIBackgroundTaskIdentifier.invalid`.
let invalidBackgroundTaskIdentifier = 0

/// Holds a background task until `end()` is called or the system expires the task.
final class BackgroundTaskAssertion: Sendable {
  private let application: any BackgroundTaskApplication
  private let identifier = UnfairLock(invalidBackgroundTaskIdentifier)

  init(application: any BackgroundTaskApplication, name: String) {
    self.application = application
    let identifier = application.beginBackgroundTask(withName: name) { [weak self] in
      // The system calls this on the main thread when the app's background time is about to run
      // out. Ending the task keeps the system from terminating the app. The request continues.
      self?.end()
    }
    self.identifier.withLock { $0 = identifier }
  }

  /// Ends the task. Later calls do nothing.
  func end() {
    let identifier = self.identifier.withLock { identifier -> Int in
      defer { identifier = invalidBackgroundTaskIdentifier }
      return identifier
    }
    if identifier != invalidBackgroundTaskIdentifier {
      application.endBackgroundTask(identifier)
    }
  }
}

enum SystemBackgroundTaskApplication {
  /// Returns the app's `UIApplication`, or `nil` on platforms without background tasks, in app
  /// extensions, and before the app has a `UIApplication`.
  ///
  /// Background tasks apply on iOS, tvOS, and Mac Catalyst.
  static func current() -> (any BackgroundTaskApplication)? {
    #if os(iOS) || os(tvOS)
      return UIKitBackgroundTaskApplication.current()
    #else
      return nil
    #endif
  }
}

#if os(iOS) || os(tvOS)
  /// Calls `UIApplication` through the Objective-C runtime. FirebaseCoreInternal doesn't link
  /// UIKit, and app extensions must not use `UIApplication.shared`.
  private final class UIKitBackgroundTaskApplication: BackgroundTaskApplication,
    @unchecked Sendable {
    private static let isAppExtension = Bundle.main.bundlePath.hasSuffix(".appex")

    /// `UIApplication.shared`. The background task methods can be called from any thread.
    private let application: AnyObject

    private init(application: AnyObject) {
      self.application = application
    }

    static func current() -> UIKitBackgroundTaskApplication? {
      guard !isAppExtension, let applicationClass = NSClassFromString("UIApplication") else {
        return nil
      }
      let classObject = applicationClass as AnyObject
      let sharedApplication = NSSelectorFromString("sharedApplication")
      guard classObject.responds(to: sharedApplication),
            let application = classObject.perform(sharedApplication)?.takeUnretainedValue() else {
        return nil
      }
      return UIKitBackgroundTaskApplication(application: application)
    }

    func beginBackgroundTask(withName name: String,
                             expirationHandler: @escaping @Sendable () -> Void) -> Int {
      application.beginBackgroundTask?(withName: name, expirationHandler: expirationHandler)
        ?? invalidBackgroundTaskIdentifier
    }

    func endBackgroundTask(_ identifier: Int) {
      application.endBackgroundTask?(identifier)
    }
  }

  /// Declares the `UIApplication` selectors for calls through `AnyObject`.
  @objc private protocol UIApplicationBackgroundTasks {
    @objc(beginBackgroundTaskWithName:expirationHandler:)
    func beginBackgroundTask(withName taskName: String?,
                             expirationHandler handler: (() -> Void)?) -> Int

    @objc(endBackgroundTask:)
    func endBackgroundTask(_ identifier: Int)
  }
#endif
