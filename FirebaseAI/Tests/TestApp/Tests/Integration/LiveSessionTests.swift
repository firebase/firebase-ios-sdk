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

import FirebaseAILogic
import FirebaseAITestApp
import SwiftUI
import Testing

@testable import struct FirebaseAILogic.APIConfig

@Suite(.serialized)
struct LiveSessionTests {
  private static let arguments = InstanceConfig.liveConfigs.flatMap { config in
    switch config.apiConfig.service {
    case .vertexAI:
      [
        (config, ModelNames.gemini2FlashLivePreview),
      ]
    case .googleAI:
      [
        (config, ModelNames.gemini2FlashLive),
        (config, ModelNames.gemini2_5_FlashLivePreview),
      ]
    }
  }

  private let oneSecondInNanoseconds = UInt64(1e+9)
  private let tools: [Tool] = [
    .functionDeclarations([
      FunctionDeclaration(
        name: "getLastName",
        description: "Gets the last name of a person.",
        parameters: [
          "firstName": .string(
            description: "The first name of the person to lookup."
          ),
        ]
      ),
    ]),
  ]
  private let textConfig = LiveGenerationConfig(
    responseModalities: [.text]
  )
  private let audioConfig = LiveGenerationConfig(
    responseModalities: [.audio],
    outputAudioTranscription: AudioTranscriptionConfig()
  )

  private enum SystemInstructions {
    static let yesOrNo = ModelContent(
      role: "system",
      parts: """
        You can only respond with "yes" or "no".
      """.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    static let helloGoodbye = ModelContent(
      role: "system",
      parts: """
        When you hear "Hello" say "Goodbye". If you hear anything else, say "The audio file is broken".
      """.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    static let lastNames = ModelContent(
      role: "system",
      parts: "When you receive a message, if the message is a single word, assume it's the first name of a person, and call the getLastName tool to get the last name of said person. Only respond with the last name."
    )
  }

  @Test(arguments: arguments)
  func sendTextRealtime_receiveText(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: textConfig,
      systemInstruction: SystemInstructions.yesOrNo
    )

    let session = try await model.connect()
    await session.sendTextRealtime("Does five plus five equal ten?")

    let text = try await session.collectNextTextResponse()

    await session.close()
    let modelResponse = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .lowercased()

    #expect(modelResponse == "yes")
  }

  @Test(arguments: arguments)
  func sendTextRealtime_receiveAudioOutputTranscripts(_ config: InstanceConfig,
                                                      modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: audioConfig,
      systemInstruction: SystemInstructions.yesOrNo
    )

    let session = try await model.connect()
    await session.sendTextRealtime("Does five plus five equal ten?")

    let text = try await session.collectNextAudioOutputTranscript()

    await session.close()
    let modelResponse = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .lowercased()

    #expect(modelResponse == "yes")
  }

  @Test(arguments: arguments)
  func sendAudioRealtime_receiveAudioOutputTranscripts(_ config: InstanceConfig,
                                                       modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: audioConfig,
      systemInstruction: SystemInstructions.helloGoodbye
    )

    let session = try await model.connect()

    guard let audioFile = NSDataAsset(name: "hello") else {
      Issue.record("Missing audio file 'hello.wav' in Assets")
      return
    }
    await session.sendAudioRealtime(audioFile.data)
    // The model can't infer that we're done speaking until we send null bytes
    await session.sendAudioRealtime(Data(repeating: 0, count: audioFile.data.count))

    let text = try await session.collectNextAudioOutputTranscript()

    await session.close()
    let modelResponse = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .lowercased()

    #expect(modelResponse == "goodbye")
  }

  @Test(arguments: arguments)
  func sendAudioRealtime_receiveText(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: textConfig,
      systemInstruction: SystemInstructions.helloGoodbye
    )

    let session = try await model.connect()

    guard let audioFile = NSDataAsset(name: "hello") else {
      Issue.record("Missing audio file 'hello.wav' in Assets")
      return
    }
    await session.sendAudioRealtime(audioFile.data)
    await session.sendAudioRealtime(Data(repeating: 0, count: audioFile.data.count))

    let text = try await session.collectNextTextResponse()

    await session.close()
    let modelResponse = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .lowercased()

    #expect(modelResponse == "goodbye")
  }

  @Test(arguments: arguments)
  func realtime_functionCalling(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: textConfig,
      tools: tools,
      systemInstruction: SystemInstructions.lastNames
    )

    let session = try await model.connect()
    await session.sendTextRealtime("Alex")

    guard let toolCall = try await session.collectNextToolCall() else {
      return
    }

    let functionCalls = try #require(toolCall.functionCalls)

    #expect(functionCalls.count == 1)
    let functionCall = try #require(functionCalls.first)

    #expect(functionCall.name == "getLastName")
    guard let response = getLastName(args: functionCall.args) else {
      return
    }
    await session.sendFunctionResponses([
      FunctionResponsePart(
        name: functionCall.name,
        response: ["lastName": .string(response)],
        functionId: functionCall.functionId
      ),
    ])

    var text = try await session.collectNextTextResponse()
    if text.isEmpty {
      // The model sometimes sends an empty text response first
      text = try await session.collectNextTextResponse()
    }

    await session.close()
    let modelResponse = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .lowercased()

    #expect(modelResponse == "smith")
  }

  @Test(arguments: arguments.filter {
    // TODO: (b/450982184) Remove when vertex adds support
    switch $0.0.apiConfig.service {
    case .googleAI:
      true
    case .vertexAI:
      false
    }
  })
  func realtime_functionCalling_cancellation(_ config: InstanceConfig,
                                             modelName: String) async throws {
    // TODO: (b/450982184) Remove when vertex adds support
    guard case .googleAI = config.apiConfig.service else {
      Issue.record("Vertex does not currently support function ids or function cancellation.")
      return
    }

    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: textConfig,
      tools: tools,
      systemInstruction: SystemInstructions.lastNames
    )

    let session = try await model.connect()
    await session.sendTextRealtime("Alex")

    guard let toolCall = try await session.collectNextToolCall() else {
      return
    }

    let functionCalls = try #require(toolCall.functionCalls)

    #expect(functionCalls.count == 1)
    let functionCall = try #require(functionCalls.first)
    let id = try #require(functionCall.functionId)

    await session.sendTextRealtime("Actually, I don't care about the last name of Alex anymore.")

    for try await cancellation in session.responsesOf(LiveServerToolCallCancellation.self) {
      #expect(cancellation.ids == [id])
      break
    }

    await session.close()
  }

  // Getting a limited use token adds too much of an overhead; we can't interrupt the model in time
  @Test(
    arguments: arguments.filter { !$0.0.useLimitedUseAppCheckTokens }
  )
  func realtime_interruption(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: audioConfig
    )

    let session = try await model.connect()

    guard let audioFile = NSDataAsset(name: "hello") else {
      Issue.record("Missing audio file 'hello.wav' in Assets")
      return
    }
    await session.sendAudioRealtime(audioFile.data)
    await session.sendAudioRealtime(Data(repeating: 0, count: audioFile.data.count))

    // wait a second to allow the model to start generating (and cuase a proper interruption)
    try await Task.sleep(nanoseconds: oneSecondInNanoseconds)
    await session.sendAudioRealtime(audioFile.data)
    await session.sendAudioRealtime(Data(repeating: 0, count: audioFile.data.count))

    for try await content in session.responsesOf(LiveServerContent.self) {
      if content.wasInterrupted {
        break
      }

      if content.isTurnComplete {
        Issue.record("The model never sent an interrupted message.")
        return
      }
    }
  }

  @Test(arguments: arguments)
  func incremental_works(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: textConfig,
      systemInstruction: SystemInstructions.yesOrNo
    )

    let session = try await model.connect()
    await session.sendContent("Does five plus")
    await session.sendContent(" five equal ten?", turnComplete: true)

    let text = try await session.collectNextTextResponse()

    await session.close()
    let modelResponse = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .lowercased()

    #expect(modelResponse == "yes")
  }

  private func getLastName(args: JSONObject) -> String? {
    guard case let .string(firstName) = args["firstName"] else {
      Issue.record("Missing 'firstName' argument: \(String(describing: args))")
      return nil
    }

    switch firstName {
    case "Alex": return "Smith"
    case "Bob": return "Johnson"
    default:
      Issue.record("Unsupported 'firstName': \(firstName)")
      return nil
    }
  }
}

private extension LiveSession {
  /// Collects the text that the model sends for the next turn.
  ///
  /// Will listen for `LiveServerContent` messages from the model,
  /// incrementally keeping track of any `TextPart`s it sends. Once
  /// the model signals that its turn is complete, the function will return
  /// a string concatenated of all the `TextPart`s.
  func collectNextTextResponse() async throws -> String {
    var text = ""

    for try await content in responsesOf(LiveServerContent.self) {
      text += content.modelTurn?.allText() ?? ""

      if content.isTurnComplete {
        break
      }
    }

    return text
  }

  /// Collects the audio output transcripts that the model sends for the next turn.
  ///
  /// Will listen for `LiveServerContent` messages from the model,
  /// incrementally keeping track of any `LiveAudioTranscription`s it sends.
  /// Once the model signals that its turn is complete, the function will return
  /// a string concatenated of all the `LiveAudioTranscription`s.
  func collectNextAudioOutputTranscript() async throws -> String {
    var text = ""

    for try await content in responsesOf(LiveServerContent.self) {
      text += content.outputAudioText()

      if content.isTurnComplete {
        break
      }
    }

    return text
  }

  /// Waits for the next `LiveServerToolCall` message from the model, and will return it.
  ///
  /// If the model instead sends `LiveServerContent`, the function will attempt to keep track of
  /// any messages it sends (either via `LiveAudioTranscription` or `TextPart`), and will
  /// record an issue describing the message.
  ///
  /// This is useful when testing function calling, as sometimes the model sends an error message,
  /// does something unexpected, or will attempt to get clarification. Logging the message (instead
  /// of just timing out), allows us to more easily debug such situations.
  func collectNextToolCall() async throws -> LiveServerToolCall? {
    var error = ""
    for try await response in responses {
      switch response.payload {
      case let .toolCall(toolCall):
        return toolCall
      case let .content(content):
        if let text = content.modelTurn?.allText() {
          error += text
        } else {
          error += content.outputAudioText()
        }

        if content.isTurnComplete {
          Issue.record("The model didn't send a tool call. Text received: \(error)")
          return nil
        }
      default:
        continue
      }
    }
    Issue.record("Failed to receive any responses")
    return nil
  }

  /// Filters responses from the model to a certain type.
  ///
  /// Useful when you only expect (or care about) certain types.
  ///
  /// ```swift
  /// for try await content in session.responsesOf(LiveServerContent.self) {
  ///   // ...
  /// }
  /// ```
  ///
  /// Is the equivelent to manually doing:
  /// ```swift
  /// for try await response in session.responses {
  ///   if case let .content(content) = response.payload {
  ///     // ...
  ///   }
  /// }
  /// ```
  func responsesOf<T>(_: T.Type) -> AsyncCompactMapSequence<AsyncThrowingStream<
    LiveServerMessage,
    any Error
  >, T> {
    responses.compactMap { response in
      switch response.payload {
      case let .content(content):
        if let casted = content as? T {
          return casted
        }
      case let .toolCall(toolCall):
        if let casted = toolCall as? T {
          return casted
        }
      case let .toolCallCancellation(cancellation):
        if let casted = cancellation as? T {
          return casted
        }
      case let .goingAwayNotice(goingAway):
        if let casted = goingAway as? T {
          return casted
        }
      }
      return nil
    }
  }
}

private extension ModelContent {
  /// A collection of text from all parts.
  ///
  /// If this doesn't contain any `TextPart`, then an empty
  /// string will be returned instead.
  func allText() -> String {
    parts.compactMap { ($0 as? TextPart)?.text }.joined()
  }
}

extension LiveServerContent {
  /// Text of the output `LiveAudioTranscript`, or an empty string if it's missing.
  func outputAudioText() -> String {
    outputAudioTranscription?.text ?? ""
  }
}
