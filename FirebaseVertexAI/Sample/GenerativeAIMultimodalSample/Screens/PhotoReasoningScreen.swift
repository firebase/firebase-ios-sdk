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

import GenerativeAIUIComponents
import MarkdownUI
import PhotosUI
import SwiftUI

struct PhotoReasoningScreen: View {
  @StateObject var viewModel = PhotoReasoningViewModel()

  enum FocusedField: Hashable {
    case message
  }

  @FocusState
  var focusedField: FocusedField?

  var body: some View {
    VStack {
      MultimodalInputField(text: $viewModel.userInput, selection: $viewModel.selectedItems)
        .focused($focusedField, equals: .message)
        .onSubmit {
          onSendTapped()
        }

      ScrollViewReader { scrollViewProxy in
        List {
          if let outputText = viewModel.outputText {
            HStack(alignment: .top) {
              if viewModel.inProgress {
                ProgressView()
              } else {
                Image(systemName: "cloud.circle.fill")
                  .font(.title2)
              }

              Markdown("\(outputText)")
            }
            .listRowSeparator(.hidden)
          }
        }
        .listStyle(.plain)
      }
    }
    .navigationTitle("Multimodal sample")
    .onAppear {
      focusedField = .message
    }
  }

  // MARK: - Actions

  private func onSendTapped() {
    focusedField = nil

    Task {
      await viewModel.reason()
    }
  }
}

#Preview {
  NavigationStack {
    PhotoReasoningScreen()
  }
}
