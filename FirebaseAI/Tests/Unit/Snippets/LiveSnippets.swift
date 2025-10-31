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
import FirebaseCore
import XCTest

// These snippet tests are intentionally skipped in CI jobs; see the README file in this directory
// for instructions on running them manually.

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
@available(watchOS, unavailable)
final class LiveSnippets: XCTestCase {
  override func setUpWithError() throws {
    try FirebaseApp.configureDefaultAppForSnippets()
  }

  override func tearDown() async throws {
    await FirebaseApp.deleteDefaultAppForSnippets()
  }

  func sendAudioReceiveAudio() async throws {
    // Initialize the Vertex AI Gemini API backend service
    // Set the location to `us-central1` (the flash-live model is only supported in that location)
    // Create a `LiveGenerativeModel` instance with the flash-live model (only model that supports
    // the Live API)
    let model = FirebaseAI.firebaseAI(backend: .vertexAI(location: "us-central1")).liveModel(
      modelName: "gemini-2.0-flash-exp",
      // Configure the model to respond with audio
      generationConfig: LiveGenerationConfig(
        responseModalities: [.audio]
      )
    )

    do {
      let session = try await model.connect()

      // Load the audio file, or tap a microphone
      guard let audioFile = NSDataAsset(name: "audio.pcm") else {
        fatalError("Failed to load audio file")
      }

      // Provide the audio data
      await session.sendAudioRealtime(audioFile.data)

      for try await message in session.responses {
        if case let .content(content) = message.payload {
          content.modelTurn?.parts.forEach { part in
            if let part = part as? InlineDataPart, part.mimeType.starts(with: "audio/pcm") {
              // Handle 16bit pcm audio data at 24khz
              playAudio(part.data)
            }
          }
          // Optional: if you don't require to send more requests.
          if content.isTurnComplete {
            await session.close()
          }
        }
      }
    } catch {
      fatalError(error.localizedDescription)
    }
  }

  func sendAudioReceiveText() async throws {
    // Initialize the Vertex AI Gemini API backend service
    // Set the location to `us-central1` (the flash-live model is only supported in that location)
    // Create a `LiveGenerativeModel` instance with the flash-live model (only model that supports
    // the Live API)
    let model = FirebaseAI.firebaseAI(backend: .googleAI()).liveModel(
      modelName: "gemini-live-2.5-flash-preview",
      // Configure the model to respond with text
      generationConfig: LiveGenerationConfig(
        responseModalities: [.text]
      )
    )

    do {
      let session = try await model.connect()

      // Load the audio file, or tap a microphone
      guard let audioFile = NSDataAsset(name: "audio.pcm") else {
        fatalError("Failed to load audio file")
      }

      // Provide the audio data
      await session.sendAudioRealtime(audioFile.data)

      var outputText = ""
      for try await message in session.responses {
        if case let .content(content) = message.payload {
          content.modelTurn?.parts.forEach { part in
            if let part = part as? TextPart {
              outputText += part.text
            }
          }
          // Optional: if you don't require to send more requests.
          if content.isTurnComplete {
            await session.close()
          }
        }
      }

      // Output received from the server.
      print(outputText)
    } catch {
      fatalError(error.localizedDescription)
    }
  }

  func sendTextReceiveAudio() async throws {
    // Initialize the Gemini Developer API backend service
    // Create a `LiveModel` instance with the flash-live model (only model that supports the Live
    // API)
    let model = FirebaseAI.firebaseAI(backend: .googleAI()).liveModel(
      modelName: "gemini-live-2.5-flash-preview",
      // Configure the model to respond with audio
      generationConfig: LiveGenerationConfig(
        responseModalities: [.audio]
      )
    )

    do {
      let session = try await model.connect()

      // Provide a text prompt
      let text = "tell a short story"

      await session.sendTextRealtime(text)

      for try await message in session.responses {
        if case let .content(content) = message.payload {
          content.modelTurn?.parts.forEach { part in
            if let part = part as? InlineDataPart, part.mimeType.starts(with: "audio/pcm") {
              // Handle 16bit pcm audio data at 24khz
              playAudio(part.data)
            }
          }
          // Optional: if you don't require to send more requests.
          if content.isTurnComplete {
            await session.close()
          }
        }
      }
    } catch {
      fatalError(error.localizedDescription)
    }
  }

  func sendTextReceiveText() async throws {
    // Initialize the Gemini Developer API backend service
    // Create a `LiveModel` instance with the flash-live model (only model that supports the Live
    // API)
    let model = FirebaseAI.firebaseAI(backend: .googleAI()).liveModel(
      modelName: "gemini-live-2.5-flash-preview",
      // Configure the model to respond with audio
      generationConfig: LiveGenerationConfig(
        responseModalities: [.audio]
      )
    )

    do {
      let session = try await model.connect()

      // Provide a text prompt
      let text = "tell a short story"

      await session.sendTextRealtime(text)

      for try await message in session.responses {
        if case let .content(content) = message.payload {
          content.modelTurn?.parts.forEach { part in
            if let part = part as? InlineDataPart, part.mimeType.starts(with: "audio/pcm") {
              // Handle 16bit pcm audio data at 24khz
              playAudio(part.data)
            }
          }
          // Optional: if you don't require to send more requests.
          if content.isTurnComplete {
            await session.close()
          }
        }
      }
    } catch {
      fatalError(error.localizedDescription)
    }
  }

  func changeVoiceAndLanguage() {
    let model = FirebaseAI.firebaseAI(backend: .googleAI()).liveModel(
      modelName: "gemini-live-2.5-flash-preview",
      // Configure the model to use a specific voice for its audio response
      generationConfig: LiveGenerationConfig(
        responseModalities: [.audio],
        speech: SpeechConfig(voiceName: "Fenrir")
      )
    )

    // Not part of snippet
    silenceWarning(model)
  }

  func modelParameters() {
    // ...

    // Set parameter values in a `LiveGenerationConfig` (example values shown here)
    let config = LiveGenerationConfig(
      temperature: 0.9,
      topP: 0.1,
      topK: 16,
      maxOutputTokens: 200,
      responseModalities: [.audio],
      speech: SpeechConfig(voiceName: "Fenrir")
    )

    // Initialize the Vertex AI Gemini API backend service
    // Specify the config as part of creating the `LiveGenerativeModel` instance
    let model = FirebaseAI.firebaseAI(backend: .googleAI()).liveModel(
      modelName: "gemini-live-2.5-flash-preview",
      generationConfig: config
    )

    // ...

    // Not part of snippet
    silenceWarning(model)
  }

  func systemInstructions() {
    // Specify the system instructions as part of creating the `LiveGenerativeModel` instance
    let model = FirebaseAI.firebaseAI(backend: .googleAI()).liveModel(
      modelName: "gemini-live-2.5-flash-preview",
      systemInstruction: ModelContent(role: "system", parts: "You are a cat. Your name is Neko.")
    )

    // Not part of snippet
    silenceWarning(model)
  }

  private func playAudio(_ data: Data) {
    // Use AVAudioPlayerNode or something akin to play back audio
  }

  /// This function only exists to silence the "unused value" warnings.
  ///
  /// This allows us to ensure the snippets match devsite.
  private func silenceWarning(_ model: LiveGenerativeModel) {}
}
