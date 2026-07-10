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

#if compiler(>=6.4) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
  import FirebaseCore
  import Foundation
  import FoundationModels

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GeminiLanguageModel {
    public struct ModelConfig: Sendable, Hashable {
      let firebaseAppName: String
      let apiConfig: APIConfig
      let useLimitedUseAppCheckTokens: Bool

      let modelName: String
      let safetySettings: [SafetySetting]?
      let serverTools: [InternalGeminiTool]
      let geminiOptions: GeminiGenerationOptions?
      let requestOptions: RequestOptions

      var firebaseAI: FirebaseAI {
        let firebaseApp = FirebaseApp.app(name: firebaseAppName)
        return FirebaseAI.createInstance(
          app: firebaseApp,
          apiConfig: apiConfig,
          useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens
        )
      }
    }

    let modelConfig: ModelConfig
    let modelResourceName: String
    let firebaseInfo: FirebaseInfo
    let toolConfig: ToolConfig?
    let urlSession: URLSession

    init(modelName: String,
         modelResourceName: String,
         firebaseInfo: FirebaseInfo,
         apiConfig: APIConfig,
         safetySettings: [SafetySetting]? = nil,
         serverTools: [any GeminiTool]? = nil,
         toolConfig: ToolConfig? = nil,
         geminiOptions: GeminiGenerationOptions? = nil,
         requestOptions: RequestOptions = RequestOptions(),
         urlSession: URLSession = GenAIURLSession.default) {
      let serverTools: [InternalGeminiTool] = (serverTools ?? []).compactMap { geminiTool in
        switch geminiTool {
        case let googleSearch as GoogleSearch:
          return .googleSearch(googleSearch)
        case let googleMaps as GoogleMaps:
          return .googleMaps(googleMaps)
        case let urlContext as URLContext:
          return .urlContext(urlContext)
        case let codeExecution as CodeExecution:
          return .codeExecution(codeExecution)
        default:
          AILog.warning(
            code: .unsupportedGeminiServerTool,
            "Skipping unsupported Gemini server tool: \(geminiTool)"
          )
          return nil
        }
      }

      modelConfig = ModelConfig(
        firebaseAppName: firebaseInfo.app.name,
        apiConfig: apiConfig,
        useLimitedUseAppCheckTokens: firebaseInfo.useLimitedUseAppCheckTokens,
        modelName: modelName,
        safetySettings: safetySettings,
        serverTools: serverTools,
        geminiOptions: geminiOptions,
        requestOptions: requestOptions
      )
      self.modelResourceName = modelResourceName
      self.firebaseInfo = firebaseInfo
      self.toolConfig = toolConfig
      self.urlSession = urlSession
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel: FoundationModels.LanguageModel {
    public var capabilities: LanguageModelCapabilities {
      return LanguageModelCapabilities([
        .toolCalling,
        .vision,
        .reasoning,
        .guidedGeneration,
      ])
    }

    public var executorConfiguration: ModelConfig {
      return modelConfig
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GeminiGenerationOptions: Sendable, Equatable, Hashable {
    /// Supported modalities of the response.
    public var responseModalities: [ResponseModality]?

    /// Configuration options for generating images.
    public var imageConfig: ImageConfig?

    /// Whether summaries of the model's "thoughts" are included in responses.
    ///
    /// When `includeThoughts` is set to `true`, the model will return a summary of its internal
    /// thinking process alongside the final answer. This can provide valuable insight into how the
    /// model arrived at its conclusion, which is particularly useful for complex or creative tasks.
    ///
    /// If you don't specify a value for `includeThoughts` (`nil`), the model will use its default
    /// behavior (which is typically to not include thought summaries).
    public var includeThoughts: Bool?

    // TODO: We want to make the default for including thoughts `true`, figure out the best way to do that.
    public init(responseModalities: [ResponseModality]? = nil,
                imageConfig: ImageConfig? = nil,
                includeThoughts: Bool? = nil) {
      self.responseModalities = responseModalities
      self.imageConfig = imageConfig
      self.includeThoughts = includeThoughts
    }
  }
#endif // compiler(>=6.4) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
