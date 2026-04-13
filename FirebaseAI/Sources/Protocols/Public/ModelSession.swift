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
  public protocol _ModelSession: Sendable {
    var _hasHistory: Bool { get }

    nonisolated(nonsending) func _respond(to prompt: [any Part],
                                          schema: FirebaseAI.GenerationSchema?,
                                          includeSchemaInPrompt: Bool,
                                          options: GenerationConfig?) async throws
      -> _ModelSessionResponse

    @available(macOS 12.0, watchOS 8.0, *)
    func _streamResponse(to prompt: [any Part],
                         schema: FirebaseAI.GenerationSchema?,
                         includeSchemaInPrompt: Bool,
                         options: GenerationConfig?)
      -> sending AsyncThrowingStream<_ModelSessionResponse, any Error>
  }
#endif // compiler(>=6.2.3)
