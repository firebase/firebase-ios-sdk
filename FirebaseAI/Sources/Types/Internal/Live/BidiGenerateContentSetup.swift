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

import Foundation

/// Message to be sent in the first and only first
/// `BidiGenerateContentClientMessage`. Contains configuration that will apply
/// for the duration of the streaming RPC.
///
/// Clients should wait for a `BidiGenerateContentSetupComplete` message before
/// sending any additional messages.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
struct BidiGenerateContentSetup: Encodable {
  /// The fully qualified name of the publisher model.
  ///
  /// Publisher model format:
  /// `projects/{project}/locations/{location}/publishers/*/models/*`
  let model: String

  /// Generation config.
  let generationConfig: BidiGenerationConfig?

  /// The user provided system instructions for the model.
  /// Note: only text should be used in parts and content in each part will be
  /// in a separate paragraph.
  let systemInstruction: ModelContent?

  /// A list of `Tools` the model may use to generate the next response.
  ///
  /// A `Tool` is a piece of code that enables the system to interact with
  /// external systems to perform an action, or set of actions, outside of
  /// knowledge and scope of the model.
  let tools: [Tool]?

  let toolConfig: ToolConfig?

  /// Input transcription. The transcription is independent to the model turn
  /// which means it doesn't imply any ordering between transcription and model
  /// turn.
  let inputAudioTranscription: BidiAudioTranscriptionConfig?

  /// Output transcription. The transcription is independent to the model turn
  /// which means it doesn't imply any ordering between transcription and model
  /// turn.
  let outputAudioTranscription: BidiAudioTranscriptionConfig?

  init(model: String,
       generationConfig: BidiGenerationConfig? = nil,
       systemInstruction: ModelContent? = nil,
       tools: [Tool]? = nil,
       toolConfig: ToolConfig? = nil,
       inputAudioTranscription: BidiAudioTranscriptionConfig? = nil,
       outputAudioTranscription: BidiAudioTranscriptionConfig? = nil) {
    self.model = model
    self.generationConfig = generationConfig
    self.systemInstruction = systemInstruction
    self.tools = tools
    self.toolConfig = toolConfig
    self.inputAudioTranscription = inputAudioTranscription
    self.outputAudioTranscription = outputAudioTranscription
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
struct BidiAudioTranscriptionConfig: Encodable {}
