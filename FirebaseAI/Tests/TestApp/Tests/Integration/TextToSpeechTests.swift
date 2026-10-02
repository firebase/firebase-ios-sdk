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

import FirebaseAILogic
import FirebaseAITestApp
import Testing

@Suite(.serialized)
struct TextToSpeechTests {
  private static let ttsModels = [
    ModelNames.gemini3_8_FlashTTS,
    ModelNames.gemini3_8_FlashLiteTTS,
  ]
  private let unaryMIMEType = "audio/wav"
  private let streamingMIMEType = "audio/l16; rate=24000; channels=1"

  // MARK: - Single-Speaker Tests

  @Test(arguments: InstanceConfig.defaultConfigs, ttsModels)
  func singleSpeaker_withTurnMetadata(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: GenerationConfig(
        responseModalities: [.audio],
        speechConfig: SpeechConfig(voiceName: "Kore")
      )
    )
    let prompt = TextPart(
      "Welcome aboard flight 412 with direct service to Tokyo Haneda.",
      speechMetadata: SpeechMetadata(style: "professional and welcoming")
    )

    let response = try await model.generateContent(prompt)

    let candidate = try #require(response.candidates.first)
    #expect(candidate.finishReason == .stop)
    let audioPart = try #require(candidate.content.parts.first as? InlineDataPart)
    #expect(!audioPart.data.isEmpty)
    #expect(audioPart.mimeType == unaryMIMEType)
  }

  @Test(arguments: InstanceConfig.defaultConfigs, ttsModels)
  func singleSpeakerStream_withTurnMetadata(_ config: InstanceConfig,
                                            modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: GenerationConfig(
        responseModalities: [.audio],
        speechConfig: SpeechConfig(voiceName: "Puck")
      )
    )
    let prompt = TextPart(
      "Deep in the ancient forest, a glowing stone lay hidden beneath the roots of the world tree.",
      speechMetadata: SpeechMetadata(style: "whispering and mysterious")
    )

    let responseStream = try model.generateContentStream(prompt)

    var receivedAudioDataCount = 0
    for try await chunk in responseStream {
      guard let candidate = chunk.candidates.first else { continue }
      if let audioPart = candidate.content.parts.first as? InlineDataPart {
        #expect(!audioPart.data.isEmpty)
        #expect(audioPart.mimeType == streamingMIMEType)
        receivedAudioDataCount += audioPart.data.count
      } else {
        #expect(candidate.finishReason == .stop, "Unexpected non-audio chunk: \(candidate)")
      }
    }
    #expect(receivedAudioDataCount > 0)
  }

  @Test(arguments: InstanceConfig.defaultConfigs, ttsModels)
  func singleSpeaker_withoutTurnMetadata(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: GenerationConfig(
        responseModalities: [.audio],
        speechConfig: SpeechConfig(voiceName: "Charon", languageCode: "fr-CA")
      )
    )

    let response = try await model.generateContent("Attache ta tuque!")

    let candidate = try #require(response.candidates.first)
    #expect(candidate.finishReason == .stop)
    let audioPart = try #require(candidate.content.parts.first as? InlineDataPart)
    #expect(!audioPart.data.isEmpty)
    #expect(audioPart.mimeType == unaryMIMEType)
  }

  @Test(arguments: InstanceConfig.defaultConfigs, ttsModels)
  func singleSpeakerStream_withoutTurnMetadata(_ config: InstanceConfig,
                                               modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: GenerationConfig(
        responseModalities: [.audio],
        speechConfig: SpeechConfig(voiceName: "Charon", languageCode: "en-GB")
      )
    )

    let responseStream = try model.generateContentStream("""
    Breaking news: The James Webb Space Telescope has detected signs of water vapour on a distant \
    exoplanet.
    """)

    var receivedAudioDataCount = 0
    for try await chunk in responseStream {
      guard let candidate = chunk.candidates.first else { continue }
      if let audioPart = candidate.content.parts.first as? InlineDataPart {
        #expect(!audioPart.data.isEmpty)
        #expect(audioPart.mimeType == streamingMIMEType)
        receivedAudioDataCount += audioPart.data.count
      } else {
        #expect(candidate.finishReason == .stop, "Unexpected non-audio chunk: \(candidate)")
      }
    }
    #expect(receivedAudioDataCount > 0)
  }

  // MARK: - Multi-Speaker Tests

  // TODO(#16775): Change to `InstanceConfig.defaultConfigs` after backend API rollout.
  @Test(arguments: [InstanceConfig.enterprise_v1beta_global], ttsModels)
  func multiSpeaker_withTurnMetadata(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: GenerationConfig(
        responseModalities: [.audio],
        speechConfig: SpeechConfig(
          multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig(
            speakerVoiceConfigs: [
              SpeakerVoiceConfig(speaker: "Joe", voiceName: "Puck"),
              SpeakerVoiceConfig(speaker: "Jane", voiceName: "Kore"),
            ]
          )
        )
      )
    )
    let turn1 = TextPart(
      "Did you see the northern lights last night? The entire sky turned brilliant emerald green!",
      speechMetadata: SpeechMetadata(speaker: "Joe", style: "awed and enthusiastic")
    )
    let turn2 = TextPart(
      "I did! It was breathtaking. I've never seen anything quite like it.",
      speechMetadata: SpeechMetadata(speaker: "Jane", style: "wonderstruck and peaceful")
    )

    let response = try await model.generateContent(turn1, turn2)

    let candidate = try #require(response.candidates.first)
    #expect(candidate.finishReason == .stop)
    let audioPart = try #require(candidate.content.parts.first as? InlineDataPart)
    #expect(!audioPart.data.isEmpty)
    #expect(audioPart.mimeType == unaryMIMEType)
  }

  // TODO(#16775): Change to `InstanceConfig.defaultConfigs` after backend API rollout.
  @Test(arguments: [InstanceConfig.enterprise_v1beta_global], ttsModels)
  func multiSpeakerStream_withTurnMetadata(_ config: InstanceConfig,
                                           modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: GenerationConfig(
        responseModalities: [.audio],
        speechConfig: SpeechConfig(
          multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig(
            speakerVoiceConfigs: [
              SpeakerVoiceConfig(speaker: "Joe", voiceName: "Puck"),
              SpeakerVoiceConfig(speaker: "Jane", voiceName: "Kore"),
            ]
          )
        )
      )
    )
    let turn1 = TextPart(
      "Welcome back everyone. Today we're debating: is time travel theoretically possible?",
      speechMetadata: SpeechMetadata(speaker: "Joe", style: "inquisitive and energetic")
    )
    let turn2 = TextPart(
      "According to general relativity, travelling forward is easy; going backward, not so much.",
      speechMetadata: SpeechMetadata(speaker: "Jane", style: "analytical and wry")
    )

    let responseStream = try model.generateContentStream(turn1, turn2)

    var receivedAudioDataCount = 0
    for try await chunk in responseStream {
      guard let candidate = chunk.candidates.first else { continue }
      if let audioPart = candidate.content.parts.first as? InlineDataPart {
        #expect(!audioPart.data.isEmpty)
        #expect(audioPart.mimeType == streamingMIMEType)
        receivedAudioDataCount += audioPart.data.count
      } else {
        #expect(candidate.finishReason == .stop, "Unexpected non-audio chunk: \(candidate)")
      }
    }
    #expect(receivedAudioDataCount > 0)
  }

  // MARK: - Error Handling Tests

  @Test(arguments: InstanceConfig.defaultConfigs, ttsModels)
  func multiSpeaker_invalidSize(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: GenerationConfig(
        responseModalities: [.audio],
        speechConfig: SpeechConfig(
          multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig(
            speakerVoiceConfigs: [
              SpeakerVoiceConfig(speaker: "Speaker1", voiceName: "Puck"),
              SpeakerVoiceConfig(speaker: "Speaker2", voiceName: "Charon"),
              SpeakerVoiceConfig(speaker: "Speaker3", voiceName: "Aoede"),
            ]
          )
        )
      )
    )

    let turn1 = TextPart("Hello!", speechMetadata: SpeechMetadata(speaker: "Speaker1"))
    let turn2 = TextPart("Hi!", speechMetadata: SpeechMetadata(speaker: "Speaker2"))
    let turn3 = TextPart("Hey!", speechMetadata: SpeechMetadata(speaker: "Speaker3"))
    let error = try await #require(throws: GenerateContentError.self) {
      try await model.generateContent(turn1, turn2, turn3)
    }
    guard case let .internalError(underlyingError) = error else {
      Issue.record("Expected internalError; got \(error).")
      return
    }
    #expect(
      String(describing: underlyingError)
        .contains("the number of speaker_voice_configs must equal 2")
    )
  }
}
