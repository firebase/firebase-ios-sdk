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

public extension GenerativeModel {
  /// An error that may occur while generating a response.
  enum GenerationError: Error {
    /// The context in which the error occurred.
    public struct Context: Sendable {
      /// A debug description to help developers diagnose issues during development.
      ///
      /// This string is not localized and is not appropriate for display to end users.
      public let debugDescription: String

      /// Creates a context.
      ///
      /// - Parameters:
      ///   - debugDescription: The debug description to help developers diagnose issues during
      /// development.
      public init(debugDescription: String) {
        self.debugDescription = debugDescription
      }
    }

    /// An error that indicates the session failed to deserialize a valid generable type from model
    /// output.
    ///
    /// This can happen if generation was terminated early.
    case decodingFailure(GenerativeModel.GenerationError.Context)
  }
}
