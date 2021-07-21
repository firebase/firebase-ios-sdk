// Copyright 2019 Google
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

import UIKit
import Firebase
// Verify that the following Firebase Swift APIs can be found.
import FirebaseAnalyticsSwift
import FirebaseFirestoreSwift
import FirebaseInAppMessagingSwift
import FirebaseStorageSwift

class CoreExists: FirebaseApp {}
class AnalyticsExists: Analytics {}
class AuthExists: Auth {}
// Uncomment next line if ABTesting gets added to Firebase.h.
// class ABTestingExists : LifecycleEvents {}
class DatabaseExists: Database {}
class DynamicLinksExists: DynamicLinks {}
class FirestoreExists: Firestore {}
class FunctionsExists: Functions {}
class InAppMessagingExists: InAppMessaging {}
class InAppMessagingDisplayExists: InAppMessagingDisplay { // protocol instead of interface
  func displayMessage(_ messageForDisplay: InAppMessagingDisplayMessage,
                      displayDelegate: InAppMessagingDisplayDelegate) {}
}

class MessagingExists: Messaging {}
class PerformanceExists: Performance {}
class RemoteConfigExists: RemoteConfig {}
class StorageExists: Storage {}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication
                     .LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication,
                   configurationForConnecting connectingSceneSession: UISceneSession,
                   options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration",
                                sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication,
                   didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
  }
}
