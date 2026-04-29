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

    typealias SessionState = (primary: (any _ModelSession)?, secondary: (any _ModelSession)?)
    private let lock: UnfairLock<SessionState>

    init(primaryModel: any LanguageModel, secondaryModel: any LanguageModel,
         tools: [any ToolRepresentable]?, instructions: String?) {
      self.primaryModel = primaryModel
      self.secondaryModel = secondaryModel
      self.tools = tools
      self.instructions = instructions
      lock = UnfairLock((primary: nil, secondary: nil))
    }

    enum SessionModel {
      case primaryModel
      case secondaryModel
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
      return try await TaskLocals.$isHybridRequest.withValue(true) {
        // If the secondary session contains history then a previous fallback occurred.
        // Stick with the secondary session to maintain conversation consistency.
        let useSecondary = lock.withLock { state in
          state.secondary?._hasHistory == true
        }
        if useSecondary {
          let secondarySession = try getSession(for: .secondaryModel)
          return try await secondarySession._respond(
            to: prompt,
            schema: schema,
            includeSchemaInPrompt: includeSchemaInPrompt,
            options: options
          )
        }

        let primarySession: any _ModelSession
        do {
          // First try to get the primary session.
          primarySession = try getSession(for: .primaryModel)
        } catch {
          if Task.isCancelled || error is CancellationError {
            throw error
          }

          // Fallback to the second session if the first fails or is unavailable.
          AILog.notice(code: .hybridPrimarySessionInitializationFailed, """
          Primary model "\(primaryModel._modelName)" failed to initialize session with error: \
          \(error); falling back to secondary model "\(secondaryModel._modelName)".
          """)
          let secondarySession = try getSession(for: .secondaryModel)
          return try await secondarySession._respond(
            to: prompt,
            schema: schema,
            includeSchemaInPrompt: includeSchemaInPrompt,
            options: options
          )
        }

        do {
          // Then try the request on the primary session.
          return try await primarySession._respond(
            to: prompt,
            schema: schema,
            includeSchemaInPrompt: includeSchemaInPrompt,
            options: options
          )
        } catch {
          if Task.isCancelled || error is CancellationError {
            throw error
          }

          // Do not fallback to second session if the primary session contains history.
          let primaryHasHistory = lock.withLock { state in
            state.primary?._hasHistory == true
          }
          if primaryHasHistory {
            throw error
          }

          // Fallback to the second session if the first fails or is unavailable.
          AILog.notice(code: .hybridPrimaryModelRequestFailed, """
          Primary model "\(primaryModel._modelName)" failed with error: \(error); falling back to \
          secondary model "\(secondaryModel._modelName)".
          """)
          let secondarySession = try getSession(for: .secondaryModel)
          return try await secondarySession._respond(
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
        let useSecondary = lock.withLock { state in
          state.secondary?._hasHistory == true
        }
        if useSecondary {
          do {
            let secondarySession = try getSession(for: .secondaryModel)
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
              let primarySession = try self.getSession(for: .primaryModel)
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
                if Task.isCancelled || error is CancellationError {
                  continuation.finish(throwing: error)
                  return
                }

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
                AILog.notice(code: .hybridPrimaryModelStreamingRequestFailed, """
                Primary model "\(primaryModel._modelName)" failed with error: \(error); falling \
                back to secondary model "\(secondaryModel._modelName)".
                """)
                let secondarySession = try self.getSession(for: .secondaryModel)
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
              if Task.isCancelled || error is CancellationError {
                continuation.finish(throwing: error)
                return
              }

              // Failure to create primary session.
              // Fallback to the second session if the first fails or is unavailable.
              AILog.notice(code: .hybridPrimarySessionInitializationFailed, """
              Primary model "\(primaryModel._modelName)" failed to initialize session with error: \
              \(error); falling back to secondary model "\(secondaryModel._modelName)".
              """)
              do {
                let secondarySession = try self.getSession(for: .secondaryModel)
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
    }

    private func getSession(for model: SessionModel) throws -> any _ModelSession {
      let languageModel = (model == .primaryModel) ? primaryModel : secondaryModel

      // 1. Check if it exists under lock.
      let existing = lock.withLock { state in
        (model == .primaryModel) ? state.primary : state.secondary
      }
      if let existing {
        return existing
      }

      // 2. Create it outside the lock.
      let session = try languageModel._startSession(tools: tools, instructions: instructions)

      // 3. Try to store it under lock.
      return lock.withLock { state in
        if model == .primaryModel {
          if let existing = state.primary { return existing }
          state.primary = session
        } else {
          if let existing = state.secondary { return existing }
          state.secondary = session
        }
        return session
      }
    }
  }
#endif // compiler(>=6.2.3)
