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
#if os(OSX)
  import Cocoa
  import AppKit
#elseif os(watchOS)
  import WatchKit
#endif

///
/// The SessionInitiator is responsible for:
///   1) Running the initiate callback whenever a Session Start Event should
///      begin sending. This can happen at a cold start of the app, and when it
///      been in the background for a period of time (originally set at 30 mins)
///      and comes to the foreground.
///
class SessionInitiator {
  let sessionTimeout: TimeInterval = 30 * 60 // 30 minutes
  let getDate: () -> Date
  var backgroundTime = Date.distantFuture
  var initiateSessionStart: () -> Void = {}

  init(getDate: @escaping () -> Date = Date.init) {
    self.getDate = getDate
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
    #elseif os(OSX)
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
    #endif
  }

  @objc func appBackgrounded() {
    backgroundTime = getDate()
  }

  @objc func appForegrounded() {
    let interval = getDate().timeIntervalSince(backgroundTime)
    if interval > sessionTimeout {
      initiateSessionStart()
    }
  }
}
