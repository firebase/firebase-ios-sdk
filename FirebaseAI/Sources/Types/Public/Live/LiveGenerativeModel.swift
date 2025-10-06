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

/// A multimodal model (like Gemini) capable of real-time content generation based on
/// various input types, supporting bidirectional streaming.
///
/// You can create a new session via ``LiveGenerativeModel/connect()``.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public final class LiveGenerativeModel {
  let modelResourceName: String
  let firebaseInfo: FirebaseInfo
  let apiConfig: APIConfig
  let generationConfig: LiveGenerationConfig?
  let tools: [Tool]?
  let toolConfig: ToolConfig?
  let systemInstruction: ModelContent?
  let urlSession: URLSession
  let requestOptions: RequestOptions

  init(modelResourceName: String,
       firebaseInfo: FirebaseInfo,
       apiConfig: APIConfig,
       generationConfig: LiveGenerationConfig? = nil,
       tools: [Tool]? = nil,
       toolConfig: ToolConfig? = nil,
       systemInstruction: ModelContent? = nil,
       urlSession: URLSession = GenAIURLSession.default,
       requestOptions: RequestOptions) {
    self.modelResourceName = modelResourceName
    self.firebaseInfo = firebaseInfo
    self.apiConfig = apiConfig
    self.generationConfig = generationConfig
    self.tools = tools
    self.toolConfig = toolConfig
    self.systemInstruction = systemInstruction
    self.urlSession = urlSession
    self.requestOptions = requestOptions
  }

  /// Start a ``LiveSession`` with the server for bidirectional streaming.
  ///
  /// - Returns: A new ``LiveSession`` that you can use to stream messages to and from the server.
  public func connect() async throws -> LiveSession {
    let service = LiveSessionService(
      modelResourceName: modelResourceName,
      generationConfig: generationConfig,
      urlSession: urlSession,
      apiConfig: apiConfig,
      firebaseInfo: firebaseInfo,
      tools: tools,
      toolConfig: toolConfig,
      systemInstruction: systemInstruction,
      requestOptions: requestOptions
    )

    try await service.connect()

    return LiveSession(service: service)
  }
}
