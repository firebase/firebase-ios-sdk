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

#if canImport(FoundationModels) && compiler(>=6.4)
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel {
    /// Configuration for Gemini internal thinking process.
    public struct Thinking: Sendable, Hashable {
      /// Modes for returning thought summaries from the model.
      public enum SummaryMode: String, Sendable, Hashable {
        /// The model automatically outputs thought summaries when reasoning.
        case auto

        /// Thought summaries are not returned.
        case off
      }

      /// The configuration for returning thought summaries.
      public var summaries: SummaryMode?

      /// Creates a thinking configuration.
      ///
      /// - Parameter summaries: The configuration mode for returning thought summaries.
      ///   Defaults to `nil`.
      public init(summaries: SummaryMode? = nil) {
        self.summaries = summaries
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
