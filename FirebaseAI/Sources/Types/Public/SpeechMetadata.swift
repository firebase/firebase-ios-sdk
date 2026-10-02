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

/// **[Public Preview]** Turn-level speech synthesis metadata for text content in a model request.
///
/// > Warning: This API is a public preview and may be subject to change.
///
/// When generating audio using Gemini text-to-speech (TTS) models, the input text in a
/// ``TextPart`` is treated strictly as a verbatim transcript. ``SpeechMetadata`` attaches
/// structured turn-level instructions to control speaker assignment and speech delivery.
///
/// For more details on speech generation, see the
/// [Text-to-speech guide](https://firebase.google.com/docs/ai-logic/generate-speech).
public struct SpeechMetadata: Sendable, Equatable, Hashable {
  /// The unique name or identifier of the speaker for multi-speaker synthesis.
  ///
  /// > Important: When using a multi-speaker configuration, `speaker` is required on every
  /// > ``TextPart``. Omitting `speaker` in a multi-speaker request results in a backend error.
  let speaker: String?

  /// The sustained delivery style instruction for speech synthesis.
  let style: String?

  /// Creates speech metadata with an optional speaker identifier and delivery style.
  ///
  /// - Parameters:
  ///   - speaker: The unique name or identifier of the speaker for multi-speaker synthesis
  ///     (for example, `"Joe"`). Must match a speaker name configured in ``SpeakerVoiceConfig``.
  ///
  ///     > Important: When using a multi-speaker configuration, `speaker` is required on every
  ///     > dialogue turn. Pass each speaker turn as a separate ``TextPart`` with a matching
  ///     > `speaker` name.
  ///
  ///     See the documentation on
  ///     [multi-speaker](https://firebase.google.com/docs/ai-logic/generate-speech#multi-speaker)
  ///     for more details. Defaults to `nil`.
  ///   - style: A natural-language description of the sustained delivery style, emotion,
  ///     prosody, pacing, or volume across the entire turn (for example,
  ///     `"cheerful and friendly"` or `"whispering urgently"`).
  ///
  ///     Instructions should be partitioned based on scope:
  ///     - **Sustained turn-level delivery (`style`)**: Put attributes that apply across an
  ///       entire dialogue turn into `style` (for example, `"whispering"`,
  ///       `"cheerful and friendly"`, `"speaking slowly"`, `"out of breath"`, or `"sarcastic"`).
  ///     - **Point-in-time events (inline vocal tags)**: Place momentary non-speech vocalizations
  ///       or pauses directly inside the transcript text using angle brackets (for example,
  ///       `<laugh>`, `<sigh>`, `<cough>`, `<breath>`, or `<short pause>`), rather than in
  ///       `style`.
  ///
  ///     See [audio tags](https://firebase.google.com/docs/ai-logic/generate-speech#audio-tags)
  ///     for more details. Defaults to `nil`.
  public init(speaker: String? = nil, style: String? = nil) {
    self.speaker = speaker
    self.style = style
  }
}

// MARK: - Codable Conformance

extension SpeechMetadata: Codable {}
