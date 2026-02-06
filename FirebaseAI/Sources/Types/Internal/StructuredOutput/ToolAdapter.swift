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
  internal import FoundationModels

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  struct ToolAdapter<Wrapped: FirebaseTool>: FoundationModels.Tool {
    // MARK: - Associated Types

    typealias Arguments = ToolArgumentsAdaptor<Wrapped.Arguments>
    typealias Output = ToolOutputAdaptor<Wrapped.Output>

    // MARK: - Stored Properties

    /// The wrapped FirebaseTool instance.
    private let wrappedTool: Wrapped

    var name: String {
      return wrappedTool.name
    }

    var description: String {
      return wrappedTool.description
    }

    var includesSchemaInInstructions: Bool {
      return wrappedTool.includesSchemaInInstructions
    }

    let parameters: GenerationSchema

    // MARK: - Initialization

    init(tool: Wrapped, parameters: GenerationSchema) {
      self.parameters = parameters
      wrappedTool = tool
    }

    // MARK: - Tool Protocol Implementation

    func call(arguments: Self.Arguments) async throws -> Self.Output {
      // Forward the call to the wrapped FirebaseTool
      let output = try await wrappedTool.call(arguments: arguments.toGenerable())
      return Output(output: output)
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  struct ToolArgumentsAdaptor<Wrapped: FirebaseGenerable>: ConvertibleFromGeneratedContent {
    private let value: Wrapped

    init(_ content: GeneratedContent) throws {
      value = try Wrapped(ModelOutput(content))
    }

    func toGenerable() -> Wrapped {
      return value
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  struct ToolOutputAdaptor<Wrapped: ConvertibleToModelOutput>: ConvertibleToGeneratedContent {
    private let output: Wrapped

    init(output: Wrapped) {
      self.output = output
    }

    var generatedContent: GeneratedContent {
      return output.modelOutput.generatedContent
    }
  }
#endif // canImport(FoundationModels)
