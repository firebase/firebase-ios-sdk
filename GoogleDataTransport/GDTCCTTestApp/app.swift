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
      return true
    }
  }

  public class ViewController: UIViewController {
    let cctTransport: GDTCORTransport = GDTCORTransport(mappingID: "1018", transformers: nil,
                                                        target: GDTCORTarget.CCT)!
    let fllTransport: GDTCORTransport = GDTCORTransport(mappingID: "1018", transformers: nil,
                                                        target: GDTCORTarget.FLL)!
    let cshTransport: GDTCORTransport = GDTCORTransport(mappingID: "1018", transformers: nil,
                                                        target: GDTCORTarget.CSH)!

    @IBOutlet var backendSwitch: UISegmentedControl?

    var transport: GDTCORTransport {
      var theTransport: GDTCORTransport = fllTransport

      if !Thread.current.isMainThread {
        DispatchQueue.main.sync {
          if Globals.IsMonkeyTesting {
            backendSwitch?.selectedSegmentIndex = Int(arc4random_uniform(3))
          }
          switch backendSwitch?.selectedSegmentIndex {
          case 0:
            theTransport = cctTransport

          case 1:
            theTransport = fllTransport

          case 2:
            theTransport = cshTransport

          default:
            theTransport = cctTransport
          }
        }
      } else {
        if Globals.IsMonkeyTesting {
          backendSwitch?.selectedSegmentIndex = Int(arc4random_uniform(3))
        }

        switch backendSwitch?.selectedSegmentIndex {
        case 0:
          theTransport = cctTransport

        case 1:
          theTransport = fllTransport

        case 2:
          theTransport = cshTransport

        default:
          theTransport = cctTransport
        }
      }
      return theTransport
    }
  }

// macOS specifics.
#elseif os(macOS)
  import Cocoa

  @NSApplicationMain class Main: NSObject, NSApplicationDelegate {
    var windowController: NSWindowController!

    func applicationDidFinishLaunching(aNotification: NSNotification) {}
  }

  public class ViewController: NSViewController {
    let cctTransport: GDTCORTransport = GDTCORTransport(mappingID: "1018", transformers: nil,
                                                        target: GDTCORTarget.CCT)!
    let fllTransport: GDTCORTransport = GDTCORTransport(mappingID: "1018", transformers: nil,
                                                        target: GDTCORTarget.FLL)!
    let cshTransport: GDTCORTransport = GDTCORTransport(mappingID: "1018", transformers: nil,
                                                        target: GDTCORTarget.CSH)!

    @IBOutlet var backendSwitch: NSSegmentedControl?

    var transport: GDTCORTransport {
      var theTransport: GDTCORTransport = fllTransport
      if !Thread.current.isMainThread {
        DispatchQueue.main.sync {
          if Globals.IsMonkeyTesting {
            backendSwitch?.selectedSegment = Int(arc4random_uniform(3))
          }
          switch backendSwitch?.selectedSegment {
          case 0:
            theTransport = cctTransport

          case 1:
            theTransport = fllTransport

          case 2:
            theTransport = cshTransport

          default:
            theTransport = cctTransport
          }
        }
      } else {
        if Globals.IsMonkeyTesting {
          backendSwitch?.selectedSegment = Int(arc4random_uniform(3))
        }
        switch backendSwitch?.selectedSegment {
        case 0:
          theTransport = cctTransport

        case 1:
          theTransport = fllTransport

        case 2:
          theTransport = cshTransport

        default:
          theTransport = cctTransport
        }
      }
      return theTransport
    }
  }
#endif
