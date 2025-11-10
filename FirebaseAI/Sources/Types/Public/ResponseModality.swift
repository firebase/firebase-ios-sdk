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

/// Represents the different types, or modalities, of data that a model can produce as output.
///
/// To configure the desired output modalities for model requests, set the `responseModalities`
/// parameter when initializing a ``GenerationConfig``. See the [multimodal
/// responses](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal-response-generation)
/// documentation for more details.
///
/// > Important: Support for each response modality, or combination of modalities, depends on the
/// > model.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ResponseModality: EncodableProtoEnum, Sendable {
  enum Kind: String {
    case text = "TEXT"
    case image = "IMAGE"
    case audio = "AUDIO"
  }

  /// Specifies that the model should generate textual content.
  ///
  /// Use this modality when you need the model to produce written language, such as answers to
  /// questions, summaries, creative writing, code snippets, or structured data formats like JSON.
  public static let text = ResponseModality(kind: .text)

  /// **Public Experimental**: Specifies that the model should generate image data.
  ///
  /// Use this modality when you want the model to create visual content based on the provided input
  /// or prompts. The response might contain one or more generated images. See the [image
  /// generation](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal-response-generation#image-generation)
  /// documentation for more details.
  ///
  /// > Warning: Image generation using Gemini 2.0 Flash is a **Public Experimental** feature, which
  /// > means that it is not subject to any SLA or deprecation policy and could change in
  /// > backwards-incompatible ways.
  public static let image = ResponseModality(kind: .image)

  /// **Public Preview**: Specifies that the model should generate audio content.
  ///
  /// Use this modality when you need the model to produce (spoken) audio responses based on the
  /// provided input or prompts.
  ///
  /// > Warning: This is currently **only** supported via the
  /// > [live api](https://firebase.google.com/docs/ai-logic/live-api)\.
  /// >
  /// > Furthermore, using the Firebase AI Logic SDKs with the Gemini Live API is in Public Preview,
  /// > which means that the feature is not subject to any SLA or deprecation policy and could
  /// > change in backwards-incompatible ways.
  public static let audio = ResponseModality(kind: .audio)

  let rawValue: String
}
