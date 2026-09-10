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

public import ArgumentParser
import Foundation

#if canImport(FoundationModels) && compiler(>=6.4)
  import FoundationModels

  /// Command for generating structured output schemas.
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct SchemaCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
      commandName: "schema",
      abstract: "Generate a structured output generation schema.",
      subcommands: [ObjectSchemaCommand.self]
    )

    public init() {}
  }

  /// Subcommand for generating a structured output schema for an object type.
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct ObjectSchemaCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
      commandName: "object",
      abstract: "Generate a structured output schema for an object type.",
      discussion: """
        PROPERTY DECLARATIONS
          --anyOf               Build an anyOf union; subsequent --schema args become choices
          --boolean <name>      Declare a boolean property
          --double <name>       Declare a floating-point property
          --integer <name>      Declare an integer property
          --object <name>       Declare a nested object property (follow with --schema)
          --schema <json>       Provide a structured output schema (after --object or --anyOf)
          --string <name>       Declare a string property

        PROPERTY MODIFIERS
          --array               Mark the preceding property as an array of that type
          --description <text>  Set a description on the preceding property
          --optional            Mark the preceding property as optional

        Use dot notation in property names (e.g. 'address.street') to create nested objects.
        """
    )

    @Argument(
      parsing: .allUnrecognized,
      help: "Property declarations, nested types, and modifiers."
    )
    public var rawArguments: [String] = []

    public init() {}

    public init(rawArguments: [String]) {
      self.rawArguments = rawArguments
    }

    public func run() throws {
      let argsToParse: [String]
      if !rawArguments.isEmpty {
        argsToParse = rawArguments
      } else {
        // Find "object" in CommandLine.arguments and take everything after it
        let cliArgs = CommandLine.arguments
        if let objIndex = cliArgs.firstIndex(of: "object") {
          argsToParse = Array(cliArgs.dropFirst(objIndex + 1))
        } else {
          argsToParse = []
        }
      }

      let schema = try SchemaBuilder.build(from: argsToParse)
      let jsonString = try SchemaBuilder.formatJSON(schema)
      print(jsonString)
    }
  }
#endif
