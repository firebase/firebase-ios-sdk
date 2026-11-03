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
  import Foundation
  import Synchronization
  import Testing

  @testable import FoundationModelsFake

  /// Types for the key-encoding-strategy tests, namespaced so that their `$defs` names (such as
  /// `ChildModel`) don't clash with other test types.
  enum KeyStrategyModels {
    /// A nested type with a property named `pattern` and a regex pattern guide.
    @Generable(description: "Child")
    struct ChildModel {
      /// A property named like the `pattern` schema keyword.
      var pattern: String

      /// A property with a regex pattern guide.
      @Guide(description: "zip", .pattern(#/^\d{5}$/#))
      var zipCode: String
    }

    /// The root type, with camel-case and keyword-like property names.
    @Generable(description: "Root")
    struct RootModel {
      /// A camel-case property name.
      var firstName: String

      /// A property named like the `properties` schema keyword.
      var properties: Int

      /// A nested object, hoisted into `$defs`.
      var child: ChildModel
    }
  }

  /// Collects the coding paths a custom key encoding or decoding strategy is called with.
  private final class CodingPathRecorder: Sendable {
    /// The recorded coding paths, as arrays of key strings.
    private let storage = Mutex<[[String]]>([])

    /// The recorded coding paths.
    var paths: [[String]] {
      storage.withLock { $0 }
    }

    /// Records a coding path.
    ///
    /// - Parameter path: The coding path passed to the strategy.
    func record(_ path: [any CodingKey]) {
      storage.withLock { $0.append(path.map(\.stringValue)) }
    }
  }

  /// Tests for encoding and decoding schemas with key-encoding and key-decoding strategies.
  @Suite("GenerationSchema key strategies")
  struct SchemaKeyStrategyTests {
    /// Apple's output for `KeyStrategyModels.RootModel.generationSchema` with
    /// `.convertToSnakeCase` and `.sortedKeys`: keywords are converted, but
    /// property names and `$defs` names aren't.
    static let appleSnakeCaseSchema =
      ##"{"$defs":{"ChildModel":{"additional_properties":false,"description":"Child","##
      + ##""properties":{"pattern":{"type":"string"},"zipCode":{"description":"zip","##
      + ##""pattern":"^\\d{5}$","type":"string"}},"required":["pattern","zipCode"],"##
      + ##""title":"ChildModel","type":"object","x-order":["pattern","zipCode"]}},"##
      + ##""additional_properties":false,"description":"Root","properties":{"child":"##
      + ##"{"$ref":"#\/$defs\/ChildModel"},"firstName":{"type":"string"},"properties":"##
      + ##"{"type":"integer"}},"required":["firstName","properties","child"],"##
      + ##""title":"RootModel","type":"object","x-order":["firstName","properties","child"]}"##

    @Test
    func snakeCaseKeyStrategyLeavesPropertyAndDefinitionNamesAlone() throws {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      encoder.keyEncodingStrategy = .convertToSnakeCase

      let data = try encoder.encode(KeyStrategyModels.RootModel.generationSchema)

      #expect(String(decoding: data, as: UTF8.self) == Self.appleSnakeCaseSchema)
    }

    @Test
    func customKeyStrategyIsNotCalledForPropertyOrDefinitionNames() throws {
      let recorder = CodingPathRecorder()
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .custom { path in
        recorder.record(path)
        return path[path.count - 1]
      }

      _ = try encoder.encode(KeyStrategyModels.RootModel.generationSchema)

      let lastKeys = recorder.paths.compactMap(\.last)
      #expect(!lastKeys.contains("firstName"))
      #expect(!lastKeys.contains("child"))
      #expect(!lastKeys.contains("zipCode"))
      #expect(!lastKeys.contains("ChildModel"))
      #expect(lastKeys.filter { $0 == "pattern" }.count == 1)
      #expect(lastKeys.filter { $0 == "properties" }.count == 2)
    }

    @Test
    func promptInitializerWithoutContextOptionsIncludesSchemaWhenFormatIsSet() {
      let format = Transcript.ResponseFormat(schema: KeyStrategyModels.RootModel.generationSchema)

      let withFormat = Transcript.Prompt(segments: [], responseFormat: format)
      let withoutFormat = Transcript.Prompt(segments: [])
      let fullInitializer = Transcript.Prompt(metadata: [:], segments: [], responseFormat: format)

      #expect(withFormat.contextOptions.includeSchemaInPrompt == true)
      #expect(withoutFormat.contextOptions.includeSchemaInPrompt == nil)
      #expect(fullInitializer.contextOptions.includeSchemaInPrompt == nil)
    }

    /// A schema whose property and definition names contain underscores.
    static let snakeCaseNamedSchema =
      ##"{"title":"Snake","type":"object","properties":{"user_name":{"type":"string"},"##
      + ##""pet_info":{"$ref":"#/$defs/Pet_Info"}},"required":["user_name","pet_info"],"##
      + ##""x-order":["user_name","pet_info"],"additionalProperties":false,"$defs":{"Pet_Info":"##
      + ##"{"title":"Pet_Info","type":"object","properties":{"nick_name":{"type":"string"}},"##
      + ##""required":["nick_name"],"x-order":["nick_name"],"additionalProperties":false}}}"##

    /// Apple's `.sortedKeys` re-encoding of `snakeCaseNamedSchema` after decoding it with
    /// `.convertFromSnakeCase`: every name is kept.
    static let appleSnakeCaseNamedSchemaReencoded =
      ##"{"$defs":{"Pet_Info":{"additionalProperties":false,"properties":{"nick_name":"##
      + ##"{"type":"string"}},"required":["nick_name"],"title":"Pet_Info","type":"object","##
      + ##""x-order":["nick_name"]}},"additionalProperties":false,"properties":{"pet_info":"##
      + ##"{"$ref":"#\/$defs\/Pet_Info"},"user_name":{"type":"string"}},"##
      + ##""required":["user_name","pet_info"],"title":"Snake","type":"object","##
      + ##""x-order":["user_name","pet_info"]}"##

    @Test
    func snakeCaseKeyDecodingStrategyLeavesPropertyAndDefinitionNamesAlone() throws {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]

      let schema = try decoder.decode(
        GenerationSchema.self,
        from: Data(Self.snakeCaseNamedSchema.utf8)
      )

      let reencoded = String(decoding: try encoder.encode(schema), as: UTF8.self)
      #expect(reencoded == Self.appleSnakeCaseNamedSchemaReencoded)
    }

    @Test
    func snakeCaseKeyStrategiesRoundTripASchema() throws {
      let schema = KeyStrategyModels.RootModel.generationSchema
      let snakeEncoder = JSONEncoder()
      snakeEncoder.keyEncodingStrategy = .convertToSnakeCase
      let snakeDecoder = JSONDecoder()
      snakeDecoder.keyDecodingStrategy = .convertFromSnakeCase
      let plainEncoder = JSONEncoder()
      plainEncoder.outputFormatting = [.sortedKeys]

      let decoded = try snakeDecoder.decode(
        GenerationSchema.self,
        from: try snakeEncoder.encode(schema)
      )

      #expect(try plainEncoder.encode(decoded) == plainEncoder.encode(schema))
    }

    @Test
    func customKeyDecodingStrategyIsNotCalledForPropertyOrDefinitionNames() throws {
      let recorder = CodingPathRecorder()
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .custom { path in
        recorder.record(path)
        return path[path.count - 1]
      }

      _ = try decoder.decode(GenerationSchema.self, from: Data(Self.snakeCaseNamedSchema.utf8))

      let lastKeys = Set(recorder.paths.compactMap(\.last))
      #expect(lastKeys.isDisjoint(with: ["user_name", "pet_info", "nick_name", "Pet_Info"]))
      #expect(lastKeys.isSuperset(of: ["properties", "$defs", "x-order", "type"]))
    }
  }
#endif  // compiler(>=6.4)
