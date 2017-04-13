/*
 * Copyright 2017 Google
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

import UIKit

import FirebaseDev // FirebaseCore
import GoogleSignIn // GoogleSignIn

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  /** @var kGoogleClientID
      @brief The Google client ID.
   */
  private let kGoogleClientID =
      "1085102361755-f46rhqgjkr313n5kqnsoh6l4vlu9nd4k.apps.googleusercontent.com"

  // TODO(xiangtian): add Facebook login support as well.

  /** @var kFacebookAppID
      @brief The Facebook app ID.
   */
  private let kFacebookAppID = "452491954956225"

  /** @var window
      @brief The main window of the app.
   */
  var window: UIWindow?

  func application(_ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    FIRApp.configure()
    GIDSignIn.sharedInstance().clientID = kGoogleClientID
    return true
  }

  @available(iOS 9.0, *)
  func application(_ application: UIApplication, open url: URL,
      options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
    return GIDSignIn.sharedInstance().handle(url,
        sourceApplication: options[UIApplicationOpenURLOptionsKey.sourceApplication] as! String,
        annotation: nil)
  }

  func application(_ application: UIApplication, open url: URL, sourceApplication: String?,
      annotation: Any) -> Bool {
    return GIDSignIn.sharedInstance().handle(url, sourceApplication: sourceApplication,
        annotation: annotation)
  }
}
