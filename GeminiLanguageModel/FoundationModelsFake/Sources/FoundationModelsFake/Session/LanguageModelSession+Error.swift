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
    import Foundation
  #else
    public import Foundation
  #endif

  extension LanguageModelSession {
    /// Errors thrown by a language model session during request execution.
    ///
    /// - SeeAlso: [`LanguageModelSession.Error`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/error)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public enum Error: LocalizedError {
      /// An error indicating that a request was initiated while another request was in progress.
      case concurrentRequests

      /// An error indicating that the transcript was mutated while a request was in progress.
      case transcriptMutationWhileResponding
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension LanguageModelSession.Error: CustomDebugStringConvertible {
    /// A textual description of the error suitable for debugging.
    public var debugDescription: String {
      switch self {
      case .concurrentRequests:
        "A session can handle only one request at a time, but a new request started before "
          + "the previous one finished."
      case .transcriptMutationWhileResponding:
        "The transcript changed from outside the session while a request was running."
      }
    }
  }

  extension LanguageModelSession.Error {
    /// A localized message describing the error.
    public var errorDescription: String? {
      switch self {
      case .concurrentRequests:
        "The session received overlapping requests."
      case .transcriptMutationWhileResponding:
        "The transcript changed during a request."
      }
    }
  }

  extension LanguageModelSession.Error: Equatable {}

  extension LanguageModelSession.Error: Hashable {}

  extension LanguageModelSession {
    /// An error that wraps an underlying failure encountered while invoking a tool.
    ///
    /// - SeeAlso: [`LanguageModelSession.ToolCallError`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/toolcallerror)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public struct ToolCallError: Swift.Error, LocalizedError {
      /// The tool whose invocation produced the error.
      public var tool: any Tool

      /// The underlying error thrown during tool invocation.
      public var underlyingError: any Swift.Error

      /// Creates a tool call error wrapping an invocation failure.
      ///
      /// - Parameters:
      ///   - tool: The tool that produced the error.
      ///   - underlyingError: The underlying error that was thrown.
      public init(tool: any Tool, underlyingError: any Swift.Error) {
        self.tool = tool
        self.underlyingError = underlyingError
      }
    }
  }

  extension LanguageModelSession.ToolCallError {
    /// A localized message describing the tool call error.
    public var errorDescription: String? {
      "The tool '\(tool.name)' threw an error: \(underlyingError.localizedDescription)"
    }
  }
#endif  // compiler(>=6.4)
