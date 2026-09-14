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

import Foundation
import Testing

@testable import GFMCore

#if canImport(FoundationModels) && compiler(>=6.4)
  import FoundationModels

  @Suite("SchemaCommand Tests")
  struct SchemaCommandTests {
    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func buildSimpleObjectSchema() throws {
      let args = ["--name", "Person", "--string", "name", "--int", "age"]

      let schema = try SchemaBuilder.build(from: args)
      let json = try SchemaBuilder.formatJSON(schema)

      #expect(schema.name == "Person")
      #expect(json.contains("\"title\" : \"Person\""))
      #expect(json.contains("\"name\" : {\n      \"type\" : \"string\"\n    }"))
      #expect(json.contains("\"age\" : {\n      \"type\" : \"integer\"\n    }"))
      #expect(json.contains("\"additionalProperties\" : false"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func buildSchemaWithModifiers() throws {
      let args = [
        "--name", "Dog",
        "--string", "breed", "--description", "Breed of dog",
        "--boolean", "friendly", "--optional",
        "--string", "tags", "--array",
      ]

      let schema = try SchemaBuilder.build(from: args)
      let json = try SchemaBuilder.formatJSON(schema)

      #expect(schema.name == "Dog")
      #expect(json.contains("\"description\" : \"Breed of dog\""))
      #expect(json.contains("\"type\" : \"array\""))
      #expect(json.contains("\"friendly\" : {\n      \"type\" : \"boolean\"\n    }"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func buildSchemaWithDotNotationNesting() throws {
      let args = [
        "--name", "Restaurant",
        "--string", "name",
        "--string", "address.street",
        "--string", "address.zip",
      ]

      let schema = try SchemaBuilder.build(from: args)
      let json = try SchemaBuilder.formatJSON(schema)

      #expect(schema.name == "Restaurant")
      #expect(json.contains("\"title\" : \"Restaurant\""))
      #expect(json.contains("\"$ref\" : \"#\\/$defs\\/Address\""))
      #expect(json.contains("\"Address\" : {"))
      #expect(json.contains("\"street\" : {\n          \"type\" : \"string\"\n        }"))
      #expect(json.contains("\"zip\" : {\n          \"type\" : \"string\"\n        }"))
    }
  }
#endif
