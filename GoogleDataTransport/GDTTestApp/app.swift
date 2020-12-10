/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import GoogleDataTransport

// iOS and tvOS specifics.
#if os(iOS) || os(tvOS)
  import UIKit

  @UIApplicationMain
  class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication
                       .LaunchOptionsKey: Any]?) -> Bool {
      GDTCORConsoleLoggerLoggingLevel = GDTCORLoggingLevel.debug.rawValue
      return true
    }
  }

  public class ViewController: UIViewController {
    let transport: GDTCORTransport = GDTCORTransport(mappingID: "1234", transformers: nil,
                                                     target: GDTCORTarget.test)!
    @IBOutlet var statusLabel: UILabel!
  }

// macOS specifics.
#elseif os(macOS)
  import Cocoa

  @NSApplicationMain class Main: NSObject, NSApplicationDelegate {
    var windowController: NSWindowController!

    func applicationDidFinishLaunching(aNotification: NSNotification) {}
  }

  public class ViewController: NSViewController {
    let transport: GDTCORTransport = GDTCORTransport(mappingID: "1234", transformers: nil,
                                                     target: GDTCORTarget.test)!
  }
#endif
