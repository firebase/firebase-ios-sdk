// Copyright 2025 Google LLC
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
import AuthenticationServices

class PasskeyViewController: UIViewController{
  
}

//func passkeySignUp(appManager: AppManager, logFailure: @escaping (String, Error?) -> Void, logSuccess: @escaping (String) -> Void, log: @escaping (String) -> Void, passkeyEnroll: @escaping () -> Void) {
//    // Sign in anonymously
//  appManager.auth().signInAnonymously { (result: AuthDataResult?, error: Error?) in
//        if let error = error {
//          logFailure("sign-in anonymously failed", error)
//        } else if let user = result?.user {
//            logSuccess("sign-in anonymously succeeded.")
//            log("User ID : \(user.uid)")
//            passkeyEnroll() // Call passkeyEnroll after successful anonymous sign-in
//        } else {
//          logFailure("sign-in anonymously failed", nil)
//        }
//    }
//}
//
//private func passkeySignIn(){
//  user?.startPasskeyEnrollmentWithName(withName: <#T##String?#>)
//}
//
//func passkeyEnroll(
//    appManager: AppManager,
//    logFailure: @escaping (String, Error?) -> Void,
//    log: @escaping (String) -> Void,
//    showTextInputPrompt: @escaping (String, UIKeyboardType, @escaping (Bool, String?) -> Void) -> Void,
//    presentationContextProvider: ASAuthorizationControllerPresentationContextProviding,
//    authorizationControllerDelegate: ASAuthorizationControllerDelegate
//) async {
//    guard let user = appManager.auth().currentUser else {
//        logFailure("Please sign in first.", nil)
//        return
//    }
//
//  guard let passkeyName = await showTextInputPrompt("passkey name", keyboardType: UIKeyboardType = .default) else {
//        return
//    }
//
//    if #available(iOS 16.0, macOS 12.0, tvOS 16.0, *) {
//        do {
//            let request = try await user.startPasskeyEnrollmentWithName(withName: passkeyName)
//            let controller = ASAuthorizationController(authorizationRequests: [request])
//            controller.delegate = authorizationControllerDelegate
//            controller.presentationContextProvider = presentationContextProvider
//            controller.performRequests()
//        } catch {
//            logFailure("Passkey enrollment failed", error)
//        }
//    } else {
//        log("OS version is not supported for this action.")
//    }
//}
//
//func passkeyUnenroll(){
//  
//}
