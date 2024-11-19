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
import SwiftUI

struct MFALoginView: View {
  @Environment(\.dismiss) private var dismiss

  @State private var factorSelection: MultiFactorInfo?
  // This is only needed for phone MFA.
  @State private var verificationId: String?
  // This is needed for both phone and TOTP MFA.
  @State private var verificationCode: String = ""

  private let resolver: MultiFactorResolver
  private weak var delegate: (any LoginDelegate)?

  init(resolver: MultiFactorResolver, delegate: (any LoginDelegate)?) {
    self.resolver = resolver
    self.delegate = delegate
  }

  var body: some View {
    Text("Choose a second factor to continue.")
      .padding(.top)
    List(resolver.hints, id: \.self, selection: $factorSelection) {
      Text($0.displayName ?? "No display name provided.")
    }
    .frame(height: 300)
    .clipShape(RoundedRectangle(cornerRadius: 15))
    .padding()

    if let factorSelection {
      // TODO(ncooke3): This logic handles both phone and TOTP MFA states. Investigate how to make
      // more clear with better APIs.
      if factorSelection.factorID == PhoneMultiFactorID, verificationId == nil {
        MFAViewButton(
          text: "Send Verification Code",
          accentColor: .white,
          backgroundColor: .orange
        ) {
          Task { await startMfALogin() }
        }
        .padding()
      } else {
        TextField("Enter verification code.", text: $verificationCode)
          .textFieldStyle(SymbolTextField(symbolName: "lock.circle.fill"))
          .padding()
        MFAViewButton(
          text: "Sign in",
          accentColor: .white,
          backgroundColor: .orange
        ) {
          Task { await finishMfALogin() }
        }
        .padding()
      }
    }
    Spacer()
  }
}

extension MFALoginView {
  private func startMfALogin() async {
    guard let factorSelection else { return }
    switch factorSelection.factorID {
    case PhoneMultiFactorID:
      await startPhoneMultiFactorSignIn(hint: factorSelection as? PhoneMultiFactorInfo)
    case TOTPMultiFactorID: break // TODO(ncooke3): Indicate to user to get verification code.
    default: return
    }
  }

  private func startPhoneMultiFactorSignIn(hint: PhoneMultiFactorInfo?) async {
    guard let hint else { return }
    do {
      verificationId = try await PhoneAuthProvider.provider().verifyPhoneNumber(
        with: hint,
        uiDelegate: nil,
        multiFactorSession: resolver.session
      )
    } catch {
      print(error)
    }
  }

  private func finishMfALogin() async {
    guard let factorSelection else { return }
    switch factorSelection.factorID {
    case PhoneMultiFactorID:
      await finishPhoneMultiFactorSignIn()
    case TOTPMultiFactorID:
      await finishTOTPMultiFactorSignIn(hint: factorSelection)
    default: return
    }
  }

  private func finishPhoneMultiFactorSignIn() async {
    guard let verificationId else { return }
    let credential = PhoneAuthProvider.provider().credential(
      withVerificationID: verificationId,
      verificationCode: verificationCode
    )
    let assertion = PhoneMultiFactorGenerator.assertion(with: credential)
    do {
      _ = try await resolver.resolveSignIn(with: assertion)
      // MFA login was successful.
      await MainActor.run {
        dismiss()
        delegate?.loginDidOccur(resolver: nil)
      }
    } catch {
      print(error)
    }
  }

  private func finishTOTPMultiFactorSignIn(hint: MultiFactorInfo) async {
    // TODO(ncooke3): Disable button if verification code textfield contents is empty.
    guard verificationCode.count > 0 else { return }
    let assertion = TOTPMultiFactorGenerator.assertionForSignIn(
      withEnrollmentID: hint.uid,
      oneTimePassword: verificationCode
    )
    do {
      _ = try await resolver.resolveSignIn(with: assertion)
      // MFA login was successful.
      await MainActor.run {
        dismiss()
        delegate?.loginDidOccur(resolver: nil)
      }
    } catch {
      // Wrong or expired OTP. Re-prompt the user.
      // TODO(ncooke3): Show error to user.
      print(error)
    }
  }
}

private struct MFAViewButton: View {
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
