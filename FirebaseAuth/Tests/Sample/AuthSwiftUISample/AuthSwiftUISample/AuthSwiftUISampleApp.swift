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

import SwiftUI
import UIKit

import FirebaseAuth
import FirebaseCore
import GoogleUtilitiesMulticastAppDelegate

class MulticastAppDelegate: GULMulticastAppDelegate {
  override init() {
    super.init(appDelegate: AppDelegate())
  }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_: UIApplication,
                   didFinishLaunchingWithOptions _: [UIApplication
                     .LaunchOptionsKey: Any]? = nil) -> Bool
  {
    FirebaseApp.configure()

    PhoneAuthProvider.provider()
      .verifyPhoneNumber("+16505551234", uiDelegate: nil) { verificationID, error in
        if let error = error {
          print(error)
          return
        }
        // Sign in using the verificationID and the code sent to the user
        // ...
        UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
        let verificationID = UserDefaults.standard.string(forKey: "authVerificationID")
        self.signin(verificationID: verificationID ?? "")
      }

    return true
  }

  func signin(verificationID: String) {
    let credential = PhoneAuthProvider.provider().credential(
      withVerificationID: verificationID,
      verificationCode: "654321"
    )
    Auth.auth().signIn(with: credential) { _, error in
      if let error = error {
        print(error.localizedDescription)
        return
      }
    }
  }
}

@main
struct AuthSwiftUISampleApp: App {
  @UIApplicationDelegateAdaptor(MulticastAppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
