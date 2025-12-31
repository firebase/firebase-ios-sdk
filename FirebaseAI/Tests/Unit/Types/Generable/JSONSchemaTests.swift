// Copyright 2025 Google LLC
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

@testable import FirebaseAILogic
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class JSONSchemaTests: XCTestCase {
  func testAsSchema_string() throws {
    let json = """
    {
      "type": "string",
      "description": "A string"
    }
    """.data(using: .utf8)!

    let decodedSchema = try JSONDecoder().decode(JSONSchema.self, from: json)
    let schema = try decodedSchema.asSchema()

    XCTAssertEqual(schema.type, "STRING")
    XCTAssertEqual(schema.description, "A string")
  }

  func testAsSchema_enum() throws {
    let json = """
    {
      "type": "string",
      "enum": ["north", "south"],
      "description": "Direction"
    }
    """.data(using: .utf8)!

    let decodedSchema = try JSONDecoder().decode(JSONSchema.self, from: json)
    let schema = try decodedSchema.asSchema()

    XCTAssertEqual(schema.type, "STRING")
    XCTAssertEqual(schema.enumValues, ["north", "south"])
  }

  func testAsSchema_object() throws {
    let json = """
    {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer"}
      },
      "required": ["name"]
    }
    """.data(using: .utf8)!

    let decodedSchema = try JSONDecoder().decode(JSONSchema.self, from: json)
    let schema = try decodedSchema.asSchema()

    XCTAssertEqual(schema.type, "OBJECT")
    XCTAssertEqual(schema.properties?.count, 2)
    XCTAssertEqual(schema.properties?["name"]?.type, "STRING")
    XCTAssertEqual(schema.properties?["age"]?.type, "INTEGER")
    XCTAssertEqual(schema.requiredProperties, ["name"])
  }

  func testAsSchema_array() throws {
    let json = """
    {
      "type": "array",
      "items": {"type": "string"},
      "minItems": 1,
      "maxItems": 10
    }
    """.data(using: .utf8)!

    let decodedSchema = try JSONDecoder().decode(JSONSchema.self, from: json)
    let schema = try decodedSchema.asSchema()

    XCTAssertEqual(schema.type, "ARRAY")
    XCTAssertEqual(schema.items?.type, "STRING")
    XCTAssertEqual(schema.minItems, 1)
    XCTAssertEqual(schema.maxItems, 10)
  }

  func testAsSchema_numericConstraints() throws {
    let json = """
    {
      "type": "number",
      "minimum": 0.5,
      "maximum": 99.9
    }
    """.data(using: .utf8)!

    let decodedSchema = try JSONDecoder().decode(JSONSchema.self, from: json)
    let schema = try decodedSchema.asSchema()

    XCTAssertEqual(schema.type, "NUMBER")
    XCTAssertEqual(schema.minimum, 0.5)
    XCTAssertEqual(schema.maximum, 99.9)
  }

  func testAsSchema_anyOf() throws {
    let json = """
    {
      "anyOf": [
        {"type": "string"},
        {"type": "integer"}
      ]
    }
    """.data(using: .utf8)!

    let decodedSchema = try JSONDecoder().decode(JSONSchema.self, from: json)
    let schema = try decodedSchema.asSchema()

    XCTAssertNil(schema.dataType) // anyOf schema doesn't have a top-level type
    XCTAssertEqual(schema.anyOf?.count, 2)
    XCTAssertEqual(schema.anyOf?[0].type, "STRING")
    XCTAssertEqual(schema.anyOf?[1].type, "INTEGER")
  }
}
