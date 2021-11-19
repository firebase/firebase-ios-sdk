// Copyright 2021 Google LLC
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

import FirebaseAuth
import FirebaseCore

import FBSDKCoreKit
import UIKit

@objc protocol OpenURLDelegate: AnyObject {
  func handleOpenURL(_ url: URL, sourceApplication: String) -> Bool
}

@main
public class AppDelegate: UIResponder, UIApplicationDelegate {
  weak static var gOpenURLDelegate: OpenURLDelegate?
  public var window: UIWindow?
  var sampleAppMainViewController: MainViewController?

  @objc class func setOpenURLDelegate(_ openURLDelegate: OpenURLDelegate?) {
    gOpenURLDelegate = openURLDelegate
  }

  public func application(_ application: UIApplication,
                          didFinishLaunchingWithOptions launchOptions: [UIApplication
                            .LaunchOptionsKey: Any]?) -> Bool {
    GTMSessionFetcher.setLoggingEnabled(true)
    FirebaseConfiguration.shared.setLoggerLevel(FirebaseLoggerLevel.info)

    // Configure the default Firebase application.
    FirebaseApp.configure()

    // Configure Facebook Login.
    ApplicationDelegate.shared.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    // Load and present the UI.
    let window = UIWindow(frame: UIScreen.main.bounds)
    sampleAppMainViewController = MainViewController(
      nibName: NSStringFromClass(MainViewController.self),
      bundle: nil
    )
    sampleAppMainViewController?.navigationItem.title = "Firebase Auth"
    window
      .rootViewController = UINavigationController(rootViewController: sampleAppMainViewController!)
    self.window = window
    self.window?.makeKeyAndVisible()

    return true
  }

  public func application(_ app: UIApplication,
                          open url: URL,
                          options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    ApplicationDelegate.shared.application(
      app,
      open: url,
      sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
      annotation: options[UIApplication.OpenURLOptionsKey.annotation]
    )

    if Self.gOpenURLDelegate!.handleOpenURL(
      url,
      sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as! String
    ) {
      return true
    }
    if sampleAppMainViewController!.handleIncomingLink(with: url) {
      return true
    }
    return false
  }

  public func application(_ application: UIApplication,
                          continue userActivity: NSUserActivity,
                          restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void)
    -> Bool {
    if userActivity.webpageURL != nil {
      return sampleAppMainViewController!.handleIncomingLink(with: userActivity.webpageURL!)
    }
    return false
  }
}
