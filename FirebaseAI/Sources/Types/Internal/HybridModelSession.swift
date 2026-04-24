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
  final class HybridModelSession: _ModelSession {
    private let primary: any _ModelSession
    private let secondary: any _ModelSession

    init(primary: any _ModelSession, secondary: any _ModelSession) {
      self.primary = primary
      self.secondary = secondary
    }

    /// Returns `true` if the session has history (i.e., it has already had one or more chat turns).
    ///
    /// > Important: This property is for **internal use only** and may change at any time.
    var _hasHistory: Bool {
      return primary._hasHistory || secondary._hasHistory
    }

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
    func _respond(to prompt: [any Part], schema: FirebaseAI.GenerationSchema?,
                  includeSchemaInPrompt: Bool, options: any GenerationOptionsRepresentable)
      async throws -> _ModelSessionResponse {
      return try await TaskLocals.$isHybridRequest.withValue(true) {
        // If the secondary session contains history then a previous fallback occurred.
        // Stick with the secondary session to maintain conversation consistency.
        if secondary._hasHistory {
          return try await secondary._respond(
            to: prompt,
            schema: schema,
            includeSchemaInPrompt: includeSchemaInPrompt,
            options: options
          )
        }

        do {
          // First try the primary session.
          return try await primary._respond(
            to: prompt,
            schema: schema,
            includeSchemaInPrompt: includeSchemaInPrompt,
            options: options
          )
        } catch {
          // Do not fallback to second session if the primary session contains history.
          if primary._hasHistory {
            throw error
          }

          // Fallback to the second session if the first fails or is unavailable.
          return try await secondary._respond(
            to: prompt,
            schema: schema,
            includeSchemaInPrompt: includeSchemaInPrompt,
            options: options
          )
        }
      }
    }

    /// Sends a prompt to the model and streams the model's response.
    ///
    /// - Parameters:
    ///   - prompt: The content to send to the model.
    ///   - schema: An optional schema for structured outputs.
    ///   - includeSchemaInPrompt: Whether to include the `schema` in the request to the model; if
    ///     `false`, structured output (JSON) is requested but the schema is not strictly enforced.
    ///   - options: A set of options, represented as a ``GenerationOptionsRepresentable`` type.
    @available(macOS 12.0, watchOS 8.0, *)
    func _streamResponse(to prompt: [any Part], schema: FirebaseAI.GenerationSchema?,
                         includeSchemaInPrompt: Bool,
                         options: any GenerationOptionsRepresentable)
      -> sending AsyncThrowingStream<_ModelSessionResponse, any Error> {
      return TaskLocals.$isHybridRequest.withValue(true) {
        // If the secondary session contains history then a previous fallback occurred.
        // Stick with the secondary session to maintain conversation consistency.
        if secondary._hasHistory {
          return secondary._streamResponse(
            to: prompt,
            schema: schema,
            includeSchemaInPrompt: includeSchemaInPrompt,
            options: options
          )
        }

        return AsyncThrowingStream { continuation in
          let task = Task {
            // First try the primary session.
            let stream = primary._streamResponse(
              to: prompt,
              schema: schema,
              includeSchemaInPrompt: includeSchemaInPrompt,
              options: options
            )

            var didYield = false
            do {
              for try await snapshot in stream {
                didYield = true
                continuation.yield(snapshot)
              }
              continuation.finish()
            } catch {
              // Do not fallback to second session if the primary session contains history or has
              // already yielded data.
              if didYield || primary._hasHistory {
                continuation.finish(throwing: error)
                return
              }

              // Fallback to the second session if the first fails or is unavailable.
              let stream = secondary._streamResponse(
                to: prompt,
                schema: schema,
                includeSchemaInPrompt: includeSchemaInPrompt,
                options: options
              )

              do {
                for try await snapshot in stream {
                  continuation.yield(snapshot)
                }
                continuation.finish()
              } catch {
                continuation.finish(throwing: error)
              }
            }
          }
          continuation.onTermination = { _ in task.cancel() }
        }
      }
    }
  }
#endif // compiler(>=6.2.3)
