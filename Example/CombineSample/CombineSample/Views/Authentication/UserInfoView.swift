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

import SwiftUI

struct UserInfoView: View {
  @ObservedObject var viewModel: UserInfoViewModel

  var body: some View {
    Section(header: Text("User Info")) {
      LabelTextView(
        "User state",
        value: viewModel.isSignedIn ? "User is signed in" : "User is signed out"
      )
      LabelTextView("User ID", value: viewModel.user?.uid ?? "")
      LabelTextView("Display name", value: viewModel.user?.displayName ?? "")
      LabelTextView("Email", value: viewModel.user?.email ?? "")
    }
  }
}

struct UserInfoView_Previews: PreviewProvider {
  static let viewModel = UserInfoViewModel()
  static var previews: some View {
    Form {
      UserInfoView(viewModel: viewModel)
    }
  }
}
