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
  #if canImport(FoundationModels)
    import FoundationModels
  #endif // canImport(FoundationModels)

  /// A type that represents options for controlling model response generation.
  ///
  /// For Gemini models, this may be a ``GenerationConfig`` value. For the `SystemLanguageModel`
  /// provided by the Apple Foundation Models framework, this may be a
  /// ``FirebaseAI/GenerationOptions`` or a `Foundation Models`
  /// [`GenerationOptions`](https://developer.apple.com/documentation/foundationmodels/generationoptions)
  /// value. For hybrid (on-device and cloud) configurations, use
  /// ``hybrid(gemini:foundationModels:)`` to specify options for each model.
  public protocol GenerationOptionsRepresentable: Sendable {
    /// Options for controlling model response generation.
    var responseGenerationOptions: ResponseGenerationOptions { get }
  }

  extension GenerationConfig: GenerationOptionsRepresentable {
    public var responseGenerationOptions: ResponseGenerationOptions {
      return ResponseGenerationOptions(geminiGenerationConfig: self)
    }
  }

  extension FirebaseAI.GenerationOptions: GenerationOptionsRepresentable {
    public var responseGenerationOptions: ResponseGenerationOptions {
      return ResponseGenerationOptions(foundationModelsGenerationOptions: self)
    }
  }

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    extension FoundationModels.GenerationOptions: GenerationOptionsRepresentable {
      public var responseGenerationOptions: ResponseGenerationOptions {
        return ResponseGenerationOptions(
          foundationModelsGenerationOptions: FirebaseAI.GenerationOptions(self)
        )
      }
    }
  #endif // canImport(FoundationModels)

  public extension GenerationOptionsRepresentable where Self == ResponseGenerationOptions {
    /// The default response generation options for a model.
    static var `default`: ResponseGenerationOptions { return ResponseGenerationOptions() }

    /// Returns response generation options for Gemini requests.
    ///
    /// - Parameter generationConfig: Generation options for Gemini models.
    static func gemini(_ generationConfig: GenerationConfig) -> ResponseGenerationOptions {
      return generationConfig.responseGenerationOptions
    }

    /// Returns response generation options for on-device requests.
    ///
    /// - Parameter generationOptions: Generation options for the on-device `SystemLanguageModel`
    ///   provided by the Foundation Models framework.
    static func foundationModels(_ generationOptions: FirebaseAI.GenerationOptions)
      -> ResponseGenerationOptions {
      return generationOptions.responseGenerationOptions
    }

    #if canImport(FoundationModels)
      /// Returns response generation options for on-device requests.
      ///
      /// - Parameter generationOptions: Generation options for the on-device `SystemLanguageModel`
      ///   provided by the Foundation Models framework.
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      static func foundationModels(_ generationOptions: FoundationModels.GenerationOptions)
        -> ResponseGenerationOptions {
        return generationOptions.responseGenerationOptions
      }

      /// Returns response generation options for hybrid (on-device and cloud) requests.
      ///
      /// - Parameters:
      ///   - gemini: Generation options for Gemini models.
      ///   - foundationModels: Generation options for the on-device `SystemLanguageModel` provided
      ///     by the Foundation Models framework.
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      static func hybrid(gemini: GenerationConfig,
                         foundationModels: FoundationModels.GenerationOptions)
        -> ResponseGenerationOptions {
        return ResponseGenerationOptions(
          geminiGenerationConfig: gemini,
          foundationModelsGenerationOptions: FirebaseAI.GenerationOptions(foundationModels)
        )
      }
    #endif // canImport(FoundationModels)

    /// Returns response generation options for hybrid (on-device and cloud) requests.
    ///
    /// - Parameters:
    ///   - gemini: Generation options for Gemini models.
    ///   - foundationModels: Generation options for the on-device `SystemLanguageModel` provided by
    ///     the Foundation Models framework.
    static func hybrid(gemini: GenerationConfig,
                       foundationModels: FirebaseAI.GenerationOptions)
      -> ResponseGenerationOptions {
      return ResponseGenerationOptions(
        geminiGenerationConfig: gemini,
        foundationModelsGenerationOptions: foundationModels
      )
    }
  }

#endif // compiler(>=6.2.3)
