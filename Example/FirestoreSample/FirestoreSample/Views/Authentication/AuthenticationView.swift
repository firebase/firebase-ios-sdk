//
// AuthenticationView.swift
// FirestoreSample
//
// Created by Peter Friese on 14.07.23.
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
import FirebaseAuth

struct AuthenticationView: View {
  let auth = Auth.auth()
  @State var user: User?
  @State var isSignedIn = false

  var body: some View {
    VStack {
      Button(action: {
        if isSignedIn {
          do {
            try auth.signOut()
          }
          catch {
          }
        }
        else {
          Task {
            auth.signIn(withEmail: "test@test.com", password: "s3cr3t")
          }
        }
      }, label: {
        Text("Sign \(isSignedIn ? "out" : "in")")
      })
    }
    .task {
      for await isSignedIn in auth.authDidChangeSequence().map({ $0 != nil }) {
        self.isSignedIn = isSignedIn
      }
      for await user in auth.authDidChangeSequence() {
        self.user = user
      }
    }
  }

}

struct AuthenticationView_Previews: PreviewProvider {
  static var previews: some View {
    AuthenticationView()
  }
}
