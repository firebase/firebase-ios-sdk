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

#if compiler(>=6.2.3)
  /// A type that represents a session for interacting with a ``LanguageModel``.
  ///
  /// > Important: This protocol is for **internal use only** and may change at any time.
  public protocol _ModelSession: Sendable {
    /// Returns `true` if the session has history (i.e., it has already had one or more chat turns).
    ///
    /// > Important: This property is for **internal use only** and may change at any time.
    var _hasHistory: Bool { get }

    /// Sends a prompt to the model and returns a ``_ModelSessionResponse``.
    ///
    /// > Important: This method is for **internal use only** and may change at any time.
    ///
    /// - Parameters:
    ///   - prompt: The content to send to the model.
    ///   - schema: An optional schema for structured outputs.
    ///   - includeSchemaInPrompt: Whether to include the `schema` in the request to the model; if
    ///     `false`, structured output (JSON) is requested but the schema is not strictly enforced.
    ///   - options: A set of options, represented as a ``GenerationOptionsRepresentable`` type.
    nonisolated(nonsending) func _respond(to prompt: [any Part],
                                          schema: FirebaseAI.GenerationSchema?,
                                          includeSchemaInPrompt: Bool,
                                          options: any GenerationOptionsRepresentable) async throws
      -> _ModelSessionResponse

    /// Sends a prompt to the model and streams the model's response.
    ///
    /// - Parameters:
    ///   - prompt: The content to send to the model.
    ///   - schema: An optional schema for structured outputs.
    ///   - includeSchemaInPrompt: Whether to include the `schema` in the request to the model; if
    ///     `false`, structured output (JSON) is requested but the schema is not strictly enforced.
    ///   - options: A set of options, represented as a ``GenerationOptionsRepresentable`` type.
    @available(macOS 12.0, watchOS 8.0, *)
    func _streamResponse(to prompt: [any Part],
                         schema: FirebaseAI.GenerationSchema?,
                         includeSchemaInPrompt: Bool,
                         options: any GenerationOptionsRepresentable)
      -> sending AsyncThrowingStream<_ModelSessionResponse, any Error>
  }
#endif // compiler(>=6.2.3)
