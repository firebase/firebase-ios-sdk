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

final class HybridModelSession: ModelSession {
  private let primary: any ModelSession
  private let secondary: any ModelSession

  init(primary: any ModelSession, secondary: any ModelSession) {
    self.primary = primary
    self.secondary = secondary
  }

  var hasHistory: Bool {
    return primary.hasHistory || secondary.hasHistory
  }

  func respondTo(promptParts: [any Part], schema: FirebaseAI.GenerationSchema?,
                 includeSchemaInPrompt: Bool,
                 options: GenerationConfig?) async throws -> ModelSessionResponse {
    do {
      // Try the primary model
      return try await primary.respondTo(
        promptParts: promptParts,
        schema: schema,
        includeSchemaInPrompt: includeSchemaInPrompt,
        options: options
      )
    } catch {
      // Do not fallback to other other sessions if the current session contains history.
      if primary.hasHistory {
        throw error
      }

      return try await secondary.respondTo(
        promptParts: promptParts,
        schema: schema,
        includeSchemaInPrompt: includeSchemaInPrompt,
        options: options
      )
    }
  }

  @available(macOS 12.0, watchOS 8.0, *)
  func streamResponseTo(promptParts: [any Part], schema: FirebaseAI.GenerationSchema?,
                        includeSchemaInPrompt: Bool,
                        options: GenerationConfig?)
    -> sending AsyncThrowingStream<ModelSessionResponse, any Error> {
    return AsyncThrowingStream { continuation in
      let task = Task {
        let stream = primary.streamResponseTo(
          promptParts: promptParts,
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
          // Do not fallback to other other sessions if the current session contains history.
          if primary.hasHistory {
            continuation.finish(throwing: error)
            return
          }

          let stream = secondary.streamResponseTo(
            promptParts: promptParts,
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
