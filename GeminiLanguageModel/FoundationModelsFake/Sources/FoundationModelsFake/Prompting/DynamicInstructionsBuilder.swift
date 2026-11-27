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

  // MARK: - DynamicInstructionsBuilder

  /// A result builder that constructs dynamic instructions hierarchies.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`DynamicInstructionsBuilder`](https://developer.apple.com/documentation/foundationmodels/dynamicinstructionsbuilder).
  @resultBuilder
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct DynamicInstructionsBuilder {
    /// Builds a dynamic instructions expression wrapping a tool.
    ///
    /// - Parameter expression: The tool to wrap as dynamic instructions.
    /// - Returns: A dynamic instructions value representing the tool.
    public static func buildExpression<T>(_ expression: T) -> some DynamicInstructions
    where T: Tool {
      _ToolDynamicInstructions(tool: expression)
    }

    /// Builds a dynamic instructions expression.
    ///
    /// - Parameter expression: The dynamic instructions expression.
    /// - Returns: The unmodified dynamic instructions.
    public static func buildExpression<T>(_ expression: T) -> T where T: DynamicInstructions {
      expression
    }

    /// Builds dynamic instructions from an array of tools.
    ///
    /// - Parameter tools: An array of tools to include in the dynamic instructions.
    /// - Returns: Dynamic instructions that iterate over each tool.
    public static func buildExpression(_ tools: [any Tool]) -> some DynamicInstructions {
      DynamicInstructionsForEach(tools, id: \.name) { tool in
        AnyDynamicInstructions(Self.buildExpression(tool))
      }
    }

    /// Combines multiple dynamic instructions into a tuple of dynamic instructions.
    ///
    /// - Parameter contents: The dynamic instructions to combine.
    /// - Returns: A tuple of dynamic instructions containing each child.
    @_disfavoredOverload
    public static func buildBlock<each Content>(
      _ contents: repeat each Content
    ) -> TupleDynamicInstructions<repeat each Content>
    where repeat each Content: DynamicInstructions {
      TupleDynamicInstructions(repeat each contents)
    }

    /// Builds a block containing a single dynamic instructions component.
    ///
    /// - Parameter content: The dynamic instructions component.
    /// - Returns: The unmodified dynamic instructions.
    public static func buildBlock<T>(_ content: T) -> T where T: DynamicInstructions {
      content
    }

    /// Builds an empty dynamic instructions block.
    ///
    /// - Returns: An empty dynamic instructions instance.
    public static func buildBlock() -> EmptyDynamicInstructions {
      EmptyDynamicInstructions()
    }

    /// Constructs dynamic instructions from the first conditional branch.
    ///
    /// - Parameter content: The dynamic instructions component from the first branch.
    /// - Returns: Conditional dynamic instructions wrapping the first branch.
    public static func buildEither<TrueContent, FalseContent>(
      first content: TrueContent
    ) -> ConditionalDynamicInstructions<TrueContent, FalseContent>
    where TrueContent: DynamicInstructions, FalseContent: DynamicInstructions {
      ConditionalDynamicInstructions(.trueContent(content))
    }

    /// Constructs dynamic instructions from the second conditional branch.
    ///
    /// - Parameter content: The dynamic instructions component from the second branch.
    /// - Returns: Conditional dynamic instructions wrapping the second branch.
    public static func buildEither<TrueContent, FalseContent>(
      second content: FalseContent
    ) -> ConditionalDynamicInstructions<TrueContent, FalseContent>
    where TrueContent: DynamicInstructions, FalseContent: DynamicInstructions {
      ConditionalDynamicInstructions(.falseContent(content))
    }

    /// Constructs dynamic instructions from an optional dynamic instructions value.
    ///
    /// - Parameter content: The optional dynamic instructions component.
    /// - Returns: The optional dynamic instructions component.
    public static func buildOptional<Content>(_ content: Content?) -> Content?
    where Content: DynamicInstructions {
      content
    }

    /// Combines an array of dynamic instructions components produced by a loop.
    ///
    /// - Parameter components: The array of dynamic instructions components.
    /// - Returns: A dynamic instructions component wrapping the array elements.
    internal static func buildArray<Content>(
      _ components: [Content]
    ) -> some DynamicInstructions where Content: DynamicInstructions {
      _ArrayDynamicInstructions(elements: components)
    }

    /// Constructs dynamic instructions within an availability check.
    ///
    /// - Parameter content: The dynamic instructions component available in the current context.
    /// - Returns: A type-erased dynamic instructions value wrapping the component.
    public static func buildLimitedAvailability(
      _ content: some DynamicInstructions
    ) -> AnyDynamicInstructions {
      AnyDynamicInstructions(content)
    }
  }
#endif  // compiler(>=6.4)
