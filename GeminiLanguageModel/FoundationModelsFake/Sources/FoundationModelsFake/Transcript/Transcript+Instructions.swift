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

  extension Transcript {
    /// System instructions and tool definitions provided to a model.
    ///
    /// - SeeAlso: [`Transcript.Instructions`](https://developer.apple.com/documentation/foundationmodels/transcript/instructions)
    public struct Instructions: Sendable, Identifiable, Equatable {
      /// The unique identifier of the instructions entry.
      public var id: String

      /// The segments that compose the instructions.
      public var segments: [Transcript.Segment]

      /// The tool definitions available for the model to invoke.
      public var toolDefinitions: [Transcript.ToolDefinition]

      /// Creates instructions with an identifier, segments, and tool definitions.
      ///
      /// - Parameters:
      ///   - id: The unique identifier for the instructions.
      ///   - segments: The segments composing the instructions.
      ///   - toolDefinitions: The tool definitions available to the model.
      public init(
        id: String = UUID().uuidString,
        segments: [Transcript.Segment],
        toolDefinitions: [Transcript.ToolDefinition]
      ) {
        self.id = id
        self.segments = segments
        self.toolDefinitions = toolDefinitions
      }

      /// The identifier type for instructions.
      public typealias ID = String
    }
  }

  extension Transcript {
    /// A description of a tool available to a language model.
    ///
    /// - SeeAlso: [`Transcript.ToolDefinition`](https://developer.apple.com/documentation/foundationmodels/transcript/tooldefinition)
    public struct ToolDefinition: Sendable, Equatable {
      /// The name of the tool.
      public var name: String

      /// A description of what the tool does.
      public var description: String

      /// The schema defining the parameters accepted by the tool.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public var parameters: GenerationSchema

      /// Creates a tool definition with a name, description, and parameter schema.
      ///
      /// - Parameters:
      ///   - name: The name of the tool.
      ///   - description: A description of what the tool does.
      ///   - parameters: A schema describing the arguments accepted by the tool.
      public init(name: String, description: String, parameters: GenerationSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
      }
    }
  }

  extension Transcript.ToolDefinition {
    /// Creates a tool definition from a tool instance.
    ///
    /// - Parameter tool: The tool to create a definition for.
    public init(tool: some Tool) {
      self.init(name: tool.name, description: tool.description, parameters: tool.parameters)
    }

    /// Returns a Boolean value indicating whether two tool definitions are equal.
    ///
    /// - Parameters:
    ///   - lhs: The first tool definition to compare.
    ///   - rhs: The second tool definition to compare.
    /// - Returns: `true` if both tool definitions are equal.
    public static func == (lhs: Transcript.ToolDefinition, rhs: Transcript.ToolDefinition) -> Bool {
      lhs.name == rhs.name
        && lhs.description == rhs.description
        && lhs.parameters.isTranscriptEquivalent(to: rhs.parameters)
    }
  }

  extension Transcript.Instructions {
    /// Returns a Boolean value indicating whether two instructions entries are equal.
    ///
    /// - Parameters:
    ///   - a: The first instructions entry to compare.
    ///   - b: The second instructions entry to compare.
    /// - Returns: `true` if both instructions entries are equal.
    public static func == (a: Transcript.Instructions, b: Transcript.Instructions) -> Bool {
      a.id == b.id && a.segments == b.segments && a.toolDefinitions == b.toolDefinitions
    }
  }
#endif  // compiler(>=6.4)
