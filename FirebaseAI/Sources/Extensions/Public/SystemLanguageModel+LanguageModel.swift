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

  extension FirebaseAI.SystemLanguageModel: LanguageModel {
    static let modelName = "apple-foundation-models-system-language-model"

    public var _modelName: String {
      return FirebaseAI.SystemLanguageModel.modelName
    }

    public func _startSession(tools: [any ToolRepresentable]?,
                              instructions: String?) throws -> any _ModelSession {
      switch availability {
      case .available:
        break
      case let .unavailable(reason):
        throw GenerativeModelSession.GenerationError.assetsUnavailable(
          GenerativeModelSession.GenerationError.Context(debugDescription: """
          The Foundation Models `SystemLanguageModel` is unavailable: \(reason)
          """)
        )
      }

      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          var afmTools = [any FoundationModels.Tool]()
          for tool in tools ?? [] {
            // Only function calling tools are supported by Foundation Models.
            if !tool.toolRepresentation.isFoundationModeCompatible {
              assertionFailure("""
              The tool "\(tool.toolRepresentation)" is not supported when using the on-device model.
              """)
            }

            let functionDeclarations = tool.toolRepresentation.functionDeclarations ?? []
            for functionDeclaration in functionDeclarations {
              switch functionDeclaration.kind {
              case .manual:
                assertionFailure("""
                The manual function declaration "\(functionDeclaration)" is not supported by the
                Foundation Models framework; function declarations must be `FoundationModels.Tool`
                types for use with the on-device model.
                """)
                continue
              case let .foundationModels(afmTool):
                guard let afmTool = afmTool as? (any FoundationModels.Tool) else {
                  assertionFailure("""
                  The function declaration "\(afmTool)" in the tool "\(tool)" is not a
                  `FoundationModels.Tool` type.
                  """)
                  continue
                }
                afmTools.append(afmTool)
              }
            }
          }

          return LanguageModelSession(
            model: self.systemLanguageModel,
            tools: afmTools,
            instructions: instructions
          )
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM

      throw GenerativeModelSession.GenerationError.assetsUnavailable(
        GenerativeModelSession.GenerationError.Context(debugDescription: """
        Failed to start a `LanguageModelSession`. The Foundation Models `SystemLanguageModel` is not
        available on the current platform.
        """)
      )
    }
  }
#endif // compiler(>=6.2.3)
