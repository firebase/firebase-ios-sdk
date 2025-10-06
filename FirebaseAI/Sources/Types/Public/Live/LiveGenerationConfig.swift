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

/// Configuration options for live content generation.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct LiveGenerationConfig: Sendable {
  let bidiGenerationConfig: BidiGenerationConfig
  let inputAudioTranscription: BidiAudioTranscriptionConfig?
  let outputAudioTranscription: BidiAudioTranscriptionConfig?

  /// Creates a new ``LiveGenerationConfig`` value.
  ///
  /// See the
  /// [Configure model parameters](https://firebase.google.com/docs/vertex-ai/model-parameters)
  /// guide and the
  /// [Cloud documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference#generationconfig)
  /// for more details.
  ///
  /// - Parameters:
  ///   - temperature:Controls the randomness of the language model's output. Higher values (for
  ///     example, 1.0) make the text more random and creative, while lower values (for example,
  ///     0.1) make it more focused and deterministic.
  ///
  ///     > Note: A temperature of 0 means that the highest probability tokens are always selected.
  ///     > In this case, responses for a given prompt are mostly deterministic, but a small amount
  ///     > of variation is still possible.
  ///
  ///     > Important: The range of supported temperature values depends on the model; see the
  ///     > [documentation](https://firebase.google.com/docs/vertex-ai/model-parameters?platform=ios#temperature)
  ///     > for more details.
  ///   - topP: Controls diversity of generated text. Higher values (e.g., 0.9) produce more diverse
  ///     text, while lower values (e.g., 0.5) make the output more focused.
  ///
  ///     The supported range is 0.0 to 1.0.
  ///
  ///     > Important: The default `topP` value depends on the model; see the
  ///     > [documentation](https://firebase.google.com/docs/vertex-ai/model-parameters?platform=ios#top-p)
  ///     > for more details.
  ///   - topK: Limits the number of highest probability words the model considers when generating
  ///     text. For example, a topK of 40 means only the 40 most likely words are considered for the
  ///     next token. A higher value increases diversity, while a lower value makes the output more
  ///     deterministic.
  ///
  ///     The supported range is 1 to 40.
  ///
  ///     > Important: Support for `topK` and the default value depends on the model; see the
  ///     [documentation](https://firebase.google.com/docs/vertex-ai/model-parameters?platform=ios#top-k)
  ///     for more details.
  ///   - candidateCount: The number of response variations to return; defaults to 1 if not set.
  ///     Support for multiple candidates depends on the model; see the
  ///     [Cloud documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference#generationconfig)
  ///     for more details.
  ///   - maxOutputTokens: Maximum number of tokens that can be generated in the response.
  ///     See the configure model parameters [documentation](https://firebase.google.com/docs/vertex-ai/model-parameters?platform=ios#max-output-tokens)
  ///     for more details.
  ///   - presencePenalty: Controls the likelihood of repeating the same words or phrases already
  ///     generated in the text. Higher values increase the penalty of repetition, resulting in more
  ///     diverse output.
  ///
  ///     > Note: While both `presencePenalty` and `frequencyPenalty` discourage repetition,
  ///     > `presencePenalty` applies the same penalty regardless of how many times the word/phrase
  ///     > has already appeared, whereas `frequencyPenalty` increases the penalty for *each*
  ///     > repetition of a word/phrase.
  ///
  ///     > Important: The range of supported `presencePenalty` values depends on the model; see the
  ///     > [Cloud documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference#generationconfig)
  ///     > for more details
  ///   - frequencyPenalty: Controls the likelihood of repeating words or phrases, with the penalty
  ///     increasing for each repetition. Higher values increase the penalty of repetition,
  ///     resulting in more diverse output.
  ///
  ///     > Note: While both `frequencyPenalty` and `presencePenalty` discourage repetition,
  ///     > `frequencyPenalty` increases the penalty for *each* repetition of a word/phrase, whereas
  ///     > `presencePenalty` applies the same penalty regardless of how many times the word/phrase
  ///     > has already appeared.
  ///
  ///     > Important: The range of supported `frequencyPenalty` values depends on the model; see
  ///     > the
  ///     > [Cloud documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference#generationconfig)
  ///     > for more details
  ///   - responseModalities: The data types (modalities) that may be returned in model responses.
  ///
  ///     See the [multimodal
  ///     responses](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal-response-generation)
  ///     documentation for more details.
  ///
  ///     > Warning: Specifying response modalities is a **Public Preview** feature, which means
  ///     > that it is not subject to any SLA or deprecation policy and could change in
  ///     > backwards-incompatible ways.
  ///   - speech: Controls the voice of the model, when streaming `audio` via
  ///     ``ResponseModality``.
  ///   - inputAudioTranscription: Configures (and enables) input transcriptions when streaming to
  ///     the model.
  ///
  ///     Input transcripts are the model's interpretation of audio data sent to it, and they are
  ///     populated in model responses via ``LiveServerContent/inputAudioTranscription``. When this
  ///     field is set to `nil`, input transcripts are not populated in model responses.
  ///   - outputAudioTranscription: Configures (and enables) output transcriptions when streaming to
  ///     the model.
  ///
  ///     Output transcripts are text representations of the audio the model is sending to the
  ///     client, and they are populated in model responses via
  ///     ``LiveServerContent/outputAudioTranscription``. When this
  ///     field is set to `nil`, output transcripts are not populated in model responses.
  ///
  ///     > Important: Transcripts are independent to the model turn. This means transcripts may
  ///     > come earlier or later than when the model sends the corresponding audio responses.
  public init(temperature: Float? = nil, topP: Float? = nil, topK: Int? = nil,
              candidateCount: Int? = nil, maxOutputTokens: Int? = nil,
              presencePenalty: Float? = nil, frequencyPenalty: Float? = nil,
              responseModalities: [ResponseModality]? = nil,
              speech: SpeechConfig? = nil,
              inputAudioTranscription: AudioTranscriptionConfig? = nil,
              outputAudioTranscription: AudioTranscriptionConfig? = nil) {
    self.init(
      BidiGenerationConfig(
        temperature: temperature,
        topP: topP,
        topK: topK,
        candidateCount: candidateCount,
        maxOutputTokens: maxOutputTokens,
        presencePenalty: presencePenalty,
        frequencyPenalty: frequencyPenalty,
        responseModalities: responseModalities,
        speechConfig: speech?.speechConfig
      ),
      inputAudioTranscription: inputAudioTranscription?.audioTranscriptionConfig,
      outputAudioTranscription: outputAudioTranscription?.audioTranscriptionConfig
    )
  }

  init(_ bidiGenerationConfig: BidiGenerationConfig,
       inputAudioTranscription: BidiAudioTranscriptionConfig? = nil,
       outputAudioTranscription: BidiAudioTranscriptionConfig? = nil) {
    self.bidiGenerationConfig = bidiGenerationConfig
    self.inputAudioTranscription = inputAudioTranscription
    self.outputAudioTranscription = outputAudioTranscription
  }
}
