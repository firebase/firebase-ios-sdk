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

#if compiler(>=6.4) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
  import CoreGraphics
  import Foundation
  import FoundationModels
  import ImageIO

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript {
    func thoughtSignature(forEntry id: String) -> String? {
      for entry in self {
        if case let .reasoning(reasoning) = entry,
           reasoning.id == id,
           let signature = reasoning.signature,
           let thoughtSignature = String(data: signature, encoding: .utf8) {
          return thoughtSignature
        }
      }

      return nil
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public extension GeminiLanguageModel {
    struct Executor: LanguageModelExecutor {
      let firebaseAI: FirebaseAI
      let configuration: GeminiLanguageModel.ModelConfig

      static let placeholderIDPrefix = "placeholder-id-"

      public init(configuration: GeminiLanguageModel.ModelConfig) throws {
        firebaseAI = configuration.firebaseAI
        self.configuration = configuration
      }

      public func respond(to request: LanguageModelExecutorGenerationRequest,
                          model: GeminiLanguageModel,
                          streamingInto channel: LanguageModelExecutorGenerationChannel) async throws {
        var responseEntryID: String? = nil

        var systemInstruction: ModelContent?
        var parts = [ModelContent]()

        for entry in request.transcript {
          switch entry {
          case let .instructions(instructions):
            systemInstruction = try instructions.toGeminiSystemInstruction()

          case let .prompt(prompt):
            try parts.append(prompt.toGeminiPrompt())

          case let .toolCalls(toolCalls):
            var functionCallParts = [FunctionCallPart]()
            for toolCall in toolCalls {
              let functionCallPart = try FunctionCallPart(
                FunctionCall(
                  name: toolCall.toolName,
                  args: JSONObject(toolCall.arguments.jsonString),
                  id: toolCall.id
                ),
                isThought: nil,
                thoughtSignature: functionCallParts.isEmpty ? request.transcript
                  .thoughtSignature(forEntry: entry.id) : nil
              )
              // FunctionCall part
              functionCallParts.append(functionCallPart)
            }
            parts.append(ModelContent(role: "model", parts: functionCallParts))

          case let .toolOutput(toolOutput):
            //          let reasoningSegments =  toolOutput.segments.compactMap {
            //            if case .reasoning(let reasoning) = $0 {
            //              return reasoning
            //            }
            //            return nil
            //          }
            guard let segment = toolOutput.segments.first else {
              continue
            }

            let functionID = toolOutput.id
              .hasPrefix(Executor.placeholderIDPrefix) ? nil : toolOutput.id
            switch segment {
            case let .text(text):
              var functionResponseParts: [FunctionResponsePart] = []
              functionResponseParts.append(
                FunctionResponsePart(
                  name: toolOutput.toolName,
                  response: ["result": .string(text.content)],
                  functionId: functionID
                )
              )
              parts.append(ModelContent(role: "function", parts: functionResponseParts))

            case let .structure(structure):
              var functionResponseParts: [FunctionResponsePart] = []
              try functionResponseParts.append(
                FunctionResponsePart(
                  name: toolOutput.toolName,
                  response: JSONObject(
                    structure.content.jsonString
                  ),
                  functionId: functionID
                  //                thoughtSignature: thoughtSignature
                )
              )
              parts.append(ModelContent(role: "function", parts: functionResponseParts))

            case let .attachment(attachment):
              throw LanguageModelError.unsupportedTranscriptContent(
                LanguageModelError.UnsupportedTranscriptContent(
                  unsupportedContent: [entry],
                  debugDescription: "Unsupported attachment segment in tool output: \(attachment)"
                )
              )

            case let .custom(customSegment):
              throw LanguageModelError.unsupportedTranscriptContent(
                LanguageModelError.UnsupportedTranscriptContent(
                  unsupportedContent: [entry],
                  debugDescription: "Unsupported custom segment in tool output: \(customSegment)"
                )
              )

            @unknown default:
              AILog.warning(
                code: .unrecognizedSegmentType,
                "Unknown segment type encountered: \(segment)"
              )
            }

          case let .response(response):
            try parts.append(response.toGeminiResponse())

          case let .reasoning(reasoning):
            // TODO: We're assuming that there's only Text segments, and only ever 1 segment. We should revisit this and have more robust handling.
            let sig = request.transcript.thoughtSignature(forEntry: reasoning.id)
            for segment in reasoning.segments {
              switch segment {
              case let .text(text):
                let content = ModelContent(role: "model", parts: [TextPart(text.content,
                                                                           isThought: true,
                                                                           thoughtSignature: sig)])
                parts.append(content)
              default:
                AILog.warning(
                  code: .unrecognizedSegmentType,
                  "Non Text thought segment encountered - ignoring for now: \(segment)"
                )
                continue
              }
            }

          @unknown default:
            AILog.warning(
              code: .unrecognizedTranscriptEntryType,
              "Unknown entry type encountered: \(entry)"
            )
          }
        }

        var generationConfig = GenerationConfig()
        if let schema = request.schema {
          // Note: `request.contextOptions.includeSchemaInPrompt` is handled natively.
          // Since Gemini natively accepts JSON Schema declarations using `responseJSONSchema`,
          // explicit manual prompt injection is unnecessary; we always configure the schema
          // natively.
          generationConfig = try GenerationConfig(
            responseMIMEType: "application/json",
            responseJSONSchema: FirebaseAI.GenerationSchema(schema).toGeminiJSONSchema()
          )
        }
        if let temp = request.generationOptions.temperature {
          generationConfig.temperature = Float(temp)
        }
        if let maxTokens = request.generationOptions.maximumResponseTokens {
          generationConfig.maxOutputTokens = maxTokens
        }
        if let responseModalities = configuration.geminiOptions?.responseModalities {
          generationConfig.responseModalities = responseModalities
        }
        if let imageConfig = configuration.geminiOptions?.imageConfig {
          generationConfig.imageConfig = imageConfig
        }
        if let samplingMode = request.generationOptions.samplingMode {
          switch samplingMode.kind {
          case .greedy:
            generationConfig.temperature = 0.0
          case let .top(k, seed):
            generationConfig.topK = k
            generationConfig.seed = seed.map { Int(truncatingIfNeeded: $0) }
          case let .nucleus(threshold, seed):
            generationConfig.topP = Float(threshold)
            generationConfig.seed = seed.map { Int(truncatingIfNeeded: $0) }
          @unknown default:
            break
          }
        }
        if let reasoningLevel = request.contextOptions.reasoningLevel {
          let includeThoughts = configuration.geminiOptions?.includeThoughts
          switch reasoningLevel {
          case .light:
            generationConfig.thinkingConfig = ThinkingConfig(
              thinkingLevel: .low,
              includeThoughts: includeThoughts
            )
          case .moderate:
            generationConfig.thinkingConfig = ThinkingConfig(
              thinkingLevel: .medium,
              includeThoughts: includeThoughts
            )
          case .deep:
            generationConfig.thinkingConfig = ThinkingConfig(
              thinkingLevel: .high,
              includeThoughts: includeThoughts
            )
          case let .custom(level):
            generationConfig.thinkingConfig = ThinkingConfig(
              thinkingLevel: ThinkingConfig.ThinkingLevel(rawValue: level.uppercased()),
              includeThoughts: includeThoughts
            )
          @unknown default:
            AILog.warning(
              code: .unrecognizedTranscriptEntryType,
              "Unsupported reasoning level: \(reasoningLevel)"
            )
          }
        }

        var toolConfig: ToolConfig?
        if let toolCallingMode = request.generationOptions.toolCallingMode {
          switch toolCallingMode.kind {
          case .allowed:
            toolConfig = ToolConfig(functionCallingConfig: .auto())
          case .required:
            toolConfig = ToolConfig(functionCallingConfig: .any())
          case .disallowed:
            toolConfig = ToolConfig(functionCallingConfig: .none())
          @unknown default:
            break
          }
        }

        var tools: [FirebaseAILogic.Tool] = []
        for tool in request.enabledToolDefinitions {
          tools.append(
            FirebaseAILogic.Tool.functionDeclarations(
              [
                FunctionDeclaration(
                  name: tool.name,
                  description: tool.description,
                  parameters: FirebaseAI.GenerationSchema(tool.parameters)
                ),
              ]
            )
          )
        }
        for serverTool in configuration.serverTools {
          switch serverTool {
          case let .googleSearch(googleSearch):
            tools.append(googleSearch.toolRepresentation)
          case let .googleMaps(googleMaps):
            tools.append(googleMaps.toolRepresentation)
          case let .urlContext(urlContext):
            tools.append(urlContext.toolRepresentation)
          case let .codeExecution(codeExecution):
            tools.append(codeExecution.toolRepresentation)
          }
        }

        let generativeModel = firebaseAI.generativeModel(
          modelName: configuration.modelName,
          generationConfig: generationConfig,
          tools: tools,
          toolConfig: toolConfig,
          systemInstruction: systemInstruction,
          requestOptions: configuration.requestOptions
        )

        // 2. Open the stream to your provider. The transport is your choice —
        //    URLSession.bytes, a vendored SDK, gRPC, WebSocket, anything that
        //    yields an async sequence of provider events.

        let stream = try TaskLocals.$isFoundationModelsRequest.withValue(true) {
          try generativeModel.generateContentStream(parts)
        }

        // 3. For each provider event, translate it into one or more channel
        //    events and send them. Use the same `entryID` for all events that
        //    belong to one response entry; use a DIFFERENT `entryID` for the
        //    tool-calls entry.

        for try await response in stream {
          try Task.checkCancellation()

          // Get the `responseId` from the `GenerateContentResponse`; it is stable while streaming
          // from Gemini.
          if responseEntryID == nil {
            // This should be unnecessary but, as a fallback, create a stable UUID for the responses
            // in the stream.
            responseEntryID = response.responseID ?? UUID().uuidString
          }

          //
          //        // TODO: Figure out what to throw when there are no parts.
          //        // TODO: Make sure we can get the thought signature if it's sent as a separate
          //        /part without
          //        // any other data; we would need to send an action with
          //        /`.appendReasoningSignature`.
          guard let candidate = response.candidates.first else {
            AILog.error(code: .generateContentResponseNoCandidates, """
            Could not parse response because the response has no candidates.
            """)
            throw GenerateContentError.internalError(underlying: InvalidCandidateError.emptyContent(
              underlyingError: Candidate.EmptyContentError()
            ))
          }

          let toolCallsID = UUID().uuidString
          for part in candidate.content.parts {
            switch part {
            case let textPart as TextPart:
              if textPart.isThought {
                await channel
                  .send(
                    .reasoning(
                      entryID: responseEntryID,
                      action: .appendText(
                        textPart.text,
                        tokenCount: 0
                      )
                    )
                  )
              } else {
                await channel.send(
                  .response(
                    entryID: responseEntryID,
                    action: .appendText(textPart.text, tokenCount: 0)
                  )
                )
              }
            case let inlineDataPart as InlineDataPart:
              let action: LanguageModelExecutorGenerationChannel.Response.Action
              // Handle the special case for image generation.
              switch inlineDataPart.mimeType {
              case "image/png", "image/jpeg":
                if let cgImage = cgImage(fromData: inlineDataPart.data) {
                  let imageAttachment = Transcript.ImageAttachment(cgImage)
                  let attachmentSegment = Transcript.AttachmentSegment(content:
                    .image(imageAttachment))
                  action = .addAttachmentSegment(attachmentSegment)
                } else {
                  action = .updateCustomSegment(inlineDataPart)
                }
              default:
                action = .updateCustomSegment(inlineDataPart)
              }

              await channel.send(.response(entryID: responseEntryID, action: action))
            case let fileDataPart as FileDataPart:
              await channel.send(
                .response(
                  entryID: responseEntryID,
                  action: .updateCustomSegment(fileDataPart)
                )
              )
            case let functionCallPart as FunctionCallPart:
              try await channel.send(
                .toolCalls(
                  entryID: toolCallsID,
                  action: .toolCall(
                    id: functionCallPart
                      .functionId ?? "\(Executor.placeholderIDPrefix)-\(UUID().uuidString)",
                    name: functionCallPart.name,
                    action: .appendArguments(
                      functionCallPart.args.jsonString(),
                      tokenCount: 0
                    )
                  )
                )
              )

              if let thoughtSignature = part.thoughtSignature?.data(using: .utf8) {
                await channel.send(
                  .reasoning(
                    entryID: toolCallsID,
                    action: .updateSignature(thoughtSignature, tokenCount: 0)
                  )
                )
              }
            case let executableCodePart as ExecutableCodePart:
              await channel.send(
                .response(
                  entryID: responseEntryID,
                  action: .updateCustomSegment(executableCodePart)
                )
              )
            case let codeExecutionResultPart as CodeExecutionResultPart:
              await channel.send(
                .response(
                  entryID: responseEntryID,
                  action: .updateCustomSegment(codeExecutionResultPart)
                )
              )
            default:
              // Intentionally ommitted that never come back from the server:
              //   - FunctionResponsePart

              // This should never happen ;) we filter out non recognized parts already.
              AILog.warning(
                code: .unrecognizedResponsePartType,
                "Unexpected part: \(part). Skipping."
              )
            }
          }

          // Handle additional metadata from the candidate
          var updatedMetadata: [String: any Sendable & Codable & Equatable] = [:]
          if let groundingMetadata = candidate.groundingMetadata {
            updatedMetadata[CandidateKeys.groundingMetadata] = groundingMetadata
          }

          if let citationMetadata = candidate.citationMetadata {
            updatedMetadata[CandidateKeys.citationMetadata] = citationMetadata
          }

          if let urlContextMetadata = candidate.urlContextMetadata {
            updatedMetadata[CandidateKeys.urlContextMetadata] = urlContextMetadata
          }

          if let finishReason = candidate.finishReason {
            updatedMetadata[CandidateKeys.finishReason] = finishReason
          }

          if let finishMessage = candidate.finishMessage {
            updatedMetadata[CandidateKeys.finishMessage] = finishMessage
          }

          if !candidate.safetyRatings.isEmpty {
            updatedMetadata[CandidateKeys.safetyRatings] = candidate.safetyRatings
          }

          if !updatedMetadata.isEmpty {
            await channel
              .send(
                .response(
                  entryID: responseEntryID,
                  action: .updateMetadata(updatedMetadata)
                )
              )
          }

          if let usageMetadata = response.usageMetadata {
            let includesThoughts = usageMetadata.totalTokenCount > 0 &&
              usageMetadata
              .totalTokenCount <=
              (usageMetadata.promptTokenCount + usageMetadata.candidatesTokenCount)
            let outputTotalTokenCount = includesThoughts
              ? usageMetadata.candidatesTokenCount
              : usageMetadata.candidatesTokenCount + usageMetadata.thoughtsTokenCount

            let input = LanguageModelExecutorGenerationChannel.Usage.Input(
              totalTokenCount: usageMetadata.promptTokenCount,
              cachedTokenCount: usageMetadata.cachedContentTokenCount
            )
            let output = LanguageModelExecutorGenerationChannel.Usage.Output(
              totalTokenCount: outputTotalTokenCount,
              reasoningTokenCount: usageMetadata.thoughtsTokenCount
            )
            await channel.send(
              .response(
                entryID: responseEntryID,
                action: .updateUsage(
                  .init(input: input, output: output)
                )
              )
            )
          }
        }
      }

      private func cgImage(fromData data: Data) -> CGImage? {
        #if canImport(ImageIO)
          guard let source = CGImageSourceCreateWithData(data as CFData, nil)
          else { return nil }
          return CGImageSourceCreateImageAtIndex(source, 0, nil)
        #else
          return nil
        #endif
      }
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension JSONObject {
    init(_ jsonString: String) throws {
      guard let jsonData = jsonString.data(using: .utf8) else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: [],
            debugDescription: "Unable to convert JSON string to UTF-8 data."
          )
        )
      }
      self = try JSONDecoder().decode(JSONObject.self, from: jsonData)
    }

    func jsonString() throws -> String {
      let jsonData = try JSONEncoder().encode(self)
      guard let string = String(data: jsonData, encoding: .utf8) else {
        throw EncodingError.invalidValue(
          self,
          EncodingError.Context(
            codingPath: [],
            debugDescription: "Unable to represent JSON data as a UTF-8 string."
          )
        )
      }
      return string
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.Instructions {
    func toGeminiSystemInstruction() throws -> ModelContent? {
      var instructions = ""
      for segment in segments {
        switch segment {
        case let .text(text):
          instructions.append(text.content)
        case let .structure(structure):
          instructions.append(
            """
            ```
            \(structure.content.jsonString)
            ```
            """
          )
        case let .attachment(attachment):
          throw LanguageModelError.unsupportedTranscriptContent(
            LanguageModelError.UnsupportedTranscriptContent(
              unsupportedContent: [Transcript.Entry.instructions(self)],
              debugDescription: "Unsupported attachment segment in instructions: \(attachment)"
            )
          )
        case let .custom(customSegment):
          throw LanguageModelError.unsupportedTranscriptContent(
            LanguageModelError.UnsupportedTranscriptContent(
              unsupportedContent: [Transcript.Entry.instructions(self)],
              debugDescription: "Unsupported custom segment in instructions: \(customSegment)"
            )
          )
        @unknown default:
          // TODO: Determine whether to throw
          AILog.warning(
            code: .unrecognizedSegmentType,
            "Skipping unknown segment type: \(segment)"
          )
        }
      }

      if instructions.isEmpty {
        return nil
      }

      return ModelContent(role: "system", parts: instructions)
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.Prompt {
    func toGeminiPrompt() throws -> ModelContent {
      var parts = [any Part]()
      for segment in segments {
        switch segment {
        case let .text(text):
          parts.append(TextPart(text.content))
        case let .structure(structure):
          parts.append(
            TextPart(
              """
              ```
              \(structure.content.jsonString)
              ```
              """
            )
          )
        case let .attachment(attachment):
          switch attachment.content {
          case let .image(imageAttachment):
            // TODO: Determine if CGImage is available and can be converted to a JPEG on watchOS.
            #if !os(watchOS)
              parts.append(contentsOf: imageAttachment.cgImage.partsValue)
            #endif // !os(watchOS)
          @unknown default:
            // TODO: Handle this
            AILog.warning(
              code: .unrecognizedSegmentType,
              "Unknown default attachment content, skipping"
            )
            continue
          }
        case let .custom(customSegment):
          throw LanguageModelError.unsupportedTranscriptContent(
            LanguageModelError.UnsupportedTranscriptContent(
              unsupportedContent: [Transcript.Entry.prompt(self)],
              debugDescription: "Unsupported custom segment in prompt: \(customSegment)"
            )
          )
        @unknown default:
          // TODO: Determine whether to throw
          AILog.warning(
            code: .unrecognizedSegmentType,
            "Skipping unknown segment type: \(segment)"
          )
        }
      }

      return ModelContent(role: "user", parts: parts)
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.Response {
    func toGeminiResponse() throws -> ModelContent {
      var parts = [any Part]()
      for segment in segments {
        switch segment {
        case let .text(text):
          parts.append(TextPart(text.content))
        case let .structure(structure):
          parts.append(
            TextPart(
              """
              ```
              \(structure.content.jsonString)
              ```
              """
            )
          )
        // TODO: Handle image segments in responses for editing use cases
        case let .attachment(attachment):
          throw LanguageModelError.unsupportedTranscriptContent(
            LanguageModelError.UnsupportedTranscriptContent(
              unsupportedContent: [Transcript.Entry.response(self)],
              debugDescription: "Unsupported attachment segment in response: \(attachment)"
            )
          )
        case let .custom(customSegment):
          throw LanguageModelError.unsupportedTranscriptContent(
            LanguageModelError.UnsupportedTranscriptContent(
              unsupportedContent: [Transcript.Entry.response(self)],
              debugDescription: "Unsupported custom segment in response: \(customSegment)"
            )
          )
        @unknown default:
          // TODO: Determine whether to throw
          AILog.warning(
            code: .unrecognizedSegmentType,
            "Skipping unknown segment type: \(segment)"
          )
        }
      }

      return ModelContent(role: "model", parts: parts)
    }
  }
#endif // compiler(>=6.4) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
