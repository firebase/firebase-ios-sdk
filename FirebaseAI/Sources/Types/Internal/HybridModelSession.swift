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
  private import FirebaseCoreInternal

  final class HybridModelSession: _ModelSession {
    private let primaryModel: any LanguageModel
    private let secondaryModel: any LanguageModel
    private let tools: [any ToolRepresentable]?
    private let instructions: String?

    private let lock: UnfairLock<(primary: (any _ModelSession)?, secondary: (any _ModelSession)?)>

    init(primaryModel: any LanguageModel, secondaryModel: any LanguageModel,
         tools: [any ToolRepresentable]?, instructions: String?) {
      self.primaryModel = primaryModel
      self.secondaryModel = secondaryModel
      self.tools = tools
      self.instructions = instructions
      lock = UnfairLock((primary: nil, secondary: nil))
    }

    /// Returns `true` if the session has history (i.e., it has already had one or more chat turns).
    ///
    /// > Important: This property is for **internal use only** and may change at any time.
    var _hasHistory: Bool {
      return lock.withLock { state in
        state.primary?._hasHistory == true || state.secondary?._hasHistory == true
      }
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
      // If the secondary session contains history then a previous fallback occurred.
      // Stick with the secondary session to maintain conversation consistency.
      let useSecondary = lock.withLock { state in
        state.secondary?._hasHistory == true
      }
      if useSecondary {
        let secondarySession = try getSecondarySession()
        return try await secondarySession._respond(
          to: prompt,
          schema: schema,
          includeSchemaInPrompt: includeSchemaInPrompt,
          options: options
        )
      }

      do {
        // First try the primary session.
        let primarySession = try getPrimarySession()
        return try await primarySession._respond(
          to: prompt,
          schema: schema,
          includeSchemaInPrompt: includeSchemaInPrompt,
          options: options
        )
      } catch {
        // Do not fallback to second session if the primary session contains history.
        let primaryHasHistory = lock.withLock { state in
          state.primary?._hasHistory == true
        }
        if primaryHasHistory {
          throw error
        }

        // Fallback to the second session if the first fails or is unavailable.
        let secondarySession = try getSecondarySession()
        return try await secondarySession._respond(
          to: prompt,
          schema: schema,
          includeSchemaInPrompt: includeSchemaInPrompt,
          options: options
        )
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
      // If the secondary session contains history then a previous fallback occurred.
      // Stick with the secondary session to maintain conversation consistency.
      let useSecondary = lock.withLock { state in
        state.secondary?._hasHistory == true
      }
      if useSecondary {
        do {
          let secondarySession = try getSecondarySession()
          return secondarySession._streamResponse(
            to: prompt,
            schema: schema,
            includeSchemaInPrompt: includeSchemaInPrompt,
            options: options
          )
        } catch {
          return AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
          }
        }
      }

      return AsyncThrowingStream { continuation in
        let task = Task {
          do {
            // First try the primary session.
            let primarySession = try self.getPrimarySession()
            let stream = primarySession._streamResponse(
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
              let primaryHasHistory = self.lock.withLock { state in
                state.primary?._hasHistory == true
              }
              if didYield || primaryHasHistory {
                continuation.finish(throwing: error)
                return
              }

              // Fallback to the second session if the first fails or is unavailable.
              let secondarySession = try self.getSecondarySession()
              let stream = secondarySession._streamResponse(
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
          } catch {
            // Failure to create primary session.
            // Fallback to the second session if the first fails or is unavailable.
            do {
              let secondarySession = try self.getSecondarySession()
              let stream = secondarySession._streamResponse(
                to: prompt,
                schema: schema,
                includeSchemaInPrompt: includeSchemaInPrompt,
                options: options
              )

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

    private func getPrimarySession() throws -> any _ModelSession {
      try lock.withLock { state in
        if let session = state.primary {
          return session
        }
        let session = try primaryModel._startSession(tools: tools, instructions: instructions)
        state.primary = session
        return session
      }
    }

    private func getSecondarySession() throws -> any _ModelSession {
      try lock.withLock { state in
        if let session = state.secondary {
          return session
        }
        let session = try secondaryModel._startSession(tools: tools, instructions: instructions)
        state.secondary = session
        return session
      }
    }
  }
#endif // compiler(>=6.2.3)
