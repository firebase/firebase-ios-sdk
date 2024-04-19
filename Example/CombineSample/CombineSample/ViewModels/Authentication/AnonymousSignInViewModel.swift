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

import Combine
import Firebase
import FirebaseAuthCombineSwift
import FirebaseFirestoreCombineSwift
import FirebaseFunctionsCombineSwift
import FirebaseStorageCombineSwift
import Foundation

class AnonymousSignInViewModel: UserInfoViewModel {
  private var cancellables = Set<AnyCancellable>()

  @Published var errorMessage: String = ""

  func signIn() {
    Auth.auth().signInAnonymously()
      .map { $0.user }
      .catch { error -> Just<User?> in
        if (error as NSError).code == AuthErrorCode.adminRestrictedOperation.rawValue {
          print("Make sure to enable Anonymous Auth for your project")
        } else {
          print(error)
        }
        return Just(nil)
      }
      .compactMap { $0 }
      .sink { user in
        print("User \(user.uid) signed in")
      }
      .store(in: &cancellables)
  }

  func signOut() {
    try? Auth.auth().signOut()
    user = nil
  }
}
