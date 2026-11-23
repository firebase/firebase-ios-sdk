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

#if compiler(>=6.4)
  #if canImport(FoundationEssentials)
    public import FoundationEssentials
  #else
    public import Foundation
  #endif

  extension GeneratedContent {
    /// An error thrown when generated content cannot be parsed or converted to a target type.
    ///
    /// - SeeAlso: [`GeneratedContent.ParsingError`](https://developer.apple.com/documentation/foundationmodels/generatedcontent/parsingerror)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct ParsingError: LocalizedError, Sendable {
      /// The raw content that failed to parse.
      public var rawContent: String

      /// The underlying error that caused the parsing failure, if any.
      public var underlyingError: (any Error)?

      /// A description of the parsing failure.
      public var debugDescription: String

      /// Creates a parsing error with raw content, an underlying error, and a description.
      ///
      /// - Parameters:
      ///   - rawContent: The raw content that failed to parse.
      ///   - underlyingError: The underlying error that caused the failure, or `nil`.
      ///   - debugDescription: A description of the parsing failure.
      public init(rawContent: String, underlyingError: (any Error)? = nil, debugDescription: String)
      {
        self.rawContent = rawContent
        self.underlyingError = underlyingError
        self.debugDescription = debugDescription
      }
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeneratedContent.ParsingError: CustomDebugStringConvertible {
  }

  extension GeneratedContent.ParsingError {
    /// A localized description of the parsing error.
    public var errorDescription: String? {
      "The generated content couldn't be parsed."
    }
  }
#endif  // compiler(>=6.4)
