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

// This package-internal protocol ensures that the methods `generativeModel(...)` and
// `imagenModel(...)` do no diverge between the `VertexAI` and `FirebaseAI` implementations.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
package protocol VertexAIProtocol {
  func generativeModel(modelName: String, generationConfig: GenerationConfig?,
                       safetySettings: [SafetySetting]?, tools: [Tool]?, toolConfig: ToolConfig?,
                       systemInstruction: ModelContent?,
                       requestOptions: RequestOptions) -> GenerativeModel

  func imagenModel(modelName: String, generationConfig: ImagenGenerationConfig?,
                   safetySettings: ImagenSafetySettings?,
                   requestOptions: RequestOptions) -> ImagenModel
}
