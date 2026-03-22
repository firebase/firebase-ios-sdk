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

#if compiler(>=6.2)
  #if canImport(FoundationModels)
    import FoundationModels
  #endif // canImport(FoundationModels)

  public protocol FunctionTool<Arguments, Output>: ToolRepresentable {
    associatedtype Arguments: FirebaseAI.ConvertibleFromGeneratedContent
    associatedtype Output: FirebaseAI.ConvertibleToGeneratedContent

    var name: String { get }
    var description: String { get }
    var parametersSchema: FirebaseAI.GenerationSchema { get }
    var responseSchema: FirebaseAI.GenerationSchema? { get }
    var includesSchemaInInstructions: Bool { get }

    @Sendable func call(arguments: Self.Arguments) async throws -> Self.Output
  }

  public extension FunctionTool {
    var name: String { String(describing: Self.self) }
    var responseSchema: FirebaseAI.GenerationSchema? { nil }
    var includesSchemaInInstructions: Bool { true }
    var toolRepresentation: FirebaseAILogic.Tool {
      return FirebaseAILogic.Tool.autoFunctionDeclaration(self)
    }
  }

  // MARK: - Default `parametersSchema` Implementations

  public extension FunctionTool where Self.Arguments: FirebaseAI.Generable {
    var parametersSchema: FirebaseAI.GenerationSchema { Arguments.firebaseGenerationSchema }
  }

  // MARK: - Default `responseSchema` Implementations

  public extension FunctionTool where Self.Output: FirebaseAI.Generable {
    // Default implementation for `responseSchema` if a Firebase AI Logic `FunctionTool`'s
    // associated type `Output` conforms to `FirebaseAI.Generable`, in which case the type provides
    // a Firebase schema in its `firebaseGenerationSchema` property.
    var responseSchema: FirebaseAI.GenerationSchema? { Output.firebaseGenerationSchema }
  }

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public extension FoundationModels.Tool
      where Self.Output: FoundationModels.ConvertibleToGeneratedContent {
      // Default implementation for `responseSchema` if a Foundation Models `Tool`'s associated type
      // `Output` conforms to `ConvertibleToGeneratedContent`, in which case the `Tool`'s output can
      // be used by Gemini but does not have an explicit schema.
      // Note: an output schema is not used by Foundation Models and is optional with Gemini models.
      var responseSchema: FirebaseAI.GenerationSchema? { nil }
    }

    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public extension FoundationModels.Tool where Self.Output: FoundationModels.Generable {
      // Default implementation for `responseSchema` if a Foundation Models `Tool`'s associated type
      // `Output` conforms to `Generable`, in which case the type provides a Foundation Models
      // schema in its `generationSchema` property.
      // Note: An output schema is not used by Foundation Models but provides additional context to
      // Gemini models.
      var responseSchema: FirebaseAI.GenerationSchema? {
        FirebaseAI.GenerationSchema(Output.generationSchema)
      }
    }
  #endif // canImport(FoundationModels)
#endif // compiler(>=6.2)
