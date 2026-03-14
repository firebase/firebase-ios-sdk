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

#if compiler(>=6.2)
  public extension FirebaseAI {
    protocol ConvertibleFromGeneratedContent {
      init(_ content: FirebaseAI.GeneratedContent) throws
    }
  }

  extension String: FirebaseAI.ConvertibleFromGeneratedContent {
    public init(_ content: FirebaseAI.GeneratedContent) throws {
      guard case let .string(value) = content.kind else {
        throw GenerativeModelSession.GenerationError.decodingFailure(
          GenerativeModelSession.GenerationError.Context(debugDescription: """
          Unsupported FirebaseAI.GeneratedContent.Kind '\(content.kind)' for type String.
          """)
        )
      }

      self = value
    }
  }
#endif // compiler(>=6.2)
