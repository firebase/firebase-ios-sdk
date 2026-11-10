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

import AVFoundation
@testable import struct FirebaseAILogic.APIConfig

// Each test has a `timeLimit(_:)` so a hung test fails instead of stalling the CI job. The trait
// can't be applied to the suite because it requires iOS 16, which is newer than the deployment
// target, and suites can't be marked `@available`.
@Suite(.serialized)
struct LiveSessionTests {
  /// Arguments for running a test against each supported Live model on each backend.
  ///
  /// Gemini 2.5 Live models will be removed after they're retired.
  private static let arguments = InstanceConfig.liveConfigs.flatMap { config in
    switch config.apiConfig.service {
    case .agentPlatform:
      [
        (config, ModelNames.gemini2_5_FlashLive),
        (config, ModelNames.gemini3_8_Live),
      ]
    case .googleAI:
      [
        (config, ModelNames.gemini2_5_FlashLivePreview),
        (config, ModelNames.gemini3_8_Live),
      ]
    }
  }

  /// Arguments for tests that rely on `voiceActivity` messages, which are only sent by Gemini 3.x
  /// Live models.
  private static let voiceActivityArguments = InstanceConfig.liveConfigs.map { config in
    (config, ModelNames.gemini3_8_Live)
  }

  private let oneSecondInNanoseconds = UInt64(1e+9)

  /// Silence to send after speech so that automatic activity detection signals the end of it.
  ///
  /// The model doesn't respond until it detects the end of the user's speech. With the default
  /// configuration, Gemini 3.x Live models require more than one second of silence for that.
  private let endOfSpeechSilence = generateRawPCMSilence(duration: 3)
  private let tools: [GenerativeModel.Tool] = [
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
  private let generationConfig = LiveGenerationConfig(
    responseModalities: [.audio],
    outputAudioTranscription: AudioTranscriptionConfig()
  )

  private let sessionResumptionGenerationConfig = LiveGenerationConfig(
    responseModalities: [.audio],
    outputAudioTranscription: AudioTranscriptionConfig(),
    // context window with the minimum values, just to ensure it doesn't cause any issues
    // when resuming sessions
    contextWindowCompression: ContextWindowCompressionConfig(
      triggerTokens: 5000,
      slidingWindow: SlidingWindow(
        targetTokens: 1000,
      )
    )
  )

  private enum SystemInstructions {
    static let yesOrNo = ModelContent(
      role: "system",
      parts: """
      You can only respond with "yes" or "no".
      """.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    static let nameTracker = ModelContent(
      role: "system",
      parts: """
      You are a name tracker. By default, the name is "Michael". When told a different name, \
      replace the old name with the new one, and keep track of it. When asked for the name, only \
      respond with the newest name. For any other message, do not respond with anything. \
      Furthermore, do not respond to this message either.
      """.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    static let helloGoodbye = ModelContent(
      role: "system",
      parts: """
      When you hear "Hello" say "Goodbye". If you hear anything else, say "The audio file is \
      broken".
      """.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    static let helloCount = ModelContent(
      role: "system",
      parts: """
      Tell me how many times you hear "Hello" (not including these instructions). Only respond with \
      the number, nothing else. If you hear anything else, say "The audio file is broken".
      """.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    static let lastNames = ModelContent(
      role: "system",
      parts: """
      When you receive a message, if the message is a single word, assume it's the first name of a \
      person, and call the getLastName tool to get the last name of said person. Once you get the \
      response, say the response.
      """.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    static let animalInVideo = ModelContent(
      role: "system",
      parts: """
      Send a one word response of what ANIMAL is in the video. \
      If you don't receive a video, send "Test is broken, I didn't receive a video.".
      """.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    /// Makes the model's response long enough to be interrupted.
    static let countSlowly = ModelContent(
      role: "system",
      parts: """
      Whenever you hear someone speak, slowly count out loud from one to twenty.
      """.trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments)
  func sendAudioRealtime_receiveAudioOutputTranscripts(_ config: InstanceConfig,
                                                       modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: generationConfig,
      systemInstruction: SystemInstructions.helloGoodbye
    )

    try await model.withSession { session in
      let audioFile = try #require(
        NSDataAsset(name: "hello"), "Missing audio file 'hello.wav' in Assets"
      )
      await session.sendAudioRealtime(audioFile.data)
      await session.sendAudioRealtime(endOfSpeechSilence)

      let text = try #require(
        try await session.tryCollectNextValidAudioOutputTranscript(),
        "Model did not respond in time with a non empty response"
      )

      let modelResponse = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: .punctuationCharacters)
        .lowercased()

      #expect(modelResponse == "goodbye")
    }
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments)
  func sendVideoRealtime_receiveAudioOutputTranscripts(_ config: InstanceConfig,
                                                       modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: generationConfig,
      systemInstruction: SystemInstructions.animalInVideo
    )

    try await model.withSession { session in
      guard let videoFile = NSDataAsset(name: "cat") else {
        Issue.record("Missing video file 'cat' in Assets")
        return
      }

      let frames = try await videoFile.videoFrames()
      for frame in frames {
        await session.sendVideoRealtime(frame, mimeType: "image/png")
      }

      // the model doesn't respond unless we send some audio too
      // vertex also responds if you send text, but google ai doesn't
      // (they both respond with audio though)
      guard let audioFile = NSDataAsset(name: "hello") else {
        Issue.record("Missing audio file 'hello.wav' in Assets")
        return
      }
      await session.sendAudioRealtime(audioFile.data)
      await session.sendAudioRealtime(endOfSpeechSilence)

      // Responses to video input can take longer than the default timeout.
      let text = try #require(
        try await session.tryCollectNextValidAudioOutputTranscript(timeout: 10),
        "Model did not respond in time with a non empty response"
      )

      let modelResponse = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: .punctuationCharacters)
        .lowercased()

      // model response varies
      #expect(["kitten", "cat", "kitty"].contains(modelResponse))
    }
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments)
  func realtime_functionCalling(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: generationConfig,
      tools: tools,
      systemInstruction: SystemInstructions.lastNames
    )

    try await model.withSession { session in
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
      let text = try #require(
        try await session.tryCollectNextValidAudioOutputTranscript(),
        "Model did not respond in time with a non empty response"
      )

      let modelResponse = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: .punctuationCharacters)
        .lowercased()

      #expect(modelResponse == "smith")
    }
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments)
  func realtime_manual_sessionResumption(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: sessionResumptionGenerationConfig,
      systemInstruction: SystemInstructions.nameTracker
    )

    let newHandle = try await model.withSession(
      sessionResumption: SessionResumptionConfig()
    ) { session in
      await session.sendTextRealtime("My name is Alex.")
      return try await session.collectNextSessionHandle()
    }
    guard let newHandle else {
      return
    }

    // `withSession` ensures the session is closed before attempting to resume.
    let text = try await model.withSession(
      sessionResumption: SessionResumptionConfig(handle: newHandle)
    ) { session in
      await session.sendTextRealtime("What is my name?")

      return try #require(
        try await session.tryCollectNextValidAudioOutputTranscript(),
        "Model did not respond in time with a non empty response"
      )
    }

    let modelResponse = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .lowercased()

    #expect(modelResponse == "alex")
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments)
  // baseline test to ensure the model isn't retaining context automatically; which would invalidate
  // our other sessionResumption tests
  func realtime_sessionResumption_disabled(_ config: InstanceConfig,
                                           modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: sessionResumptionGenerationConfig,
      systemInstruction: SystemInstructions.nameTracker
    )

    try await model.withSession(sessionResumption: SessionResumptionConfig()) { session in
      await session.sendTextRealtime("My name is Alex.")
      // Wait until the server has processed the message before closing the session; otherwise
      // the message might never be sent, and the test would pass without proving anything.
      _ = try await session.collectNextSessionHandle()
    }

    // re-connect without specifying the new handle (so it should be a new session)
    let text = try await model.withSession(
      sessionResumption: SessionResumptionConfig()
    ) { session in
      await session.sendTextRealtime("What is my name?")

      return try #require(
        try await session.tryCollectNextValidAudioOutputTranscript(),
        "Model did not respond in time with a non empty response"
      )
    }

    let modelResponse = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .lowercased()

    // the default name per the system instructions
    #expect(modelResponse == "michael")
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments)
  func realtime_resumeSession(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: sessionResumptionGenerationConfig,
      systemInstruction: SystemInstructions.nameTracker
    )

    let text = try await model.withSession(
      sessionResumption: SessionResumptionConfig()
    ) { session -> String? in
      await session.sendTextRealtime("My name is Alex.")

      guard let newHandle = try await session.collectNextSessionHandle() else {
        return nil
      }

      await session.close()
      try await session.resumeSession(
        sessionResumption: SessionResumptionConfig(handle: newHandle)
      )

      await session.sendTextRealtime("What is my name?")

      // Unwrap before returning; returning `#require` directly from a `String?` closure would
      // make it check a `String??`, which is never `nil`.
      let transcript = try #require(
        try await session.tryCollectNextValidAudioOutputTranscript(),
        "Model did not respond in time with a non empty response"
      )
      return transcript
    }
    guard let text else {
      return
    }

    let modelResponse = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .lowercased()

    #expect(modelResponse == "alex")
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(
    .timeLimit(.minutes(1)),
    arguments: arguments.filter { config, modelName in
      switch config.apiConfig.service {
      case .googleAI:
        true
      case .agentPlatform:
        // TODO: (b/450982184) Remove when Agent Platform adds support for Function IDs and
        // Cancellation in Gemini 2.5 Live models.
        modelName != ModelNames.gemini2_5_FlashLive
      }
    }
  )
  func realtime_functionCalling_cancellation(_ config: InstanceConfig,
                                             modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: generationConfig,
      tools: tools,
      systemInstruction: SystemInstructions.lastNames
    )

    try await model.withSession { session in
      await session.sendTextRealtime("Alex")

      guard let toolCall = try await session.collectNextToolCall() else {
        return
      }

      let functionCalls = try #require(toolCall.functionCalls)

      #expect(functionCalls.count == 1)
      let functionCall = try #require(functionCalls.first)
      let id = try #require(functionCall.functionId)

      await session.sendTextRealtime("Actually, I don't care about the last name of Alex anymore.")

      // TODO: Remove the known issue once the SDK supports `FunctionDeclaration.behavior`, and test
      // a `BLOCKING` function on Gemini 3.8 Live instead. Gemini 3.8 Live calls functions with
      // `NON_BLOCKING` behavior by default, and only cancels `BLOCKING` calls automatically.
      try await withKnownIssue("Gemini 3.8 Live doesn't cancel non-blocking function calls") {
        // Without a timeout, this test would hang if the model never cancels the function call.
        let cancellation = try await withTimeout(seconds: 10) {
          () -> LiveServerToolCallCancellation? in
          for try await cancellation in session.responsesOf(LiveServerToolCallCancellation.self) {
            return cancellation
          }
          return nil
        } ?? nil

        let cancelledCall = try #require(
          cancellation,
          "Model did not cancel the function call in time"
        )
        #expect(cancelledCall.ids == [id])
      } when: {
        modelName == ModelNames.gemini3_8_Live
      }
    }
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments.filter { !$0.0.useLimitedUseAppCheckTokens })
  // Getting a limited use token adds too much of an overhead; we can't interrupt the model in time
  func realtime_interruption(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: generationConfig,
      systemInstruction: SystemInstructions.countSlowly
    )

    let audioFile = try #require(
      NSDataAsset(name: "hello"), "Missing audio file 'hello.wav' in Assets"
    )

    try await retry(times: 3, delayInSeconds: 2.0) {
      try await model.withSession { session in
        await session.sendAudioRealtime(audioFile.data)
        await session.sendAudioRealtime(endOfSpeechSilence)

        // Wait a second to allow the model to start generating (and cause a proper interruption)
        try await Task.sleep(nanoseconds: oneSecondInNanoseconds)
        await session.sendAudioRealtime(audioFile.data)
        await session.sendAudioRealtime(endOfSpeechSilence)

        for try await content in session.responsesOf(LiveServerContent.self) {
          if content.wasInterrupted {
            break
          }

          if content.isTurnComplete {
            throw NoInterruptionError()
          }
        }
      }
    }
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments)
  func incremental_works(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: generationConfig,
      systemInstruction: SystemInstructions.yesOrNo
    )

    try await model.withSession { session in
      await session.sendContent("Does five plus")
      await session.sendContent(" five equal ten?", turnComplete: true)

      let text = try #require(
        try await session.tryCollectNextValidAudioOutputTranscript(),
        "Model did not respond in time with a non empty response"
      )

      let modelResponse = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: .punctuationCharacters)
        .lowercased()

      #expect(modelResponse == "yes")
    }
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments)
  func realtime_speechConfig(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: LiveGenerationConfig(
        responseModalities: [.audio],
        speech: SpeechConfig(voiceName: "Charon", languageCode: "en-US"),
        outputAudioTranscription: AudioTranscriptionConfig(),
      ),
      systemInstruction: SystemInstructions.yesOrNo
    )

    try await model.withSession { session in
      await session.sendTextRealtime("does five plus five equal ten?")

      let text = try #require(
        try await session.tryCollectNextValidAudioOutputTranscript(),
        "Model did not respond in time with a non empty response"
      )

      let modelResponse = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: .punctuationCharacters)
        .lowercased()

      #expect(modelResponse == "yes")
    }
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

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments)
  func realtime_automaticActivityDetection_disabled(_ config: InstanceConfig,
                                                    modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: LiveGenerationConfig(
        responseModalities: [.audio],
        outputAudioTranscription: AudioTranscriptionConfig(),
        realtimeInputConfig: RealtimeInputConfig(
          automaticActivityDetection: ActivityDetectionConfig.disabled()
        )
      ),
      systemInstruction: SystemInstructions.helloCount
    )

    try await model.withSession { session in
      let audioFile = try #require(
        NSDataAsset(name: "hello"), "Missing audio file 'hello.wav' in Assets"
      )
      let silentData = generateRawPCMSilence(duration: 1)

      await session.sendStartActivityRealtime()

      await session.sendAudioRealtime(audioFile.data)
      await session.sendAudioRealtime(silentData)

      try await Task.sleep(nanoseconds: oneSecondInNanoseconds)

      await session.sendAudioRealtime(audioFile.data)
      await session.sendAudioRealtime(silentData)

      await session.sendStopActivityRealtime()

      let text = try #require(
        try await session.tryCollectNextValidAudioOutputTranscript(),
        "Model did not respond in time with a non empty response"
      )

      let modelResponse = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: .punctuationCharacters)
        .lowercased()

      // TODO: Investigate why Gemini 3.8 Live sometimes counts more than two "Hello"s when automatic
      // activity detection is disabled, then remove the known issue.
      withKnownIssue("Gemini 3.8 Live miscounts the number of times it hears Hello",
                     isIntermittent: true) {
        #expect(modelResponse == "2")
      } when: {
        modelName == ModelNames.gemini3_8_Live
      }
    }
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: arguments)
  func realtime_automaticActivityDetection_enabled(_ config: InstanceConfig,
                                                   modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: LiveGenerationConfig(
        responseModalities: [.audio],
        outputAudioTranscription: AudioTranscriptionConfig(),
        realtimeInputConfig: RealtimeInputConfig(
          automaticActivityDetection: ActivityDetectionConfig(
            silenceDuration: 0.1,
          ),
          activityHandling: .noInterrupt
        )
      ),
      systemInstruction: SystemInstructions.helloCount
    )

    try await model.withSession { session in
      let audioFile = try #require(
        NSDataAsset(name: "hello"), "Missing audio file 'hello.wav' in Assets"
      )

      let silentData = generateRawPCMSilence(duration: 1)

      await session.sendAudioRealtime(audioFile.data)
      await session.sendAudioRealtime(silentData)

      try await Task.sleep(nanoseconds: oneSecondInNanoseconds)

      await session.sendAudioRealtime(audioFile.data)
      await session.sendAudioRealtime(silentData)

      let text = try #require(
        try await session.tryCollectNextValidAudioOutputTranscript(),
        "Model did not respond in time with a non empty response"
      )

      let modelResponse = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: .punctuationCharacters)
        .lowercased()

      #expect(modelResponse == "1")
    }
  }

  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Required by `timeLimit(_:)`.
  @Test(.timeLimit(.minutes(1)), arguments: voiceActivityArguments)
  func realtime_voiceActivity(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).liveModel(
      modelName: modelName,
      generationConfig: generationConfig,
      systemInstruction: SystemInstructions.helloGoodbye
    )

    try await model.withSession { session in
      let audioFile = try #require(
        NSDataAsset(name: "hello"), "Missing audio file 'hello.wav' in Assets"
      )
      await session.sendAudioRealtime(audioFile.data)
      await session.sendAudioRealtime(endOfSpeechSilence)

      let turn = try #require(
        try await session.tryCollectNextTurnWithVoiceActivity(),
        "Model did not respond in time with a non empty response"
      )


      // The server should signal both the start and the end of the user's speech.
      let receivedTypes = turn.voiceActivities.map(\.type)
      let activityStart = try #require(
        turn.voiceActivities.first { $0.type == .start },
        "Missing ACTIVITY_START voice activity; received: \(receivedTypes)"
      )
      let activityEnd = try #require(
        turn.voiceActivities.first { $0.type == .end },
        "Missing ACTIVITY_END voice activity; received: \(receivedTypes)"
      )
      #expect(activityStart.audioOffset >= 0)
      #expect(activityEnd.audioOffset >= activityStart.audioOffset)

      // Voice activity messages must not terminate the `responses` stream; the model's response to
      // the audio should still be received after them.
      let modelResponse = turn.transcript
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: .punctuationCharacters)
        .lowercased()

      #expect(modelResponse == "goodbye")
    }
  }
}

private extension LiveGenerativeModel {
  /// Starts a ``LiveSession``, passes it to `body`, and closes it when `body` returns or throws.
  ///
  /// Use this instead of ``connect(sessionResumption:)`` so that a failing test, such as one that
  /// fails a `#require` expectation, doesn't leave its session connected. Open sessions count
  /// toward the backend's concurrent session quota, which can cause other tests to fail.
  ///
  /// - Parameters:
  ///   - sessionResumption: Optional configuration for session resumption.
  ///   - body: A closure that uses the connected session.
  /// - Returns: The value returned by `body`.
  /// - Throws: Any error thrown while connecting, or by `body`.
  func withSession<T>(sessionResumption: SessionResumptionConfig? = nil,
                      _ body: (LiveSession) async throws -> T) async throws -> T {
    let session = try await connect(sessionResumption: sessionResumption)
    do {
      let result = try await body(session)
      await session.close()
      return result
    } catch {
      await session.close()
      throw error
    }
  }
}

private extension LiveSession {
  /// Collects the next non empty audio output transcript that the model sends, returning nil if it
  /// takes longer than the timeout.
  ///
  /// Basically the same as ``collectNextAudioOutputTranscript``, but this method will timeout if it
  /// takes too long, and
  /// will make sure you don't get an empty intermediary response back.
  func tryCollectNextValidAudioOutputTranscript(timeout: TimeInterval = 5.0) async throws
    -> String? {
    let response = try await withTimeout(seconds: timeout) {
      var text = ""
      for try await content in self.responsesOf(LiveServerContent.self) {
        text += content.outputAudioText()
        if content.isTurnComplete {
          if !text.isEmpty {
            break
          }
        }
      }
      return text
    }

    // if the model terminated early, we could get an empty string back
    guard let response, !response.isEmpty else {
      return nil
    }

    return response
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

  /// Collects the voice activity signals and the audio output transcript that the model sends for
  /// the next turn, returning `nil` if it takes longer than the timeout.
  ///
  /// Similar to ``tryCollectNextValidAudioOutputTranscript``, this will make sure that you don't
  /// get an empty intermediary response back.
  func tryCollectNextTurnWithVoiceActivity(timeout: TimeInterval = 10.0) async throws
    -> TurnWithVoiceActivity? {
    let turn = try await withTimeout(seconds: timeout) {
      var turn = TurnWithVoiceActivity()
      for try await content in self.responsesOf(LiveServerContent.self) {
        if let voiceActivity = content.voiceActivity {
          turn.voiceActivities.append(voiceActivity)
        }
        turn.transcript += content.outputAudioText()
        if content.isTurnComplete, !turn.transcript.isEmpty {
          return turn
        }
      }
      return turn
    }

    // if the model terminated early, we could get an empty transcript back
    guard let turn, !turn.transcript.isEmpty else {
      return nil
    }

    return turn
  }

  /// Collects the next session handle via the `LiveSessionResumptionUpdate` message.
  ///
  /// A handle will only be yielded if the the server marks the session as resumable, and a new
  /// handle is actually provided in the message.
  func collectNextSessionHandle() async throws -> String? {
    for try await update in responsesOf(LiveSessionResumptionUpdate.self) {
      guard let handle = update.newHandle, update.resumable else {
        continue
      }
      return handle
    }

    return nil
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
        error += content.outputAudioText()

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
  /// Is the equivalent to manually doing:
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
      case let .sessionResumptionUpdate(update):
        if let casted = update as? T {
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

private struct NoInterruptionError: Error,
  CustomStringConvertible {
  var description: String { "The model never sent an interrupted message." }
}

/// The voice activity signals and the audio output transcript that the model sent for a turn.
private struct TurnWithVoiceActivity: Sendable {
  var voiceActivities = [LiveServerVoiceActivity]()
  var transcript = ""
}

extension LiveServerContent {
  /// Text of the output `LiveAudioTranscript`, or an empty string if it's missing.
  func outputAudioText() -> String {
    outputAudioTranscription?.text ?? ""
  }
}

/// Generate silent audio data that has a specific duration.
func generateRawPCMSilence(duration: TimeInterval) -> Data {
  // gemini uses 16khz mono
  let sampleRate = 16000
  // gemini uses 16-bit
  let bytesPerSample = 2

  let totalSamples = Int(duration * Double(sampleRate))
  let totalBytes = totalSamples * bytesPerSample
  return Data(repeating: 0, count: totalBytes)
}
