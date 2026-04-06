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

#if canImport(FoundationModels)
  import Foundation
  import FoundationModels

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FoundationModels.LanguageModelSession: ModelSession {
    func respond<Content>(to prompt: [any PartsRepresentable], schema: FirebaseAI.GenerationSchema?,
                          generating type: Content.Type, includeSchemaInPrompt: Bool,
                          options: GenerationConfig?) async throws
      -> GenerativeModelSession.Response<Content> {
      let parts = ModelContent(parts: prompt)
      let promptParts: [Prompt] = try parts.internalParts.compactMap { part in
        // Skip any `thought` parts since they are unused by Foundation Models.
        guard !(part.isThought ?? false) else { return nil }

        // Skip any parts without `data`, for example a `Part` containing only a thought signature,
        // since they are unused by Foundation Models.
        guard let data = part.data else { return nil }

        // Currently only string types are supported.
        guard case let .text(string) = data else {
          // TODO: Create a custom error type for unsupported prompt part types.
          throw GenerativeModelSession.GenerationError.internalError(
            GenerativeModelSession.GenerationError.Context(
              debugDescription: """
              Prompt data type "\(data)" is not supported by Foundation Models.
              """
            ),
            underlyingError: NSError(domain: Constants.baseErrorDomain, code: 0)
          )
        }

        return Prompt(string)
      }
      let prompt = Prompt {
        for part in promptParts {
          part
        }
      }

      if type == String.self {
        let response = try await respond(to: prompt)

        let rawContent = FirebaseAI.GeneratedContent(
          kind: response.rawContent.kind,
          id: FirebaseAI.GenerationID(responseID: nil, generationID: response.rawContent.id),
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
        let rawResponse = GenerateContentResponse(
          candidates: [candidate],
          modelVersion: SystemLanguageModel.modelName
        )

        guard let content = response.content as? Content else {
          fatalError()
        }

        return GenerativeModelSession.Response(
          content: content,
          rawContent: rawContent,
          rawResponse: rawResponse
        )
      } else if let contentMetatype = type as? (any FoundationModels.Generable.Type) {
        // Generic helper to explicitly bind the opened existential type to `T`.
        func fetchResponse<T: FoundationModels.Generable>(_ generableType: T
          .Type) async throws -> GenerativeModelSession.Response<Content> {
          let response = try await respond(
            to: prompt,
            generating: generableType,
            includeSchemaInPrompt: includeSchemaInPrompt
          )

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
            parts: [
              InternalPart(
                .text(response.rawContent.jsonString),
                isThought: false,
                thoughtSignature: nil
              ),
            ]
          )
          let candidate = Candidate(
            content: modelContent,
            safetyRatings: [],
            finishReason: nil,
            citationMetadata: nil
          )
          let rawResponse = GenerateContentResponse(candidates: [candidate])

          // Cast the generated content back to the outer `Content` type.
          guard let finalContent = response.content as? Content else {
            fatalError("Expected \(Content.self) but received \(T.self)")
          }

          return GenerativeModelSession.Response(
            content: finalContent,
            rawContent: rawContent,
            rawResponse: rawResponse
          )
        }

        // Call the helper, which opens `contentMetatype` and passes it as `T`.
        return try await fetchResponse(contentMetatype)

      } else {
        fatalError("Unsupported type for generation: \(type)")
      }
    }

    func streamResponse<Content, PartialContent>(to prompt: [any PartsRepresentable],
                                                 schema: FirebaseAI.GenerationSchema?,
                                                 generating type: Content.Type,
                                                 includeSchemaInPrompt: Bool,
                                                 options: GenerationConfig?)
      throws -> sending GenerativeModelSession.ResponseStream<Content, PartialContent> {
      // TODO: Create a new error type
      throw NSError(
        domain: Constants.baseErrorDomain,
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "Hybrid streaming support is not yet implemented."]
      )
    }
  }
#endif // canImport(FoundationModels)
