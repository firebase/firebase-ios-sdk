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

struct ContentView: View {
  @StateObject
  var viewModel = ConversationViewModel()

  @StateObject
  var functionCallingViewModel = FunctionCallingViewModel()

  var body: some View {
    NavigationStack {
      List {
        NavigationLink {
          SummarizeScreen()
        } label: {
          Label("Text", systemImage: "doc.text")
        }
        NavigationLink {
          PhotoReasoningScreen()
        } label: {
          Label("Multi-modal", systemImage: "doc.richtext")
        }
        NavigationLink {
          ConversationScreen()
            .environmentObject(viewModel)
        } label: {
          Label("Chat", systemImage: "ellipsis.message.fill")
        }
        NavigationLink {
          FunctionCallingScreen().environmentObject(functionCallingViewModel)
        } label: {
          Label("Function Calling", systemImage: "function")
        }
      }
      .navigationTitle("Generative AI Samples")
    }
  }
}

#Preview {
  ContentView()
}
