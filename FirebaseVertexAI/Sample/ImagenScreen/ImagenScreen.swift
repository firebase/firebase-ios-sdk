// Copyright 2025 Google LLC
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

struct ImagenScreen: View {
  @StateObject var viewModel = ImagenViewModel()

  enum FocusedField: Hashable {
    case message
  }

  @FocusState
  var focusedField: FocusedField?

  var body: some View {
    VStack {
      TextField("Enter a prompt to generate an image", text: $viewModel.userInput)
        .focused($focusedField, equals: .message)
        .textFieldStyle(.roundedBorder)
        .onSubmit {
          onGenerateTapped()
        }
        .padding()

      Button("Generate") {
        onGenerateTapped()
      }
      .padding()
      if viewModel.inProgress {
        Text("Waiting for model response ...")
      }
      ForEach(viewModel.images, id: \.self) {
        Image(uiImage: $0)
          .resizable()
          .scaledToFill()
          .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
          .aspectRatio(nil, contentMode: .fit)
          .clipped()
      }
    }
    .navigationTitle("Imagen sample")
    .onAppear {
      focusedField = .message
    }
  }

  private func onGenerateTapped() {
    focusedField = nil

    Task {
      await viewModel.generateImage(prompt: viewModel.userInput)
    }
  }
}

#Preview {
  ImagenScreen()
}
