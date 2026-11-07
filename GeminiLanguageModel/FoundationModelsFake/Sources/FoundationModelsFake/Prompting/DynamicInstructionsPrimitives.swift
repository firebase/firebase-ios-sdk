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
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  // MARK: - TupleDynamicInstructions

  /// A dynamic instructions container that groups multiple child instructions together.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`TupleDynamicInstructions`](https://developer.apple.com/documentation/foundationmodels/tupledynamicinstructions).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct TupleDynamicInstructions<each Content>: DynamicInstructions
  where repeat each Content: DynamicInstructions {
    /// The type of dynamic instructions representing the body of this instance.
    public typealias Body = Never

    /// The tuple of child dynamic instructions values.
    internal var value: (repeat each Content)

    /// Creates dynamic instructions from child instructions.
    ///
    /// - Parameter contents: The child dynamic instructions to group.
    public init(_ contents: repeat each Content) {
      self.value = (repeat each contents)
    }

    /// The content and behavior of the dynamic instructions.
    public var body: Never {
      fatalError("TupleDynamicInstructions.body should not be called.")
    }
  }

  // MARK: - ConditionalDynamicInstructions

  /// A dynamic instructions container that conditionally represents one of two branches.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`ConditionalDynamicInstructions`](https://developer.apple.com/documentation/foundationmodels/conditionaldynamicinstructions).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct ConditionalDynamicInstructions<TrueContent, FalseContent>: DynamicInstructions
  where TrueContent: DynamicInstructions, FalseContent: DynamicInstructions {
    /// The type of dynamic instructions representing the body of this instance.
    public typealias Body = Never

    /// A branch of conditional dynamic instructions.
    public enum Branch {
      /// The branch chosen when the condition evaluates to true.
      case trueContent(TrueContent)

      /// The branch chosen when the condition evaluates to false.
      case falseContent(FalseContent)
    }

    /// The active conditional branch stored by this instance.
    internal let branch: Branch

    /// Creates conditional dynamic instructions with a specific branch.
    ///
    /// - Parameter branch: The active branch of instructions.
    public init(_ branch: Branch) {
      self.branch = branch
    }

    /// The content and behavior of the dynamic instructions.
    public var body: Never {
      fatalError("ConditionalDynamicInstructions.body should not be called.")
    }
  }

  // MARK: - DynamicInstructionsForEach

  /// A dynamic instructions container that produces instructions from an identified collection.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`DynamicInstructionsForEach`](https://developer.apple.com/documentation/foundationmodels/dynamicinstructionsforeach).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct DynamicInstructionsForEach<Data, ID, Content>: DynamicInstructions
  where Data: RandomAccessCollection, ID: Hashable, Content: DynamicInstructions {
    /// The type of dynamic instructions representing the body of this instance.
    public typealias Body = Never

    /// The collection of underlying identified data that creates the dynamic instructions.
    internal let data: Data

    /// The key path to the data element's identifier.
    internal let id: KeyPath<Data.Element, ID>

    /// A function that creates dynamic instructions content for a given data element.
    internal let content: (Data.Element) -> Content

    /// Creates dynamic instructions by mapping a collection using a custom identifier key path.
    ///
    /// - Parameters:
    ///   - data: The collection of data to iterate over.
    ///   - id: The key path to each element's unique identifier.
    ///   - content: A builder closure producing dynamic instructions for each element.
    public init(
      _ data: Data,
      id: KeyPath<Data.Element, ID>,
      @DynamicInstructionsBuilder content: @escaping (Data.Element) -> Content
    ) {
      self.data = data
      self.id = id
      self.content = content
    }

    /// The content and behavior of the dynamic instructions.
    public var body: Never {
      fatalError("DynamicInstructionsForEach.body should not be called.")
    }
  }

  extension DynamicInstructionsForEach
  where ID == Data.Element.ID, Data.Element: Identifiable {
    /// Creates dynamic instructions by mapping a collection of identifiable elements.
    ///
    /// - Parameters:
    ///   - data: The collection of identifiable data to iterate over.
    ///   - content: A builder closure producing dynamic instructions for each element.
    public init(
      _ data: Data,
      @DynamicInstructionsBuilder content: @escaping (Data.Element) -> Content
    ) {
      self.init(data, id: \.id, content: content)
    }
  }

  // MARK: - Internal Builder Primitives

  /// An internal dynamic instructions primitive wrapping a single `Tool`.
  internal struct _ToolDynamicInstructions<T: Tool>: DynamicInstructions {
    /// The type of dynamic instructions representing the body of this instance.
    internal typealias Body = Never

    /// The wrapped tool instance.
    internal let tool: T

    /// The content and behavior of the dynamic instructions.
    internal var body: Never {
      fatalError("_ToolDynamicInstructions.body should not be called.")
    }
  }

  /// An internal dynamic instructions primitive wrapping an array of components from `buildArray`.
  internal struct _ArrayDynamicInstructions<Content: DynamicInstructions>: DynamicInstructions {
    /// The type of dynamic instructions representing the body of this instance.
    internal typealias Body = Never

    /// The elements produced by the loop.
    internal let elements: [Content]

    /// The content and behavior of the dynamic instructions.
    internal var body: Never {
      fatalError("_ArrayDynamicInstructions.body should not be called.")
    }
  }

  // MARK: - FlattenedDynamicInstructions

  /// The flattened result of evaluating a ``DynamicInstructions`` hierarchy.
  internal struct FlattenedDynamicInstructions {
    /// Collected instruction segments in traversal order.
    internal var segments: [Transcript.Segment] = []

    /// Collected tools, deduplicated by name (the first tool with a name wins).
    internal var tools: [any Tool] = []

    /// Materialized instruction structs and tools visited during flattening (for SessionProperty
    /// binding).
    internal var bindTargets: [Any] = []

    /// Creates an empty flattened dynamic instructions result.
    internal init(
      segments: [Transcript.Segment] = [],
      tools: [any Tool] = [],
      bindTargets: [Any] = []
    ) {
      self.segments = segments
      self.tools = tools
      self.bindTargets = bindTargets
    }

    /// Whether the flattened result contains neither instruction segments nor tools.
    internal var isEmpty: Bool {
      segments.isEmpty && tools.isEmpty
    }

    /// Tool definitions to include in the transcript's `.instructions` entry (`includesSchemaInInstructions == true`).
    internal var instructionToolDefinitions: [Transcript.ToolDefinition] {
      tools.compactMap { tool in
        guard tool.includesSchemaInInstructions else { return nil }
        return Transcript.ToolDefinition(
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters
        )
      }
    }

    /// All enabled tool definitions for the model generation request.
    internal var enabledToolDefinitions: [Transcript.ToolDefinition] {
      tools.map { tool in
        Transcript.ToolDefinition(
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters
        )
      }
    }
  }

  // MARK: - DynamicInstructionsFlattener

  /// An internal protocol implemented by primitive `DynamicInstructions` nodes whose `Body` is
  /// `Never`.
  internal protocol _DynamicInstructionsPrimitive {
    /// Flattens this primitive node into the given output and deduplication state.
    ///
    /// - Parameters:
    ///   - output: The accumulated flattened instructions and tools.
    ///   - seenToolNames: The set of tool names already registered in `output.tools`.
    ///   - binder: An optional callback invoked on each composite instruction struct and tool.
    func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    )
  }

  /// Evaluates and flattens a ``DynamicInstructions`` tree into transcript segments and tools.
  internal enum DynamicInstructionsFlattener {
    /// Evaluates and flattens a ``DynamicInstructions`` hierarchy in tree traversal order.
    ///
    /// Before evaluating a composite `DynamicInstructions` node's `body`, `binder` is invoked on the
    /// node so that any `@SessionProperty` wrappers on that struct are bound to the session prior to
    /// `body` evaluation. When a `Tool` leaf is visited, `binder` is invoked on the tool and the tool
    /// is appended to `tools` on a first-wins basis by `tool.name`.
    ///
    /// - Parameters:
    ///   - root: The root dynamic instructions node to flatten.
    ///   - binder: An optional closure invoked on each composite dynamic instructions struct (before
    ///     its `body` is read) and on each encountered tool.
    /// - Returns: A ``FlattenedDynamicInstructions`` containing segments, deduplicated tools, and
    ///   visited bind targets.
    internal static func flatten<I: DynamicInstructions>(
      _ root: I,
      bindingEachWith binder: ((Any) -> Void)? = nil
    ) -> FlattenedDynamicInstructions {
      var output = FlattenedDynamicInstructions()
      var seenToolNames: Set<String> = []
      flattenNode(
        root,
        into: &output,
        seenToolNames: &seenToolNames,
        binder: binder
      )
      return output
    }

    /// Recursively flattens a single dynamic instructions node.
    ///
    /// - Parameters:
    ///   - node: The node to flatten.
    ///   - output: The accumulated flattened instructions and tools.
    ///   - seenToolNames: The set of tool names already registered in `output.tools`.
    ///   - binder: An optional callback invoked on each composite instruction struct and tool.
    internal static func flattenNode<I: DynamicInstructions>(
      _ node: I,
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {
      if let primitive = node as? any _DynamicInstructionsPrimitive {
        primitive._flatten(
          into: &output,
          seenToolNames: &seenToolNames,
          binder: binder
        )
        return
      }

      binder?(node)
      output.bindTargets.append(node)
      guard I.Body.self != Never.self else { return }
      let body = node.body
      flattenNode(
        body,
        into: &output,
        seenToolNames: &seenToolNames,
        binder: binder
      )
    }
  }

  // MARK: - Primitive Conformances

  extension Never: _DynamicInstructionsPrimitive {
    /// Flattens this primitive node.
    internal func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {}
  }

  extension EmptyDynamicInstructions: _DynamicInstructionsPrimitive {
    /// Flattens this primitive node.
    internal func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {}
  }

  extension Instructions: _DynamicInstructionsPrimitive {
    /// Flattens this instructions node by appending its segments in order.
    internal func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {
      output.segments.append(contentsOf: segments)
    }
  }

  extension AnyDynamicInstructions: _DynamicInstructionsPrimitive {
    /// Flattens the underlying type-erased dynamic instructions node.
    internal func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {
      func openAndFlatten<T: DynamicInstructions>(_ wrapped: T) {
        DynamicInstructionsFlattener.flattenNode(
          wrapped,
          into: &output,
          seenToolNames: &seenToolNames,
          binder: binder
        )
      }
      openAndFlatten(storage)
    }
  }

  extension TupleDynamicInstructions: _DynamicInstructionsPrimitive {
    /// Flattens each element of the tuple in order.
    internal func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {
      func flattenElement<T: DynamicInstructions>(_ element: T) {
        DynamicInstructionsFlattener.flattenNode(
          element,
          into: &output,
          seenToolNames: &seenToolNames,
          binder: binder
        )
      }
      repeat flattenElement(each value)
    }
  }

  extension ConditionalDynamicInstructions: _DynamicInstructionsPrimitive {
    /// Flattens the active conditional branch.
    internal func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {
      switch branch {
      case .trueContent(let content):
        DynamicInstructionsFlattener.flattenNode(
          content,
          into: &output,
          seenToolNames: &seenToolNames,
          binder: binder
        )
      case .falseContent(let content):
        DynamicInstructionsFlattener.flattenNode(
          content,
          into: &output,
          seenToolNames: &seenToolNames,
          binder: binder
        )
      }
    }
  }

  extension Optional: _DynamicInstructionsPrimitive where Wrapped: DynamicInstructions {
    /// Flattens the wrapped dynamic instructions value when non-nil.
    internal func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {
      guard let wrapped = self else { return }
      DynamicInstructionsFlattener.flattenNode(
        wrapped,
        into: &output,
        seenToolNames: &seenToolNames,
        binder: binder
      )
    }
  }

  extension DynamicInstructionsForEach: _DynamicInstructionsPrimitive {
    /// Flattens the dynamic instructions produced for each element in `data`.
    internal func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {
      for element in data {
        let child = content(element)
        DynamicInstructionsFlattener.flattenNode(
          child,
          into: &output,
          seenToolNames: &seenToolNames,
          binder: binder
        )
      }
    }
  }

  extension _ToolDynamicInstructions: _DynamicInstructionsPrimitive {
    /// Binds and appends the wrapped tool if its name has not already been seen.
    internal func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {
      binder?(tool)
      output.bindTargets.append(tool)
      if seenToolNames.insert(tool.name).inserted {
        output.tools.append(tool)
      }
    }
  }

  extension _ArrayDynamicInstructions: _DynamicInstructionsPrimitive {
    /// Flattens each element produced by `buildArray`.
    internal func _flatten(
      into output: inout FlattenedDynamicInstructions,
      seenToolNames: inout Set<String>,
      binder: ((Any) -> Void)?
    ) {
      for element in elements {
        DynamicInstructionsFlattener.flattenNode(
          element,
          into: &output,
          seenToolNames: &seenToolNames,
          binder: binder
        )
      }
    }
  }
#endif  // compiler(>=6.4)
