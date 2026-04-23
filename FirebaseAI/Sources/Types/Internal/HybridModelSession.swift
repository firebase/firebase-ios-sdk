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

    var _hasHistory: Bool {
      return primary._hasHistory || secondary._hasHistory
    }

    func _respond(to prompt: [any Part], schema: FirebaseAI.GenerationSchema?,
                  includeSchemaInPrompt: Bool, options: any GenerationOptionsRepresentable)
      async throws -> _ModelSessionResponse {
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

    @available(macOS 12.0, watchOS 8.0, *)
    func _streamResponse(to prompt: [any Part], schema: FirebaseAI.GenerationSchema?,
                         includeSchemaInPrompt: Bool,
                         options: any GenerationOptionsRepresentable)
      -> sending AsyncThrowingStream<_ModelSessionResponse, any Error> {
      return AsyncThrowingStream { continuation in
        let task = Task {
          // First try the primary session.
          let stream = primary._streamResponse(
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
            // Do not fallback to second session if the primary session contains history.
            if primary._hasHistory {
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

            for try await snapshot in stream {
              continuation.yield(snapshot)
            }
            continuation.finish()
          }
        }
        continuation.onTermination = { _ in task.cancel() }
      }
    }
  }
#endif // compiler(>=6.2.3)
