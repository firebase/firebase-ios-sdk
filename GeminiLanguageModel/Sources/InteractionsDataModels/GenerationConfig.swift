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

package import GeminiSharedDataModels

/// Configuration parameters for model interactions.
package struct GenerationConfig: Codable, Sendable, Equatable, Hashable {

  /// Configuration for image interaction.
  @available(*, deprecated)
  package let imageConfig: ImageConfig?

  /// The maximum number of tokens to include in the response.
  package let maxOutputTokens: Int?

  /// Seed used in decoding for reproducibility.
  package let seed: Int?

  /// Optional. Speech and multi-speaker configuration.
  package let speechConfig: JSONValue?

  /// A list of character sequences that will stop output interaction.
  package let stopSequences: [String]?

  /// The level of thought tokens that the model should generate.
  package let thinkingLevel: ThinkingLevel?

  /// Whether to include thought summaries in the response.
  package let thinkingSummaries: ThinkingSummaries?

  /// The tool choice configuration.
  package let toolChoice: JSONValue?

  /// Optional. Configuration for speech recognition (transcription). If present, ASR is
  /// enabled.
  package let transcriptionConfig: TranscriptionConfig?

  /// Configuration for video generation.
  package let videoConfig: VideoConfig?

  /// Creates a new `GenerationConfig`.
  ///
  /// - Parameters:
  ///   - imageConfig: Configuration for image interaction.
  ///   - maxOutputTokens: The maximum number of tokens to include in the response.
  ///   - seed: Seed used in decoding for reproducibility.
  ///   - speechConfig: Optional. Speech and multi-speaker configuration.
  ///   - stopSequences: A list of character sequences that will stop output interaction.
  ///   - thinkingLevel: The level of thought tokens that the model should generate.
  ///   - thinkingSummaries: Whether to include thought summaries in the response.
  ///   - toolChoice: The tool choice configuration.
  ///   - transcriptionConfig: Optional. Configuration for speech recognition (transcription). If present, ASR is
  ///   - videoConfig: Configuration for video generation.
  package init(
    imageConfig: ImageConfig? = nil,
    maxOutputTokens: Int? = nil,
    seed: Int? = nil,
    speechConfig: JSONValue? = nil,
    stopSequences: [String]? = nil,
    thinkingLevel: ThinkingLevel? = nil,
    thinkingSummaries: ThinkingSummaries? = nil,
    toolChoice: JSONValue? = nil,
    transcriptionConfig: TranscriptionConfig? = nil,
    videoConfig: VideoConfig? = nil
  ) {
    self.imageConfig = imageConfig
    self.maxOutputTokens = maxOutputTokens
    self.seed = seed
    self.speechConfig = speechConfig
    self.stopSequences = stopSequences
    self.thinkingLevel = thinkingLevel
    self.thinkingSummaries = thinkingSummaries
    self.toolChoice = toolChoice
    self.transcriptionConfig = transcriptionConfig
    self.videoConfig = videoConfig
  }
  enum CodingKeys: String, CodingKey {
    case imageConfig = "image_config"
    case maxOutputTokens = "max_output_tokens"
    case seed = "seed"
    case speechConfig = "speech_config"
    case stopSequences = "stop_sequences"
    case thinkingLevel = "thinking_level"
    case thinkingSummaries = "thinking_summaries"
    case toolChoice = "tool_choice"
    case transcriptionConfig = "transcription_config"
    case videoConfig = "video_config"
  }
}
