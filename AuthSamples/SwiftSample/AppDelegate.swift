/** @file AppDelegate.swift
    @brief Firebase Auth SDK Swift Sample App
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

import UIKit

import googlemac_iPhone_Firebase_FIRCore // FirebaseAnalytics
import googlemac_iPhone_Identity_SDK_SignIn_SignIn // GoogleSignIn

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
