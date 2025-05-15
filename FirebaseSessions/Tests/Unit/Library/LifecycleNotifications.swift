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

#if os(iOS) || os(tvOS) || os(visionOS)
  import UIKit
#elseif os(macOS)
  import AppKit
  import Cocoa
#elseif os(watchOS)
  import WatchKit
#endif // os(iOS) || os(tvOS)

@MainActor func postBackgroundedNotification() {
  // On Catalyst, the notifications can only be called on the main thread
  let notificationCenter = NotificationCenter.default
  #if os(iOS) || os(tvOS) || os(visionOS)
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
}

@MainActor func postForegroundedNotification() {
  // On Catalyst, the notifications can only be called on a the main thread
  let notificationCenter = NotificationCenter.default
  #if os(iOS) || os(tvOS) || os(visionOS)
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
}
