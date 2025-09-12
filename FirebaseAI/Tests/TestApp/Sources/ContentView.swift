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

import FirebaseAI
import SwiftUI

struct ContentView: View {
  // TODO: Revert changes in this file. For prototyping purposes only.
  let liveModel: LiveGenerativeModel = {
    // let firebaseAI = FirebaseAI.firebaseAI(backend: .vertexAI())
    let firebaseAI = FirebaseAI.firebaseAI()
    return firebaseAI.liveModel(
      modelName: "gemini-2.0-flash-live-001",
      generationConfig: LiveGenerationConfig(responseModalities: [.text])
    )
  }()

  @State private var responses: [String] = []

  var body: some View {
    VStack {
      List(responses, id: \.self) {
        Text($0)
      }
    }
    .padding()
    .task {
      do {
        let liveSession = liveModel.connect()
        try await liveSession.sendMessage("Why is the sky blue?")
        for try await response in liveSession.responses {
          responses.append(String(describing: response))
        }
      } catch {
        print(error)
      }
    }
  }
}

#Preview {
  ContentView()
}
