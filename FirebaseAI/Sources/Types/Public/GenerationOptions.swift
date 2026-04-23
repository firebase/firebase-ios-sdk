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
  import Foundation
  #if canImport(FoundationModels)
    import FoundationModels
  #endif // canImport(FoundationModels)

  public extension FirebaseAI {
    /// Options that control how the model generates its response to a prompt.
    ///
    /// This is a thin wrapper for the `FoundationModels.GenerationOptions` struct that is
    /// available on a wider range of operating system versions.
    struct GenerationOptions: Sendable, Equatable {
      protocol GenerationOptionsProtocol: Sendable, Equatable {}

      /// A type that defines how values are sampled from a probability distribution.
      public struct SamplingMode: Sendable, Equatable {
        protocol SamplingModeProtocol: Sendable, Equatable {}

        enum Kind {
          case greedy
          case randomTopK(k: Int, seed: UInt64?)
          case randomProbabilityThreshold(probabilityThreshold: Double, seed: UInt64?)
          case foundationModelsSamplingMode(any SamplingModeProtocol)
        }

        let kind: Kind

        init(kind: Kind) {
          self.kind = kind
        }

        /// A sampling mode that always chooses the most likely token.
        public static var greedy: GenerationOptions.SamplingMode {
          return SamplingMode(kind: .greedy)
        }

        /// A sampling mode that considers a fixed number of high-probability tokens.
        public static func random(top k: Int, seed: UInt64? = nil) -> GenerationOptions
          .SamplingMode {
          return SamplingMode(kind: .randomTopK(k: k, seed: seed))
        }

        /// A mode that considers a variable number of high-probability tokens based on the
        /// specified threshold.
        public static func random(probabilityThreshold: Double,
                                  seed: UInt64? = nil) -> GenerationOptions.SamplingMode {
          return SamplingMode(kind: .randomProbabilityThreshold(
            probabilityThreshold: probabilityThreshold,
            seed: seed
          ))
        }

        #if canImport(FoundationModels)
          @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
          @available(tvOS, unavailable)
          @available(watchOS, unavailable)
          init(_ samplingMode: FoundationModels.GenerationOptions.SamplingMode) {
            kind = .foundationModelsSamplingMode(samplingMode)
          }

          @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
          @available(tvOS, unavailable)
          @available(watchOS, unavailable)
          var samplingMode: FoundationModels.GenerationOptions.SamplingMode {
            switch kind {
            case .greedy:
              return FoundationModels.GenerationOptions.SamplingMode.greedy
            case let .randomTopK(k, seed):
              return FoundationModels.GenerationOptions.SamplingMode.random(top: k, seed: seed)
            case let .randomProbabilityThreshold(prob, seed):
              return FoundationModels.GenerationOptions.SamplingMode.random(
                probabilityThreshold: prob,
                seed: seed
              )
            case let .foundationModelsSamplingMode(samplingMode):
              guard let samplingMode = samplingMode as? FoundationModels.GenerationOptions
                .SamplingMode else {
                preconditionFailure("""
                \(Self.self).#\(#function): `samplingMode` must be a
                `FoundationModels.GenerationOptions.SamplingMode`.
                """)
              }

              return samplingMode
            }
          }
        #endif // canImport(FoundationModels)

        public static func == (lhs: SamplingMode, rhs: SamplingMode) -> Bool {
          switch (lhs.kind, rhs.kind) {
          case (.greedy, .greedy):
            return true
          case let (.randomTopK(lhsK, lhsSeed), .randomTopK(rhsK, rhsSeed)):
            return lhsK == rhsK && lhsSeed == rhsSeed
          case let (
            .randomProbabilityThreshold(lhsP, lhsSeed),
            .randomProbabilityThreshold(rhsP, rhsSeed)
          ):
            return lhsP == rhsP && lhsSeed == rhsSeed
          case let (.foundationModelsSamplingMode(lhsMode), .foundationModelsSamplingMode(rhsMode)):
            #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
              if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
                if let lhsMode = lhsMode as? FoundationModels.GenerationOptions.SamplingMode,
                   let rhsMode = rhsMode as? FoundationModels.GenerationOptions.SamplingMode {
                  return lhsMode == rhsMode
                }
              }
            #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
            return false
          default:
            return false
          }
        }
      }

      /// A sampling strategy for how the model picks tokens when generating a response.
      public var sampling: GenerationOptions.SamplingMode?

      /// Temperature influences the confidence of the model's response.
      public var temperature: Double?

      /// The maximum number of tokens the model is allowed to produce in its response.
      public var maximumResponseTokens: Int?

      // Opaque storage for Apple's type to support full round-tripping when created from it.
      private var _generationOptions: (any GenerationOptionsProtocol)?

      /// Creates generation options that control token sampling behavior.
      public init(sampling: GenerationOptions.SamplingMode? = nil, temperature: Double? = nil,
                  maximumResponseTokens: Int? = nil) {
        self.sampling = sampling
        self.temperature = temperature
        self.maximumResponseTokens = maximumResponseTokens
        _generationOptions = nil
      }

      #if canImport(FoundationModels)
        /// Initializes a ``FirebaseAI/GenerationOptions`` from a
        /// `FoundationModels.GenerationOptions`.
        ///
        /// - Parameter options: The `FoundationModels.GenerationOptions` to wrap.
        @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
        @available(tvOS, unavailable)
        @available(watchOS, unavailable)
        public init(_ options: FoundationModels.GenerationOptions) {
          _generationOptions = options
          sampling = options.sampling.map { SamplingMode(kind: .foundationModelsSamplingMode($0)) }
          temperature = options.temperature
          maximumResponseTokens = options.maximumResponseTokens
        }

        @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
        @available(tvOS, unavailable)
        @available(watchOS, unavailable)
        func toFoundationModels() -> FoundationModels.GenerationOptions {
          if let generationOptions = _generationOptions as? FoundationModels.GenerationOptions {
            return generationOptions
          }

          return FoundationModels.GenerationOptions(
            sampling: sampling?.samplingMode,
            temperature: temperature,
            maximumResponseTokens: maximumResponseTokens
          )
        }
      #endif // canImport(FoundationModels)

      public static func == (lhs: GenerationOptions, rhs: GenerationOptions) -> Bool {
        #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
          if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if let lhsOptions = lhs._generationOptions as? FoundationModels.GenerationOptions,
               let rhsOptions = rhs._generationOptions as? FoundationModels.GenerationOptions {
              return lhsOptions == rhsOptions
            }
          }
        #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM

        return lhs.sampling == rhs.sampling &&
          lhs.temperature == rhs.temperature &&
          lhs.maximumResponseTokens == rhs.maximumResponseTokens
      }
    }
  }

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    extension FoundationModels.GenerationOptions: FirebaseAI.GenerationOptions
      .GenerationOptionsProtocol {}

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    extension FoundationModels.GenerationOptions.SamplingMode: FirebaseAI.GenerationOptions
      .SamplingMode.SamplingModeProtocol {}
  #endif // canImport(FoundationModels)
#endif // compiler(>=6.2.3)
