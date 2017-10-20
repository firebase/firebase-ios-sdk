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

/// This file contains a collection of stub functions to verify the Swift syntax of Firebase Auth
/// APIs in Swift for those that are not already covered by other parts of the app.
/// These functions are never executed, but just for passing compilation.

import FirebaseCommunity.FirebaseAuth

func actionCodeSettingsStubs() {
  let actionCodeSettings = ActionCodeSettings()
  actionCodeSettings.url = URL(string: "http://some.url/path/")
  actionCodeSettings.setIOSBundleID("some.bundle.id")
  actionCodeSettings.setAndroidPackageName("some.package.name", installIfNotAvailable: true,
      minimumVersion: nil)
  let _: String? = actionCodeSettings.iOSBundleID
  let _: String? = actionCodeSettings.androidPackageName
  let _: Bool = actionCodeSettings.androidInstallIfNotAvailable
  let _: String? = actionCodeSettings.androidMinimumVersion
  Auth.auth().sendPasswordReset(withEmail: "nobody@nowhere.com",
      actionCodeSettings: actionCodeSettings) { (error: Error?) -> () in
  }
  Auth.auth().currentUser?.sendEmailVerification(with: actionCodeSettings) {
      (error: Error?) -> () in
  }
}

func languageStubs() {
  let _: String? = Auth.auth().languageCode
  Auth.auth().languageCode = "asdf"
  Auth.auth().useAppLanguage()
}

func metadataStubs() {
  let credential = OAuthProvider.credential(withProviderID: "fake", accessToken: "none")
  Auth.auth().signInAndRetrieveData(with: credential) { result, error in
    let _: Bool? = result!.additionalUserInfo!.isNewUser
    let metadata: UserMetadata = result!.user.metadata
    let _: Date? = metadata.lastSignInDate
    let _: Date? = metadata.creationDate
  }
}
