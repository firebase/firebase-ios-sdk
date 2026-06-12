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

import CoreGraphics
import Foundation
import FoundationModels

#if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM && compiler(>=6.4)
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  public extension GeminiLanguageModel {
    struct Executor: LanguageModelExecutor {
      let configuration: GeminiLanguageModel.ModelConfig

      static let placeholderIDPrefix = "placeholder-id-"

      public init(configuration: GeminiLanguageModel.ModelConfig) throws {
        self.configuration = configuration
      }

      public func respond(to request: LanguageModelExecutorGenerationRequest,
                          model: GeminiLanguageModel,
                          streamingInto channel: LanguageModelExecutorGenerationChannel) async throws {
        // 1. Translate `request` into your provider's request format.
        // TODO: Translate `request` into a `GenerateContentRequest`.
        var contents = [ModelContent]()
        var generationConfig = GenerationConfig()
        var tools: [FirebaseAILogic.Tool]? = nil
        var toolConfig: ToolConfig? = nil
        var systemInstruction: ModelContent? = nil

        let generateContentRequest = GenerateContentRequest(
          model: configuration.modelResourceName,
          contents: contents,
          generationConfig: generationConfig,
          safetySettings: configuration.safetySettings,
          tools: tools,
          toolConfig: toolConfig,
          systemInstruction: systemInstruction,
          apiConfig: configuration.apiConfig,
          apiMethod: .streamGenerateContent,
          options: configuration.requestOptions
        )

        // 2. Open the stream to your provider.

        let stream = TaskLocals.$isFoundationModelsRequest.withValue(true) {
          model.generativeAIService.loadRequestStream(request: generateContentRequest)
        }

        // 3. For each provider event, translate it into one or more channel
        //    events and send them. Use the same `entryID` for all events that
        //    belong to one response entry; use a DIFFERENT `entryID` for the
        //    tool-calls entry.

        let responseEntryID = UUID().uuidString
        let toolCallsEntryID = UUID().uuidString
        let reasoningEntryID = UUID().uuidString

        for try await response in stream {
          try Task.checkCancellation()

          // TODO: Translate each `response` to one or more `LanguageModelExecutorGenerationChannel.Event`s and send them with `await channel.send(...)`.
        }
      }
    }
  }
#endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM && compiler(>=6.4)
