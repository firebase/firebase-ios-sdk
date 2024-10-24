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

import SwiftUI

import FirebaseAuth

struct LoginView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var multiFactorResolver: MultiFactorResolver? = nil
  @State private var onetimePasscode = ""
  @State private var showingAlert = false

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
            backgroundColor: .orange,
            action: login
          )
          LoginViewButton(
            text: "Create Account",
            accentColor: .orange,
            backgroundColor: .primary,
            action: createUser
          )
        }
        .disabled(email.isEmpty || password.isEmpty)
      }
      Spacer()
    }
    .padding()
    .alert("Enter one time passcode.", isPresented: $showingAlert) {
      TextField("Verification Code", text: $onetimePasscode)
        .textInputAutocapitalization(.never)
      Button("Cancel", role: .cancel) {}
      Button("Submit", action: submitOnetimePasscode)
    }
  }

  private func login() {
    Task {
      do {
        _ = try await AppManager.shared
          .auth()
          .signIn(withEmail: email, password: password)
        //              } catch let error as AuthErrorCode
        //                where error.code == .secondFactorRequired {
        //                // error as? AuthErrorCode == nil because AuthErrorUtils returns generic
        //                /Errors
        //                // https://firebase.google.com/docs/auth/ios/totp-mfa#sign_in_users_with_a_second_factor
        //                // TODO(ncooke3): Fix?
      } catch let error as NSError
        where error.code == AuthErrorCode.secondFactorRequired.rawValue {
        let mfaKey = AuthErrorUserInfoMultiFactorResolverKey
        guard
          let resolver = error.userInfo[mfaKey] as? MultiFactorResolver,
          let multiFactorInfo = resolver.hints.first
        else { return }
        if multiFactorInfo.factorID == TOTPMultiFactorID {
          // Show the alert to enter the TOTP verification code.
          multiFactorResolver = resolver
          showingAlert = true
        } else {
          // TODO(ncooke3): Implement handling of other MFA provider (phone).
        }
      } catch {
        print(error.localizedDescription)
      }
    }
  }

  private func createUser() {
    Task {
      do {
        _ = try await AppManager.shared.auth().createUser(
          withEmail: email,
          password: password
        )
        // Sign-in was successful.
        dismiss()
      } catch {
        // TODO(ncooke3): Implement error display.
        print(error.localizedDescription)
      }
    }
  }

  private func submitOnetimePasscode() {
    Task {
      guard onetimePasscode.count > 0 else { return }
      let multiFactorInfo = multiFactorResolver!.hints[0]
      let assertion = TOTPMultiFactorGenerator.assertionForSignIn(
        withEnrollmentID: multiFactorInfo.uid,
        // TODO(ncooke3): Probably should avoid network request if empty passcode.
        oneTimePassword: self.onetimePasscode
      )
      do {
        _ = try await multiFactorResolver!.resolveSignIn(with: assertion)
        // MFA login was successful.
        dismiss()
      } catch {
        // Wrong or expired OTP. Re-prompt the user.
        // TODO(ncooke3): Show error to user.
        print(error)
      }
    }
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
    .background(Color(uiColor: .secondarySystemBackground))
    .cornerRadius(14)
    .textInputAutocapitalization(.never)
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
  LoginView()
}
