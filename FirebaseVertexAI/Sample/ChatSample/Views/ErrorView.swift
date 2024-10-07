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

import FirebaseVertexAI
import SwiftUI

struct ErrorView: View {
  var error: Error
  @State private var isDetailsSheetPresented = false
  var body: some View {
    HStack {
      Text("An error occurred.")
      Button(action: { isDetailsSheetPresented.toggle() }) {
        Image(systemName: "info.circle")
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .listRowSeparator(.hidden)
    .sheet(isPresented: $isDetailsSheetPresented) {
      ErrorDetailsView(error: error)
    }
  }
}

#Preview {
  NavigationView {
    let errorPromptBlocked = GenerateContentError.promptBlocked(
      response: GenerateContentResponse(candidates: [
        CandidateResponse(content: ModelContent(role: "model", parts: [
          """
            A _hypothetical_ model response.
            Cillum ex aliqua amet aliquip labore amet eiusmod consectetur reprehenderit sit commodo.
          """,
        ]),
        safetyRatings: [
          SafetyRating(category: .dangerousContent, probability: .high),
          SafetyRating(category: .harassment, probability: .low),
          SafetyRating(category: .hateSpeech, probability: .low),
          SafetyRating(category: .sexuallyExplicit, probability: .low),
        ],
        finishReason: FinishReason.other,
        citationMetadata: nil),
      ])
    )
    List {
      MessageView(message: ChatMessage.samples[0])
      MessageView(message: ChatMessage.samples[1])
      ErrorView(error: errorPromptBlocked)
    }
    .listStyle(.plain)
    .navigationTitle("Chat sample")
  }
}
