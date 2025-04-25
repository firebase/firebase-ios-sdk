// Copyright 2024 Google LLC
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

@_exported public import FirebaseAI

import FirebaseCore

/// The Vertex AI for Firebase SDK provides access to Gemini models directly from your app.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public class VertexAI {
  // MARK: - Public APIs

  /// Creates an instance of `VertexAI`.
  ///
  ///  - Parameters:
  ///   - app: A custom `FirebaseApp` used for initialization; if not specified, uses the default
  ///     ``FirebaseApp``.
  ///   - location: The region identifier, defaulting to `us-central1`; see
  ///     [Vertex AI locations]
  ///     (https://firebase.google.com/docs/vertex-ai/locations?platform=ios#available-locations)
  ///     for a list of supported locations.
  /// - Returns: A `VertexAI` instance, configured with the custom `FirebaseApp`.
  public static func vertexAI(app: FirebaseApp? = nil,
                              location: String = "us-central1") -> VertexAI {
    let firebaseAI = FirebaseAI.firebaseAI(app: app, backend: .vertexAI(location: location))
    return VertexAI(firebaseAI: firebaseAI)
  }

  /// Initializes a generative model with the given parameters.
  ///
  /// - Note: Refer to [Gemini models](https://firebase.google.com/docs/vertex-ai/gemini-models) for
  /// guidance on choosing an appropriate model for your use case.
  ///
  /// - Parameters:
  ///   - modelName: The name of the model to use, for example `"gemini-1.5-flash"`; see
  ///     [available model names
  ///     ](https://firebase.google.com/docs/vertex-ai/gemini-models#available-model-names) for a
  ///     list of supported model names.
  ///   - generationConfig: The content generation parameters your model should use.
  ///   - safetySettings: A value describing what types of harmful content your model should allow.
  ///   - tools: A list of ``Tool`` objects that the model may use to generate the next response.
  ///   - toolConfig: Tool configuration for any `Tool` specified in the request.
  ///   - systemInstruction: Instructions that direct the model to behave a certain way; currently
  ///     only text content is supported.
  ///   - requestOptions: Configuration parameters for sending requests to the backend.
  public func generativeModel(modelName: String,
                              generationConfig: GenerationConfig? = nil,
                              safetySettings: [SafetySetting]? = nil,
                              tools: [Tool]? = nil,
                              toolConfig: ToolConfig? = nil,
                              systemInstruction: ModelContent? = nil,
                              requestOptions: RequestOptions = RequestOptions())
    -> GenerativeModel {
    return firebaseAI.generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      tools: tools,
      toolConfig: toolConfig,
      systemInstruction: systemInstruction,
      requestOptions: requestOptions
    )
  }

  /// **[Public Preview]** Initializes an ``ImagenModel`` with the given parameters.
  ///
  /// > Warning: For Vertex AI in Firebase, image generation using Imagen 3 models is in Public
  /// Preview, which means that the feature is not subject to any SLA or deprecation policy and
  /// could change in backwards-incompatible ways.
  ///
  /// > Important: Only Imagen 3 models (named `imagen-3.0-*`) are supported.
  ///
  /// - Parameters:
  ///   - modelName: The name of the Imagen 3 model to use, for example `"imagen-3.0-generate-002"`;
  ///     see [model versions](https://firebase.google.com/docs/vertex-ai/models) for a list of
  ///     supported Imagen 3 models.
  ///   - generationConfig: Configuration options for generating images with Imagen.
  ///   - safetySettings: Settings describing what types of potentially harmful content your model
  ///     should allow.
  ///   - requestOptions: Configuration parameters for sending requests to the backend.
  public func imagenModel(modelName: String, generationConfig: ImagenGenerationConfig? = nil,
                          safetySettings: ImagenSafetySettings? = nil,
                          requestOptions: RequestOptions = RequestOptions()) -> ImagenModel {
    return firebaseAI.imagenModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      requestOptions: requestOptions
    )
  }

  // MARK: - Internal APIs

  let firebaseAI: FirebaseAI

  init(firebaseAI: FirebaseAI) {
    self.firebaseAI = firebaseAI
  }
}
