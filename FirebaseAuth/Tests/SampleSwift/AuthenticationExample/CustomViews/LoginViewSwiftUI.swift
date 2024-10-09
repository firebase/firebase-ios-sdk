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

// TODO(ncooke3): Change name of this file.

import SwiftUI

import FirebaseAuth

struct LoginViewSwiftUI: View {
  @State private var email: String = ""
  @State private var password: String = ""
  var body: some View {
    Group {
      VStack {
        Group {
          HStack {
            VStack {
              Text("Email/Password Auth")
                .font(.title)
                .bold()
            }
            Spacer()
          }
          HStack {
            Text(
              "Login or create an account using the Email/Password auth " +
                "provider.\n\nEnsure that the Email/Password provider is " +
                "enabled on the Firebase console for the given project."
            )
            .fixedSize(horizontal: false, vertical: true)
            Spacer()
          }
        }
        .padding(.vertical)

        Spacer()
        TextField("Email", text: $email)
          .textFieldStyle(SymbolTextField(symbolName: "person.crop.circle"))
        TextField("Password", text: $password)
          .textFieldStyle(SymbolTextField(symbolName: "lock.fill"))
        Spacer()
        Group {
          LoginViewButton(
            text: "Login",
            accentColor: .white,
            backgroundColor: .orange
          ) {
            Task {
              do {
                _ = try await AppManager.shared
                  .auth()
                  .signIn(withEmail: email, password: password)
              } catch let error as AuthErrorCode
                where error.code == .secondFactorRequired {
                // TODO(ncooke3): Implement.
              } catch {
                // TODO(ncooke3): Implement error display.
                print(error.localizedDescription)
              }
            }
          }
          LoginViewButton(
            text: "Create Account",
            accentColor: .orange,
            backgroundColor: .primary
          ) {
            Task {
              do {
                _ = try await AppManager.shared.auth().createUser(
                  withEmail: email,
                  password: password
                )
                // TODO(ncooke3): Transition... `self.delegate?.loginDidOccur()`
              } catch {
                // TODO(ncooke3): Implement error display.
                print(error.localizedDescription)
              }
            }
          }
        }
        .disabled(email.isEmpty || password.isEmpty)
      }
      Spacer()
    }
    .padding()
  }
}

private struct SymbolTextField: TextFieldStyle {
  let symbolName: String

  func _body(configuration: TextField<Self._Label>) -> some View {
    HStack {
      Image(systemName: symbolName)
        .foregroundColor(.orange)
        .imageScale(.large)
        .padding(.leading)
      configuration
        .padding([.vertical, .trailing])
    }
    .background(Color.color(uiColor: .secondarySystemBackground))
    .cornerRadius(14)
  }
}

// TODO(ncooke3): Use view modifiers?
private struct LoginViewButton: View {
  let text: String
  let accentColor: Color
  let backgroundColor: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Spacer()
        Text(text)
          .bold()
          .accentColor(accentColor)
        Spacer()
      }
      .padding()
      .background(backgroundColor)
      .cornerRadius(14)
    }
  }
}

#Preview {
  LoginViewSwiftUI()
}
