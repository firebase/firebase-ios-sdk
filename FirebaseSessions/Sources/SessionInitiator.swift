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

import Foundation
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

///
/// The SessionInitiator is responsible for:
///   1) Running the initiate callback whenever a Session Start Event should
///      begin sending. This can happen at a cold start of the app, and when it
///      been in the background for a period of time (originally set at 30 mins)
///      and comes to the foreground.
///
class SessionInitiator {
  let currentTime: () -> Date
  var settings: SettingsProtocol
  var backgroundTime = Date.distantFuture
  var initiateSessionStart: () -> Void = {}

  init(settings: SettingsProtocol, currentTimeProvider: @escaping () -> Date = Date.init) {
    currentTime = currentTimeProvider
    self.settings = settings
  }

  func beginListening(initiateSessionStart: @escaping () -> Void) {
    self.initiateSessionStart = initiateSessionStart
    self.initiateSessionStart()

    let notificationCenter = NotificationCenter.default
    #if os(iOS) || os(tvOS)
      notificationCenter.addObserver(
        self,
        selector: #selector(appBackgrounded),
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
      )
      notificationCenter.addObserver(
        self,
        selector: #selector(appForegrounded),
        name: UIApplication.didBecomeActiveNotification,
        object: nil
      )
    #elseif os(macOS)
      notificationCenter.addObserver(
        self,
        selector: #selector(appBackgrounded),
        name: NSApplication.didResignActiveNotification,
        object: nil
      )
      notificationCenter.addObserver(
        self,
        selector: #selector(appForegrounded),
        name: NSApplication.didBecomeActiveNotification,
        object: nil
      )
    #elseif os(watchOS)
      // Versions below WatchOS 7 do not support lifecycle events
      if #available(watchOSApplicationExtension 7.0, *) {
        notificationCenter.addObserver(
          self,
          selector: #selector(appBackgrounded),
          name: WKExtension.applicationDidEnterBackgroundNotification,
          object: nil
        )
        notificationCenter.addObserver(
          self,
          selector: #selector(appForegrounded),
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
        notificationCenter.addObserver(
          self,
          selector: #selector(appBackgrounded),
          name: UIApplication.didEnterBackgroundNotification,
          object: nil
        )
        notificationCenter.addObserver(
          self,
          selector: #selector(appForegrounded),
          name: UIApplication.didBecomeActiveNotification,
          object: nil
        )
      #endif // os(visionOS)
    #endif // swift(>=5.9)
  }

  @objc private func appBackgrounded() {
    backgroundTime = currentTime()
  }

  @objc private func appForegrounded() {
    let interval = currentTime().timeIntervalSince(backgroundTime)

    // If the interval is greater the the session timeout duration, generate a new session.
    if interval > settings.sessionTimeout {
      initiateSessionStart()
    }
  }
}
