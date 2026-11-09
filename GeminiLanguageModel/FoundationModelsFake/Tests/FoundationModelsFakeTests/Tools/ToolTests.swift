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
  import Testing

  @testable import FoundationModelsFake

  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  /// Empty tool arguments.
  private struct MockArguments: Generable {
    /// An object schema with no properties.
    static var generationSchema: GenerationSchema {
      GenerationSchema(
        type: MockArguments.self,
        description: "Mock arguments",
        properties: []
      )
    }

    /// Creates empty arguments, ignoring `content`.
    init(_ content: GeneratedContent) throws {
    }

    /// An empty object.
    var generatedContent: GeneratedContent {
      GeneratedContent(properties: [:])
    }
  }

  /// A tool that uses the default name and schema settings.
  private struct DefaultNameTool: Tool {
    /// The tool's description.
    var description: String {
      "A tool with default name and schema settings."
    }

    /// Returns a fixed string.
    func call(arguments: MockArguments) async throws -> String {
      "tool output"
    }
  }

  /// A tool that overrides its name, schema, and instructions setting.
  private struct CustomTool: Tool {
    /// The tool's name.
    var name: String {
      "custom_name"
    }

    /// The tool's description.
    var description: String {
      "A tool with custom configuration."
    }

    /// Whether the schema is included in instructions.
    var includesSchemaInInstructions: Bool {
      false
    }

    /// The tool's parameter schema.
    var parameters: GenerationSchema {
      GenerationSchema(
        __name: "CustomArguments",
        description: "Custom arguments",
        properties: []
      )
    }

    /// Returns two fixed lines.
    func call(arguments: MockArguments) async throws -> [String] {
      ["output line 1", "output line 2"]
    }
  }

  @Suite("Tool Tests")
  struct ToolTests {
    @Test
    func toolDefaultProperties() {
      let tool = DefaultNameTool()

      #expect(tool.name == "DefaultNameTool")
      #expect(tool.includesSchemaInInstructions == true)
      #expect(tool.parameters.name == MockArguments.generationSchema.name)
    }

    @Test
    func toolCustomProperties() {
      let tool = CustomTool()

      #expect(tool.name == "custom_name")
      #expect(tool.includesSchemaInInstructions == false)
    }

    @Test
    func toolExecution() async throws {
      let tool = DefaultNameTool()
      let arguments = try MockArguments(GeneratedContent(properties: [:]))

      let output = try await tool.call(arguments: arguments)

      #expect(output == "tool output")
    }
  }
#endif  // compiler(>=6.4)
