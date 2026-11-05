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
    public import FoundationEssentials
  #else
    public import Foundation
  #endif

  /// A tool that a language model can call during generation.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Tool`](https://developer.apple.com/documentation/foundationmodels/tool).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public protocol Tool<Arguments, Output>: Sendable {
    /// The output produced when the tool runs.
    associatedtype Output: PromptRepresentable

    /// The arguments required to execute the tool.
    associatedtype Arguments: ConvertibleFromGeneratedContent

    /// The name identifying the tool.
    var name: String { get }

    /// A description of what the tool does.
    var description: String { get }

    /// A schema describing the arguments accepted by the tool.
    var parameters: GenerationSchema { get }

    /// A Boolean value that indicates whether the parameter schema appears in instructions.
    var includesSchemaInInstructions: Bool { get }

    /// Runs the tool with the arguments the model generated and returns its output.
    ///
    /// The session wraps any error this method throws in a ``LanguageModelSession/ToolCallError``.
    /// The session can call this method for several tool calls at once.
    ///
    /// - Parameter arguments: The arguments decoded from the model's tool call.
    /// - Returns: The tool's output, which the session adds to the transcript.
    /// - Throws: Any error that prevents the tool from producing output.
    @concurrent func call(arguments: Self.Arguments) async throws -> Self.Output
  }

  extension Tool {
    /// The name identifying the tool.
    public var name: String {
      String(describing: Self.self)
    }

    /// A Boolean value that indicates whether the parameter schema appears in instructions.
    public var includesSchemaInInstructions: Bool {
      true
    }
  }

  extension Tool where Self.Arguments: Generable {
    /// A schema describing the arguments accepted by the tool.
    public var parameters: GenerationSchema {
      Arguments.generationSchema
    }
  }

  extension Tool where Self.Arguments == String {
    /// Unavailable, because a tool's arguments must be a ``Generable`` structure.
    @available(
      *,
      unavailable,
      message: """
        A 'Tool' can't use 'String' as its 'Arguments' type. \
        Use a '@Generable' struct.
        """
    )
    public var parameters: GenerationSchema {
      fatalError()
    }
  }

  extension Tool where Self.Arguments == Int {
    /// Unavailable, because a tool's arguments must be a ``Generable`` structure.
    @available(
      *,
      unavailable,
      message: """
        A 'Tool' can't use 'Int' as its 'Arguments' type. \
        Use a '@Generable' struct.
        """
    )
    public var parameters: GenerationSchema {
      fatalError()
    }
  }

  extension Tool where Self.Arguments == Double {
    /// Unavailable, because a tool's arguments must be a ``Generable`` structure.
    @available(
      *,
      unavailable,
      message: """
        A 'Tool' can't use 'Double' as its 'Arguments' type. \
        Use a '@Generable' struct.
        """
    )
    public var parameters: GenerationSchema {
      fatalError()
    }
  }

  extension Tool where Self.Arguments == Float {
    /// Unavailable, because a tool's arguments must be a ``Generable`` structure.
    @available(
      *,
      unavailable,
      message: """
        A 'Tool' can't use 'Float' as its 'Arguments' type. \
        Use a '@Generable' struct.
        """
    )
    public var parameters: GenerationSchema {
      fatalError()
    }
  }

  extension Tool where Self.Arguments == Decimal {
    /// Unavailable, because a tool's arguments must be a ``Generable`` structure.
    @available(
      *,
      unavailable,
      message: """
        A 'Tool' can't use 'Decimal' as its 'Arguments' type. \
        Use a '@Generable' struct.
        """
    )
    public var parameters: GenerationSchema {
      fatalError()
    }
  }

  extension Tool where Self.Arguments == Bool {
    /// Unavailable, because a tool's arguments must be a ``Generable`` structure.
    @available(
      *,
      unavailable,
      message: """
        A 'Tool' can't use 'Bool' as its 'Arguments' type. \
        Use a '@Generable' struct.
        """
    )
    public var parameters: GenerationSchema {
      fatalError()
    }
  }
#endif  // compiler(>=6.4)
