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
  import Synchronization
  import Testing

  @testable import FoundationModelsFake

  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  // MARK: - Test Support Types

  /// A minimal tool arguments type for dynamic instructions unit tests.
  private struct TestToolArguments: ConvertibleFromGeneratedContent, Generable {
    /// The generation schema for empty arguments.
    static var generationSchema: GenerationSchema {
      GenerationSchema(type: Self.self, description: nil, properties: [])
    }

    /// Creates arguments from generated content.
    init(_ content: GeneratedContent) throws {}

    /// The generated content representation.
    var generatedContent: GeneratedContent {
      GeneratedContent(properties: [:])
    }
  }

  /// A configurable tool for testing dynamic instructions flattening and deduplication.
  private struct TestDynamicTool: Tool {
    /// The tool's arguments type.
    typealias Arguments = TestToolArguments

    /// The unique name of the tool.
    let name: String

    /// The description of the tool.
    let description: String

    /// Whether the tool's schema is included in instructions.
    let includeSchema: Bool

    /// Optional reference box for verifying pre-evaluation binder invocation.
    let bindBox: BindStateBox?

    /// Creates a test dynamic tool.
    init(
      name: String,
      description: String = "Test tool",
      includeSchema: Bool = true,
      bindBox: BindStateBox? = nil
    ) {
      self.name = name
      self.description = description
      self.includeSchema = includeSchema
      self.bindBox = bindBox
    }

    /// Whether the framework includes this tool's schema in instructions.
    var includesSchemaInInstructions: Bool {
      includeSchema
    }

    /// Executes the tool.
    func call(arguments: TestToolArguments) async throws -> String {
      description
    }
  }

  /// A custom `InstructionsRepresentable` value that is not `Instructions`.
  private struct CustomInstructionsPiece: InstructionsRepresentable {
    /// The text of the piece.
    let text: String

    /// The instructions representation of the piece.
    var instructionsRepresentation: Instructions {
      Instructions(text)
    }
  }

  /// An identifiable item for testing `DynamicInstructions.ForEach`.
  private struct TestIdentifiableSkill: Identifiable, Sendable {
    /// The stable identifier of the item.
    let id: String

    /// The guidance text for the item.
    let guidance: String
  }

  /// A reference box used to simulate `@SessionProperty` binding before `body` evaluation.
  private final class BindStateBox: Sendable {
    /// The bound value protected by a mutex.
    let value = Mutex<String>("unbound")
  }

  /// A protocol implemented by test nodes that hold a `BindStateBox`.
  private protocol BindableTestNode {
    /// The reference box to bind when visited.
    var bindBox: BindStateBox { get }
  }

  /// An empty dynamic instructions struct.
  private struct EmptyCompositeInstructions: DynamicInstructions {
    /// The body of the dynamic instructions.
    var body: some DynamicInstructions {}
  }

  /// A dynamic instructions struct containing only tools.
  private struct ToolsOnlyCompositeInstructions: DynamicInstructions {
    /// The body of the dynamic instructions.
    var body: some DynamicInstructions {
      TestDynamicTool(name: "alpha", description: "Alpha tool")
      TestDynamicTool(name: "beta", description: "Beta tool", includeSchema: false)
    }
  }

  /// A dynamic instructions struct containing multiple `Instructions` components.
  private struct MultiSegmentCompositeInstructions: DynamicInstructions {
    /// Whether to include the extra conditional branch.
    let includeExtra: Bool

    /// The body of the dynamic instructions.
    var body: some DynamicInstructions {
      Instructions("Block 1")
      if includeExtra {
        Instructions("Branch True")
      } else {
        Instructions("Branch False")
      }
      if includeExtra {
        Instructions("Optional Present")
      }
      AnyDynamicInstructions(
        Instructions {
          "Builder Line A"
          "Builder Line B"
        }
      )
      Instructions(CustomInstructionsPiece(text: "Custom Representable"))
    }
  }

  /// A dynamic instructions struct with duplicate tool names.
  private struct DuplicateToolCompositeInstructions: DynamicInstructions {
    /// The body of the dynamic instructions.
    var body: some DynamicInstructions {
      Instructions("Duplicate tools")
      TestDynamicTool(name: "dup", description: "First dup description")
      TestDynamicTool(name: "dup", description: "Second dup description")
      TestDynamicTool(name: "unique", description: "Unique description")
    }
  }

  /// A dynamic instructions struct exercising `ForEach` with both key paths and `Identifiable`.
  private struct ForEachCompositeInstructions: DynamicInstructions {
    /// The string keys to iterate over.
    let keys: [String]

    /// The identifiable skills to iterate over.
    let skills: [TestIdentifiableSkill]

    /// The body of the dynamic instructions.
    var body: some DynamicInstructions {
      Instructions("Header")
      DynamicInstructions.ForEach(keys, id: \.self) { key in
        Instructions("Key: \(key)")
        TestDynamicTool(name: "tool_\(key)", description: "Tool for \(key)")
      }
      DynamicInstructionsForEach(skills) { skill in
        Instructions("Skill \(skill.id): \(skill.guidance)")
      }
    }
  }

  /// An inner nested dynamic instructions struct that reads its `BindStateBox` in `body`.
  private struct InnerBindableInstructions: DynamicInstructions, BindableTestNode {
    /// The reference box bound before `body` evaluation.
    let bindBox = BindStateBox()

    /// The reference box passed to the inner tool.
    let toolBindBox = BindStateBox()

    /// The body of the dynamic instructions.
    var body: some DynamicInstructions {
      let current = bindBox.value.withLock { $0 }
      Instructions("Inner state: \(current)")
      TestDynamicTool(name: "inner_tool", description: "Inner tool", bindBox: toolBindBox)
    }
  }

  /// An outer nested dynamic instructions struct that reads its `BindStateBox` in `body`.
  private struct OuterBindableInstructions: DynamicInstructions, BindableTestNode {
    /// The reference box bound before `body` evaluation.
    let bindBox = BindStateBox()

    /// The nested inner instructions component.
    let inner = InnerBindableInstructions()

    /// The body of the dynamic instructions.
    var body: some DynamicInstructions {
      let current = bindBox.value.withLock { $0 }
      Instructions("Outer state: \(current)")
      inner
    }
  }

  /// Extracts text strings from transcript segments.
  private func extractTexts(_ segments: [Transcript.Segment]) -> [String] {
    segments.compactMap { segment in
      guard case .text(let textSegment) = segment else { return nil }
      return textSegment.content
    }
  }

  // MARK: - Tests

  @Suite("DynamicInstructions Tests")
  struct DynamicInstructionsTests {
    @Test
    func emptyBodyProducesEmptySegmentsAndTools() {
      let emptyPrimitive = EmptyDynamicInstructions()
      let emptyComposite = EmptyCompositeInstructions()

      let flattenedPrimitive = DynamicInstructionsFlattener.flatten(emptyPrimitive)
      let flattenedComposite = DynamicInstructionsFlattener.flatten(emptyComposite)

      #expect(flattenedPrimitive.segments.isEmpty)
      #expect(flattenedPrimitive.tools.isEmpty)
      #expect(flattenedPrimitive.isEmpty)
      #expect(flattenedComposite.segments.isEmpty)
      #expect(flattenedComposite.tools.isEmpty)
      #expect(flattenedComposite.isEmpty)
    }

    @Test
    func toolsOnlyBodyPreservesToolsAndFiltersInstructionSchemas() {
      let instructions = ToolsOnlyCompositeInstructions()

      let flattened = DynamicInstructionsFlattener.flatten(instructions)

      #expect(flattened.segments.isEmpty)
      #expect(!flattened.isEmpty)
      #expect(flattened.tools.map(\.name) == ["alpha", "beta"])
      #expect(flattened.enabledToolDefinitions.map(\.name) == ["alpha", "beta"])
      #expect(flattened.instructionToolDefinitions.map(\.name) == ["alpha"])
    }

    @Test
    func multipleInstructionsBlocksPreserveSegmentBoundaries() {
      let falseBranch = MultiSegmentCompositeInstructions(includeExtra: false)
      let trueBranch = MultiSegmentCompositeInstructions(includeExtra: true)

      let flattenedFalse = DynamicInstructionsFlattener.flatten(falseBranch)
      let flattenedTrue = DynamicInstructionsFlattener.flatten(trueBranch)

      #expect(
        extractTexts(flattenedFalse.segments) == [
          "Block 1",
          "Branch False",
          "Builder Line A",
          "Builder Line B",
          "Custom Representable",
        ]
      )
      #expect(
        extractTexts(flattenedTrue.segments) == [
          "Block 1",
          "Branch True",
          "Optional Present",
          "Builder Line A",
          "Builder Line B",
          "Custom Representable",
        ]
      )
    }

    @Test
    func duplicateToolNamesDeduplicateOnFirstWins() throws {
      let instructions = DuplicateToolCompositeInstructions()

      let flattened = DynamicInstructionsFlattener.flatten(instructions)

      #expect(extractTexts(flattened.segments) == ["Duplicate tools"])
      #expect(flattened.tools.count == 2)
      #expect(flattened.tools.map(\.name) == ["dup", "unique"])
      let firstTool = try #require(flattened.tools.first)
      #expect(firstTool.description == "First dup description")
      #expect(
        flattened.instructionToolDefinitions.map(\.description) == [
          "First dup description",
          "Unique description",
        ]
      )
    }

    @Test
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    func conditionalsOptionalsToolArraysAndLoopsFlattenCorrectly() {
      let optionalPresent: Instructions? = Instructions("Optional Some")
      let optionalNil: Instructions? = nil
      let dynamicTools: [any Tool] = [
        TestDynamicTool(name: "array_tool_1", description: "First array tool"),
        TestDynamicTool(name: "array_tool_2", description: "Second array tool"),
        TestDynamicTool(name: "array_tool_1", description: "Duplicate array tool"),
      ]
      let loopItems = ["loop-1", "loop-2"]

      @DynamicInstructionsBuilder
      func buildSample() -> some DynamicInstructions {
        optionalPresent
        optionalNil
        dynamicTools
        for item in loopItems {
          Instructions(item)
        }
        if #available(macOS 15.0, *) {
          Instructions("Available block")
        }
      }

      let flattened = DynamicInstructionsFlattener.flatten(buildSample())

      #expect(
        extractTexts(flattened.segments) == [
          "Optional Some",
          "loop-1",
          "loop-2",
          "Available block",
        ]
      )
      #expect(flattened.tools.map(\.name) == ["array_tool_1", "array_tool_2"])
      #expect(flattened.tools.first?.description == "First array tool")
    }

    @Test
    func forEachFlattensKeyPathAndIdentifiableCollections() {
      let instructions = ForEachCompositeInstructions(
        keys: ["x", "y"],
        skills: [
          TestIdentifiableSkill(id: "s1", guidance: "Use active voice"),
          TestIdentifiableSkill(id: "s2", guidance: "Keep lines under 100 chars"),
        ]
      )
      let emptyInstructions = ForEachCompositeInstructions(keys: [], skills: [])

      let flattened = DynamicInstructionsFlattener.flatten(instructions)
      let flattenedEmpty = DynamicInstructionsFlattener.flatten(emptyInstructions)

      #expect(
        extractTexts(flattened.segments) == [
          "Header",
          "Key: x",
          "Key: y",
          "Skill s1: Use active voice",
          "Skill s2: Keep lines under 100 chars",
        ]
      )
      #expect(flattened.tools.map(\.name) == ["tool_x", "tool_y"])
      #expect(extractTexts(flattenedEmpty.segments) == ["Header"])
      #expect(flattenedEmpty.tools.isEmpty)
    }

    @Test
    func anyDynamicInstructionsErasesAllSupportedInitializers() {
      let fromDynamic = AnyDynamicInstructions(Instructions("From DynamicInstructions"))
      let fromErasing = AnyDynamicInstructions(erasing: Instructions("From erasing"))
      let fromRepresentable = AnyDynamicInstructions(CustomInstructionsPiece(text: "From piece"))
      let nestedAny = AnyDynamicInstructions(fromDynamic)

      let flatDynamic = DynamicInstructionsFlattener.flatten(fromDynamic)
      let flatErasing = DynamicInstructionsFlattener.flatten(fromErasing)
      let flatRepresentable = DynamicInstructionsFlattener.flatten(fromRepresentable)
      let flatNested = DynamicInstructionsFlattener.flatten(nestedAny)

      #expect(extractTexts(flatDynamic.segments) == ["From DynamicInstructions"])
      #expect(extractTexts(flatErasing.segments) == ["From erasing"])
      #expect(extractTexts(flatRepresentable.segments) == ["From piece"])
      #expect(extractTexts(flatNested.segments) == ["From DynamicInstructions"])
    }

    @Test
    func binderIsInvokedBeforeCompositeBodyEvaluationAndOnTools() {
      let root = OuterBindableInstructions()
      let visitedOrder = Mutex<[String]>([])

      let flattened = DynamicInstructionsFlattener.flatten(root) { target in
        if let bindable = target as? any BindableTestNode {
          bindable.bindBox.value.withLock { $0 = "bound-before-body" }
          visitedOrder.withLock { $0.append(String(describing: type(of: target))) }
        } else if let tool = target as? TestDynamicTool {
          tool.bindBox?.value.withLock { $0 = "tool-bound" }
          visitedOrder.withLock { $0.append("tool:\(tool.name)") }
        }
      }

      #expect(
        extractTexts(flattened.segments) == [
          "Outer state: bound-before-body",
          "Inner state: bound-before-body",
        ]
      )
      #expect(flattened.tools.map(\.name) == ["inner_tool"])
      #expect(root.inner.toolBindBox.value.withLock { $0 } == "tool-bound")
      #expect(flattened.bindTargets.count == 3)
      #expect(
        visitedOrder.withLock { $0 } == [
          "OuterBindableInstructions",
          "InnerBindableInstructions",
          "tool:inner_tool",
        ]
      )
    }
  }
#endif  // compiler(>=6.4)
