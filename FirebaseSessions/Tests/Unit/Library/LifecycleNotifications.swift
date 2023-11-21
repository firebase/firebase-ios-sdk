//
// Copyright 2022 Google LLC
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

import XCTest

import Dispatch

#if os(iOS) || os(tvOS)
  import UIKit
#elseif os(macOS)
  import AppKit
  import Cocoa
#elseif os(watchOS)
  import WatchKit
#endif // os(iOS) || os(tvOS)

// swift(>=5.9) implies Xcode 15+
// Need to have this Swift version check to use os(visionOS) macro, VisionOS support.
// TODO: Remove this check and add `os(visionOS)` to the `os(iOS) || os(tvOS)` conditional above
// when Xcode 15 is the minimum supported by Firebase.
#if swift(>=5.9)
  #if os(visionOS)
    import UIKit
  #endif // os(visionOS)
#endif // swift(>=5.9)

extension XCTestCase {
  func postBackgroundedNotification() {
    // On Catalyst, the notifications can only be called on a the main thread
    if Thread.isMainThread {
      postBackgroundedNotificationInternal()
    } else {
      DispatchQueue.main.sync {
        self.postBackgroundedNotificationInternal()
      }
    }
  }

  private func postBackgroundedNotificationInternal() {
    let notificationCenter = NotificationCenter.default
    #if os(iOS) || os(tvOS)
      notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    #elseif os(macOS)
      notificationCenter.post(name: NSApplication.didResignActiveNotification, object: nil)
    #elseif os(watchOS)
      if #available(watchOSApplicationExtension 7.0, *) {
        notificationCenter.post(
          name: WKExtension.applicationDidEnterBackgroundNotification,
          object: nil
        )
      }
    #endif // os(iOS) || os(tvOS)

    // swift(>=5.9) implies Xcode 15+
    // Need to have this Swift version check to use os(visionOS) macro, VisionOS support.
    // TODO: Remove this check and add `os(visionOS)` to the `os(iOS) || os(tvOS)` conditional above
    // when Xcode 15 is the minimum supported by Firebase.
    #if swift(>=5.9)
      #if os(visionOS)
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
      #endif // os(visionOS)
    #endif // swift(>=5.9)
  }

  func postForegroundedNotification() {
    // On Catalyst, the notifications can only be called on a the main thread
    if Thread.isMainThread {
      postForegroundedNotificationInternal()
    } else {
      DispatchQueue.main.sync {
        self.postForegroundedNotificationInternal()
      }
    }
  }

  private func postForegroundedNotificationInternal() {
    let notificationCenter = NotificationCenter.default
    #if os(iOS) || os(tvOS)
      notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    #elseif os(macOS)
      notificationCenter.post(name: NSApplication.didBecomeActiveNotification, object: nil)
    #elseif os(watchOS)
      if #available(watchOSApplicationExtension 7.0, *) {
        notificationCenter.post(
          name: WKExtension.applicationDidBecomeActiveNotification,
          object: nil
        )
      }
    #endif // os(iOS) || os(tvOS)

    // swift(>=5.9) implies Xcode 15+
    // Need to have this Swift version check to use os(visionOS) macro, VisionOS support.
    // TODO: Remove this check and add `os(visionOS)` to the `os(iOS) || os(tvOS)` conditional above
    // when Xcode 15 is the minimum supported by Firebase.
    #if swift(>=5.9)
      #if os(visionOS)
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
      #endif // os(visionOS)
    #endif // swift(>=5.9)
  }
}
