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

struct LoginViewSwiftUI: View {
  @State private var email: String = ""
  @State private var password: String = ""
  var body: some View {
    VStack {
      TextField("Email", text: $email)
        .textFieldStyle(SymbolTextField(symbolName: "person.crop.circle"))
      TextField("Password", text: $password)
        .textFieldStyle(SymbolTextField(symbolName: "lock.fill"))
      
      Button {
        // TODO(ncooke3): Add action.
      } label: {
        HStack {
          Spacer()
          Text("Login")
            .bold()
            .accentColor(.white)
          Spacer()
        }
        .padding()
        .background(Color.orange)
        .cornerRadius(14)
      }
      
      Button {
        // TODO(ncooke3): Add action.
      } label: {
        HStack {
          Spacer()
          Text("Create Account")
            .bold()
            .accentColor(.orange)
          Spacer()
        }
        .padding()
        .background(Color.primary)
        .cornerRadius(14)
      }
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


#Preview {
  LoginViewSwiftUI()
}
