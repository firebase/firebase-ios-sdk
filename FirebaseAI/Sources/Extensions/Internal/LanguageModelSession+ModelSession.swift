// Copyright 2026 Google LLC
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

// TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
#if compiler(>=6.2)
  import Foundation
  #if canImport(FoundationModels)
    import FoundationModels
  #endif // canImport(FoundationModels)

  extension FirebaseAI.LanguageModelSession: ModelSession {
    func respond<Content>(to prompt: [any PartsRepresentable], schema: FirebaseAI.GenerationSchema?,
                          generating type: Content.Type, includeSchemaInPrompt: Bool,
                          options: GenerationConfig?) async throws
      -> GenerativeModelSession.Response<Content> {
      #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) else {
          fatalError()
        }

        let parts = ModelContent(parts: prompt)
        let promptParts = parts.internalParts.map { part in
          guard !(part.isThought ?? false) else { fatalError() }
          guard let data = part.data else { fatalError() }
          guard case let .text(string) = data else { fatalError() }

          return Prompt(string)
        }
        let prompt = Prompt {
          for part in promptParts {
            part
          }
        }

        guard let session else {
          fatalError()
        }

        if type == String.self {
          let response = try await session.respond(to: prompt)

          let rawContent = FirebaseAI.GeneratedContent(
            kind: response.rawContent.kind,
            id: FirebaseAI.GenerationID(
              responseID: UUID().uuidString,
              generationID: response.rawContent.id
            ),
            isComplete: response.rawContent.isComplete
          )

          let modelContent = ModelContent(
            role: "model",
            parts: [InternalPart(.text(response.content), isThought: false, thoughtSignature: nil)]
          )
          let candidate = Candidate(
            content: modelContent,
            safetyRatings: [],
            finishReason: nil,
            citationMetadata: nil
          )
          let rawResponse = GenerateContentResponse(candidates: [candidate])

          guard let content = response.content as? Content else {
            fatalError()
          }

          return GenerativeModelSession.Response(
            content: content,
            rawContent: rawContent,
            rawResponse: rawResponse
          )
        } else {
          fatalError("Only String generation is supported.")
        }
      #else
        fatalError("Foundation Models not supported.")
      #endif // canImport(FoundationModels)
    }
  }
#endif // compiler(>=6.2)
