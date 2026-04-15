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
    /// An on-device text generation model provided by Apple's Foundation Models framework.
    ///
    /// This is a thin wrapper for the `FoundationModels.SystemLanguageModel` class that is
    /// available on a wider range of operating system versions. For more details about the
    /// underlying `SystemLanguageModel`, see the Apple
    /// [documentation](https://developer.apple.com/documentation/FoundationModels/SystemLanguageModel).
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

      /// The availability status for the on-device model.
      public var availability: SystemLanguageModel.Availability {
        #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
          if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if let model = _systemLanguageModel as? FoundationModels.SystemLanguageModel {
              switch model.availability {
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

      /// Returns `true` if the on-device model is available for use.
      ///
      /// For specific availability details, see ``FirebaseAI/SystemLanguageModel/availability``.
      public var isAvailable: Bool {
        #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
          if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if let model = _systemLanguageModel as? FoundationModels.SystemLanguageModel {
              return model.isAvailable
            }
          }
        #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        return false
      }

      /// The types of use cases that the on-device model is tuned for.
      ///
      /// For more details, see the Apple [documentation
      /// ](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase).
      public struct UseCase: Sendable, Equatable {
        enum Kind {
          case general
          case contentTagging
        }

        let kind: Kind

        /// The default use case for general model tasks.
        ///
        /// This use case provides the closest equivalent to the standard Gemini model behavior. For
        /// more details, see the Apple
        /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase/general).
        public static let general = UseCase(kind: .general)

        /// A use case for content tagging and categorization tasks.
        ///
        /// For more details, see the Apple
        /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase/contenttagging).
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
    /// Settings for controlling how potentially harmful content is blocked or flagged by the model.
    ///
    /// Guardrails are roughly equivalent to ``SafetySetting``s for Gemini models. For more details,
    /// see the Apple
    /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails).
    struct Guardrails: Sendable, Equatable {
      enum Kind {
        case `default`
        case permissiveContentTransformations
      }

      let kind: Kind

      /// The default guardrail settings for the on-device model.
      ///
      /// For more details, see the Apple
      /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails/default).
      public static let `default` = Guardrails(kind: .default)

      /// Guardrail settings that are less restrictive for content transformation prompts.
      ///
      /// Content transformation includes tasks such as summarizing or rewriting text. For more
      /// details, see the Apple
      /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails/permissivecontenttransformations).
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
    /// Availability states for the on-device model.
    @frozen enum Availability: Equatable, Sendable {
      /// Reasons that the on-device model is in the
      /// ``FirebaseAI/SystemLanguageModel/Availability/unavailable(_:)`` state.
      ///
      /// For more details, see the Apple
      /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum).
      @nonexhaustive
      public enum UnavailableReason: Equatable, Sendable {
        /// The device does not support the on-device model.
        ///
        /// For more details, see the Apple
        /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason/devicenoteligible).
        case deviceNotEligible

        /// The user does not have Apple Intelligence enabled on their device.
        ///
        /// Apple Intelligence is required to use the on-device model. Unlike ``deviceNotEligible``,
        /// this unavailable reason means that the device is capable on running the on-device model.
        /// For more details, see the Apple
        /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason/appleintelligencenotenabled).
        case appleIntelligenceNotEnabled

        /// The on-device model isn't available on the user's device.
        ///
        /// For more details, see the Apple
        /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason/modelnotready).
        case modelNotReady
      }

      /// The on-device model is ready and available for use.
      ///
      /// For more details, see the Apple
      /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/available).
      case available

      /// The on-device model is not available for the specified reason.
      ///
      /// For more details, see the Apple
      /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailable(_:)).
      case unavailable(FirebaseAI.SystemLanguageModel.Availability.UnavailableReason)
    }

    /// Returns the on-device model configured with the default settings.
    ///
    /// For more details, see the Apple
    /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/default).
    static var `default`: FirebaseAI.SystemLanguageModel {
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          return FirebaseAI
            .SystemLanguageModel(systemLanguageModel: FoundationModels.SystemLanguageModel.default)
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      return FirebaseAI.SystemLanguageModel(systemLanguageModel: nil)
    }

    /// Initializes on-device text generation model provided by Apple's Foundation Models framework.
    ///
    /// For more details, see the Apple
    /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/init(usecase:guardrails:)).
    ///
    /// - Parameters:
    ///   - useCase: The ``UseCase`` that the model is tuned for; defaults to ``UseCase/general``.
    ///   - guardrails: The ``Guardrails`` that configure how the model handles potentially harmful
    ///     content; defaults to ``Guardrails/default``.
    convenience init(useCase: FirebaseAI.SystemLanguageModel.UseCase = .general,
                     guardrails: FirebaseAI.SystemLanguageModel.Guardrails = .default) {
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
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
      /// Initializes a ``FirebaseAI/SystemLanguageModel`` with a
      /// `FoundationModels.SystemLanguageModel`.
      ///
      /// This initializer may be used to support features that are not supported by the wrapper,
      /// such as providing a `SystemLanguageModel.Adapter`.
      ///
      /// - Parameter systemLanguageModel: The `FoundationModels.SystemLanguageModel` to wrap.
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      convenience init(_ systemLanguageModel: FoundationModels.SystemLanguageModel) {
        self.init(systemLanguageModel: systemLanguageModel)
      }
    #endif // canImport(FoundationModels)

    /// Returns the languages supported by the on-device model.
    ///
    /// If the model is not available on the current platform this returns an empty set. For more
    /// details, see the Apple
    /// [documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/supportedlanguages).
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    var supportedLanguages: Set<Locale.Language> {
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          if let model = _systemLanguageModel as? FoundationModels.SystemLanguageModel {
            return model.supportedLanguages
          }
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      return []
    }

    /// Returns `true` if the specified `Locale` is supported by the on-device model.
    ///
    /// Defaults to the device's current `Locale`. If the model is not available on the current
    /// platform, this returns `false`.
    func supportsLocale(_ locale: Locale = Locale.current) -> Bool {
      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
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
