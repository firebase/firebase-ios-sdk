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

#if canImport(FoundationModels)
  import FoundationModels

  // TODO: Wrap `FoundationModels.SystemLanguageModel` in type-erased box to simplify iOS 15 hybrid.
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FoundationModels.SystemLanguageModel: LanguageModel {
    static let modelName = "apple-foundation-models-system-language-model"

    var modelName: String { FoundationModels.SystemLanguageModel.modelName }

    func startSession(tools: [any ToolRepresentable]?,
                      instructions: String?) throws -> any ModelSession {
      switch availability {
      case .available:
        break
      case let .unavailable(reason):
        throw FoundationModels.LanguageModelSession.GenerationError.assetsUnavailable(
          LanguageModelSession.GenerationError.Context(debugDescription: """
          The Foundation Models `SystemLanguageModel` is unavailable: \(reason)
          """)
        )
      }

      var afmTools = [any FoundationModels.Tool]()
      // Only function calling tools are supported by Foundation Models.
      for tool in tools ?? [] {
        // Skips any unsupported tools such as `GoogleMaps` or `CodeExecution` since they are only
        // supported by Gemini models.
        // TODO: Decide whether to throw for unsupported `FirebaseAILogic.Tool` types or ignore.
        let functionDeclarations = tool.toolRepresentation.functionDeclarations ?? []
        for functionDeclaration in functionDeclarations {
          switch functionDeclaration.kind {
          case .manual:
            // TODO: Decide whether ignore manual function calling declarations, throw or assert.
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
      return LanguageModelSession(tools: afmTools, instructions: instructions)
    }
  }
#endif // canImport(FoundationModels)
