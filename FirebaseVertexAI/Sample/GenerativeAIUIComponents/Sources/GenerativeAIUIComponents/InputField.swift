// Copyright 2023 Google LLC
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

public struct InputField<Label>: View where Label: View {
  @Binding
  private var text: String

  private var title: String?
  private var label: () -> Label

  @Environment(\.submitHandler)
  var submitHandler

  private func submit() {
    if let submitHandler {
      submitHandler()
    }
  }

  public init(_ title: String? = nil, text: Binding<String>,
              @ViewBuilder label: @escaping () -> Label) {
    self.title = title
    _text = text
    self.label = label
  }

  public var body: some View {
    VStack(alignment: .leading) {
      HStack(alignment: .bottom) {
        VStack(alignment: .leading) {
          TextField(
            title ?? "",
            text: $text,
            axis: .vertical
          )
          .padding(.vertical, 4)
          .onSubmit(submit)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay {
          RoundedRectangle(
            cornerRadius: 8,
            style: .continuous
          )
          .stroke(Color(UIColor.systemFill), lineWidth: 1)
        }

        Button(action: submit, label: label)
          .padding(.bottom, 4)
      }
    }
    .padding(8)
  }
}

#Preview {
  struct Wrapper: View {
    @State var userInput: String = ""

    var body: some View {
      InputField("Message", text: $userInput) {
        Image(systemName: "arrow.up.circle.fill")
          .font(.title)
      }
    }
  }

  return Wrapper()
}
