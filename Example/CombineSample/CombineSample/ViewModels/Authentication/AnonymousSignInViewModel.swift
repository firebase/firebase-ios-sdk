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

import Foundation
import Firebase
import FirebaseCombineSwift
import Combine

class AnonymousSignInViewModel: UserInfoViewModel {
  private var cancellables = Set<AnyCancellable>()

  func signIn() {
    Auth.auth().signInAnonymously()
      // the following is completely optional and just for demo purposes
      .sink { completion in
      } receiveValue: { result in
        print(result.user.uid)
      }
      .store(in: &cancellables)
  }

  func signOut() {
    try? Auth.auth().signOut()
    user = nil
  }
}
