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
import Foundation
import OSLog
import PhotosUI
import SwiftUI

@MainActor
class MultimodalOutputViewModel: ObservableObject {

  private var logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "generative-ai")

  @Published
  var userInput: String = ""

  @Published
  var outputText: String? = nil

  @Published
  var errorMessage: String?

  @Published
  var inProgress = false
    
  @Published
  var responseModalities: [OutputContentModality]?
    
  private var model: GenerativeModel?

  init() {
      let config = GenerationConfig(responseModalities: [.text, .image, .audio])
    model = VertexAI.vertexAI().generativeModel(modelName: "gemini-2.0-flash-001", generationConfig: config)
  }

  func generate() async {
    defer {
      inProgress = false
    }
    guard let model else {
      return
    }

    do {
      inProgress = true
      errorMessage = nil
      outputText = ""

      let prompt = userInput
        
        let outputContentStream = try model.generateContentStream(prompt)
        
        for try await outputContent in outputContentStream {
            guard let line = outputContent.text else {
                return
            }
            
            outputText = (outputText ?? "") + line
        }
    } catch {
        logger.error("\(error.localizedDescription)")
        errorMessage = error.localizedDescription
    }
  }
}
