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
  /// A type that executes generation requests for a language model.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`LanguageModelExecutor`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutor).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public protocol LanguageModelExecutor: Sendable {
    /// The configuration type required to initialize the executor.
    associatedtype Configuration: Hashable, Sendable

    /// The type of language model associated with this executor.
    associatedtype Model: LanguageModel

    /// Prepares the executor for generation using the given model and transcript.
    ///
    /// - Parameters:
    ///   - model: The model to prewarm.
    ///   - transcript: The transcript to prepare for generation.
    func prewarm(model: Self.Model, transcript: Transcript)

    /// Creates an executor with the specified configuration.
    ///
    /// - Parameter configuration: The configuration options for the executor.
    /// - Throws: An error if initialization fails.
    init(configuration: Self.Configuration) throws

    /// Generates content for a request, streaming events into a channel.
    ///
    /// - Parameters:
    ///   - request: The generation request to process.
    ///   - model: The model servicing the request.
    ///   - channel: The channel receiving streamed generation events.
    /// - Throws: An error if generation fails.
    nonisolated(nonsending) func respond(
      to request: LanguageModelExecutorGenerationRequest,
      model: Self.Model,
      streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws
  }

  extension LanguageModelExecutor {
    /// Prepares the executor for generation using the given model and transcript.
    ///
    /// - Parameters:
    ///   - model: The model to prewarm.
    ///   - transcript: The transcript to prepare for generation.
    public func prewarm(model: Self.Model, transcript: Transcript) {
    }
  }
#endif  // compiler(>=6.4)
