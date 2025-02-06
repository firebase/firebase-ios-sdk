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

struct ContentView: View {
  @StateObject private var viewModel = ViewModel()

  @State private var promptText = ""
  @State private var useGCS = false

  var body: some View {
    VStack {
      ScrollView {
        ScrollViewReader { _ in
          VStack {
            if viewModel.isLoading {
              ProgressView()
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
        }
      }
      .padding()

      HStack {
        TextField("Image generation prompt...", text: $promptText)
          .padding()
          .background(Color(.systemGray6))
          .cornerRadius(20)

        Button {
          generateImages()
        } label: {
          Image(systemName: "paperplane.fill")
            .font(.title2)
        }
        .padding(.trailing)
        .disabled(promptText.isEmpty)
      }
      .padding()
      .background(.white)

      HStack {
        Toggle(isOn: $useGCS) {
          Text("Use Cloud Storage For Firebase")
        }.padding(.horizontal)
      }.padding(.horizontal)
    }
    .navigationTitle("Imagen Bug Bash")
  }

  func generateImages() {
    guard !promptText.isEmpty else { return }

    viewModel.generateImages(prompt: promptText, isGCS: useGCS)
  }
}

#Preview {
  NavigationView {
    ContentView()
  }
}
