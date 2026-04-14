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
    final class SystemLanguageModel: Sendable {
      protocol SystemLanguageModelProtocol: Sendable {}

      private let _systemLanguageModel: (any SystemLanguageModelProtocol)?

      #if canImport(FoundationModels)
        @available(iOS 26.0, macOS 26.0, *)
        @available(tvOS, unavailable)
        @available(watchOS, unavailable)
        var systemLanguageModel: FoundationModels.SystemLanguageModel {
          guard let model = _systemLanguageModel as? FoundationModels.SystemLanguageModel else {
            assertionFailure("Model was nil in \(Self.self).#\(#function).")
            fatalError("SystemLanguageModel not available")
          }
          return model
        }
      #endif // canImport(FoundationModels)

      init(systemLanguageModel: (any SystemLanguageModelProtocol)?) {
        _systemLanguageModel = systemLanguageModel
      }

      public final var availability: SystemLanguageModel.Availability {
        #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
          if #available(iOS 26.0, macOS 26.0, *) {
            if let model = _systemLanguageModel as? FoundationModels.SystemLanguageModel {
              let systemAvail = model.availability
              switch systemAvail {
              case .available:
                return .available
              case let .unavailable(reason):
                switch reason {
                case .deviceNotEligible:
                  return .unavailable(.deviceNotEligible)
                case .appleIntelligenceNotEnabled:
                  return .unavailable(.appleIntelligenceNotEnabled)
                case .modelNotReady:
                  return .unavailable(.modelNotReady)
                @unknown default:
                  return .unavailable(.deviceNotEligible)
                }
              }
            }
          }
        #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        return .unavailable(.deviceNotEligible)
      }

      public final var isAvailable: Bool {
        #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
          if #available(iOS 26.0, macOS 26.0, *) {
            if let model = _systemLanguageModel as? FoundationModels.SystemLanguageModel {
              return model.isAvailable
            }
          }
        #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        return false
      }

      public struct UseCase: Sendable, Equatable {
        enum Kind {
          case general
          case contentTagging
        }

        let kind: Kind

        public static let general = UseCase(kind: .general)
        public static let contentTagging = UseCase(kind: .contentTagging)

        #if canImport(FoundationModels)
          @available(iOS 26.0, macOS 26.0, *)
          @available(tvOS, unavailable)
          @available(watchOS, unavailable)
          func toFoundationModels() -> FoundationModels.SystemLanguageModel.UseCase {
            switch kind {
            case .general:
              return FoundationModels.SystemLanguageModel.UseCase.general
            case .contentTagging:
              return FoundationModels.SystemLanguageModel.UseCase.contentTagging
            }
          }
        #endif // canImport(FoundationModels)
      }
    }
  }

  public extension FirebaseAI.SystemLanguageModel {
    struct Guardrails: Sendable, Equatable {
      enum Kind {
        case `default`
        case permissiveContentTransformations
      }

      let kind: Kind

      public static let `default` = Guardrails(kind: .default)

      public static let permissiveContentTransformations = Guardrails(
        kind: .permissiveContentTransformations
      )

      #if canImport(FoundationModels)
        @available(iOS 26.0, macOS 26.0, *)
        @available(tvOS, unavailable)
        @available(watchOS, unavailable)
        func toFoundationModels() -> FoundationModels.SystemLanguageModel.Guardrails {
          switch kind {
          case .default:
            return FoundationModels.SystemLanguageModel.Guardrails.default
          case .permissiveContentTransformations:
            return FoundationModels.SystemLanguageModel.Guardrails.permissiveContentTransformations
          }
        }
      #endif // canImport(FoundationModels)
    }
  }

  public extension FirebaseAI.SystemLanguageModel {
    @frozen enum Availability: Equatable, Sendable {
      @nonexhaustive
      public enum UnavailableReason: Equatable, Sendable {
        case deviceNotEligible

        case appleIntelligenceNotEnabled

        case modelNotReady
      }

      case available

      case unavailable(FirebaseAI.SystemLanguageModel.Availability.UnavailableReason)
    }

    static var `default`: FirebaseAI.SystemLanguageModel {
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, *) {
          return FirebaseAI
            .SystemLanguageModel(systemLanguageModel: FoundationModels.SystemLanguageModel.default)
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      return FirebaseAI.SystemLanguageModel(systemLanguageModel: nil)
    }

    convenience init(useCase: FirebaseAI.SystemLanguageModel.UseCase = .general,
                     guardrails: FirebaseAI.SystemLanguageModel.Guardrails = .default) {
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, *) {
          let model = FoundationModels.SystemLanguageModel(
            useCase: useCase.toFoundationModels(),
            guardrails: guardrails.toFoundationModels()
          )
          self.init(systemLanguageModel: model)
          return
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      self.init(systemLanguageModel: nil)
    }

    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      convenience init(_ systemLanguageModel: FoundationModels.SystemLanguageModel) {
        self.init(systemLanguageModel: systemLanguageModel)
      }
    #endif // canImport(FoundationModels)

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    final var supportedLanguages: Set<Locale.Language> {
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, *) {
          if let model = _systemLanguageModel as? FoundationModels.SystemLanguageModel {
            return model.supportedLanguages
          }
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      return []
    }

    final func supportsLocale(_ locale: Locale = Locale.current) -> Bool {
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, *) {
          if let model = _systemLanguageModel as? FoundationModels.SystemLanguageModel {
            return model.supportsLocale(locale)
          }
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      return false
    }
  }

  extension FirebaseAI.SystemLanguageModel.Availability.UnavailableReason: Hashable {}

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    extension FoundationModels.SystemLanguageModel: FirebaseAI.SystemLanguageModel
      .SystemLanguageModelProtocol {}
  #endif // canImport(FoundationModels)
#endif // compiler(>=6.2.3)
