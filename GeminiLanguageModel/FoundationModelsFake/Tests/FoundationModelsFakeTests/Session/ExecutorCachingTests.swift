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
  import Foundation
  import Synchronization
  import Testing

  @testable import FoundationModelsFake

  /// Tests for per-session executor caching, matching Apple's framework.
  @Suite("Per-session executor caching")
  struct ExecutorCachingTests {
    /// A model whose executors record their creation and label their responses.
    struct LabelingModel: LanguageModel {
      /// Records executor creation per configuration name.
      final class Log: Sendable {
        /// Mutable log state.
        private struct State: Sendable {
          /// Executor creations so far, per configuration name.
          var creations: [String: Int] = [:]

          /// Configuration names whose next creation throws.
          var failNext: Set<String> = []

          /// Prewarm calls, as executor labels.
          var prewarms: [String] = []
        }

        /// The log state.
        private let state = Mutex(State())

        /// Records a creation of `name` and returns its label, or throws if a failure was queued.
        func create(_ name: String) throws -> String {
          try state.withLock { state in
            if state.failNext.remove(name) != nil {
              throw CreationError()
            }
            state.creations[name, default: 0] += 1
            return "\(name)#\(state.creations[name, default: 0])"
          }
        }

        /// Makes the next creation of `name` throw.
        func failNextCreation(of name: String) {
          state.withLock { _ = $0.failNext.insert(name) }
        }

        /// Records a prewarm by the executor labeled `label`.
        func prewarmed(_ label: String) {
          state.withLock { $0.prewarms.append(label) }
        }

        /// The number of executors created for `name`.
        func creations(of name: String) -> Int {
          state.withLock { $0.creations[name, default: 0] }
        }

        /// The prewarm calls so far, as executor labels.
        var prewarms: [String] {
          state.withLock { $0.prewarms }
        }
      }

      /// The error a queued creation failure throws.
      struct CreationError: Error {}

      /// The executor, which answers with its own label.
      struct Executor: LanguageModelExecutor {
        /// The model this executor serves.
        typealias Model = LabelingModel

        /// The configuration: a name and the shared log. Equality uses the name only.
        struct Configuration: Hashable, Sendable {
          /// The configuration name.
          let name: String

          /// The shared log.
          let log: Log

          /// Compares names only.
          static func == (lhs: Configuration, rhs: Configuration) -> Bool {
            lhs.name == rhs.name
          }

          /// Hashes the name only.
          func hash(into hasher: inout Hasher) {
            hasher.combine(name)
          }
        }

        /// This executor's label.
        let label: String

        /// The shared log.
        let log: Log

        /// Creates an executor, recording it in the log.
        init(configuration: Configuration) throws {
          label = try configuration.log.create(configuration.name)
          log = configuration.log
        }

        /// Records the prewarm.
        func prewarm(model: LabelingModel, transcript: Transcript) {
          log.prewarmed(label)
        }

        /// Answers with this executor's label.
        nonisolated(nonsending) func respond(
          to request: LanguageModelExecutorGenerationRequest,
          model: LabelingModel,
          streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
          await channel.send(.response(action: .appendText(label, tokenCount: 1)))
        }
      }

      /// The configuration name.
      let name: String

      /// The shared log.
      let log: Log

      /// No capabilities needed.
      var capabilities: LanguageModelCapabilities { LanguageModelCapabilities([]) }

      /// The configuration.
      var executorConfiguration: Executor.Configuration {
        Executor.Configuration(name: name, log: log)
      }
    }

    /// Returns a model with a unique configuration name and a fresh log.
    static func makeModel() -> LabelingModel {
      LabelingModel(name: "model-\(UUID().uuidString)", log: LabelingModel.Log())
    }

    @Test
    func executorIsCreatedLazilyAndReusedWithinASession() async throws {
      let model = Self.makeModel()
      let session = LanguageModelSession(model: model)
      let createdAtInit = model.log.creations(of: model.name)

      session.prewarm()
      session.prewarm(promptPrefix: Prompt("Hello"))
      let first = try await session.respond(to: "One").content
      let second = try await session.respond(to: "Two").content
      let streamed = try await session.streamResponse(to: "Three").collect().content

      #expect(createdAtInit == 0)
      #expect(model.log.creations(of: model.name) == 1)
      #expect([first, second, streamed] == Array(repeating: "\(model.name)#1", count: 3))
      #expect(model.log.prewarms == Array(repeating: "\(model.name)#1", count: 2))
    }

    @Test
    func sessionsNeverShareAnExecutor() async throws {
      let model = Self.makeModel()
      let first = LanguageModelSession(model: model)
      let second = LanguageModelSession(model: model)

      first.prewarm()
      let firstAnswer = try await first.respond(to: "One").content
      let secondAnswer = try await second.respond(to: "One").content

      #expect(firstAnswer == "\(model.name)#1")
      #expect(secondAnswer == "\(model.name)#2")
      #expect(model.log.prewarms == ["\(model.name)#1"])
    }

    @Test
    func failedCreationIsRetriedOnTheNextCall() async throws {
      let model = Self.makeModel()
      let session = LanguageModelSession(model: model)
      model.log.failNextCreation(of: model.name)

      await #expect(throws: LabelingModel.CreationError.self) {
        try await session.respond(to: "One")
      }
      let answer = try await session.respond(to: "Two").content

      #expect(answer == "\(model.name)#1")
    }

    @Test
    func failedCreationDuringPrewarmIsSilentAndRetried() async throws {
      let model = Self.makeModel()
      let session = LanguageModelSession(model: model)
      model.log.failNextCreation(of: model.name)

      session.prewarm()
      let answer = try await session.respond(to: "One").content

      #expect(model.log.prewarms.isEmpty)
      #expect(answer == "\(model.name)#1")
    }
  }
#endif  // compiler(>=6.4)
