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

import Firebase
import FirebaseAuth
import FirebaseAuthCombineSwift
import Combine

class UserInfoViewModel: ObservableObject {
  @Published var user: User?

  @Published var isSignedIn = false

  private var cancellables = Set<AnyCancellable>()

  init() {
    Auth.auth().authStateDidChangePublisher()
      .map { $0 }
      .assign(to: &$user)

    $user
      .map { $0 != nil }
      .assign(to: &$isSignedIn)
  }
}
