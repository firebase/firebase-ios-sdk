// Copyright 2024 Google LLC
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
import GoogleSignIn

class AuthViewModel: ObservableObject {
  enum SignInState {
    case signedIn
    case signedOut
  }

  @Published var state: SignInState = .signedOut

  func signIn() {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
      fatalError("Missing clientID. Check the GoogleService-Info.plist")
    }

    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

    #if os(iOS) || os(visionOS)
      guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootViewController = windowScene.windows.first?.rootViewController else {
        print("There is no presenting window!")
        return
      }
    #elseif os(macOS)
      guard let rootViewController = NSApplication.shared.windows.first else {
        print("There is no presenting window!")
        return
      }
    #endif

    GIDSignIn.sharedInstance
      .signIn(withPresenting: rootViewController) { [unowned self] result, error in
        if let error = error {
          print("Error doing Google Sign-In, \(error)")
          return
        }

        guard let user = result?.user,
              let idToken = user.idToken?.tokenString
        else {
          print("Error accessing Google Sign-In token")
          return
        }

        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                       accessToken: user.accessToken.tokenString)

        Auth.auth().signIn(with: credential) { [unowned self] _, error in
          if let error {
            print(error.localizedDescription)
          } else {
            print("Signed in with Google")
            self.state = .signedIn
          }
        }
      }
  }

  func signOut() {
    GIDSignIn.sharedInstance.signOut()

    do {
      try Auth.auth().signOut()

      state = .signedOut
    } catch {
      print(error.localizedDescription)
    }
  }
}
