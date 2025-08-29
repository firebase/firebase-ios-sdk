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

import FirebaseAILogic
import Foundation
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class SchemaTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    super.setUp()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  }

  // MARK: - String Schema Encoding

  func testEncodeSchema_string_defaultParameters() throws {
    let schema = Schema.string()

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "nullable" : false,
      "type" : "STRING"
    }
    """)
  }

  func testEncodeSchema_string_allOptions() throws {
    let description = "Timestamp of the event."
    let title = "Event Timestamp"
    let format = Schema.StringFormat.custom("date-time")
    let schema = Schema.string(
      description: description,
      title: title,
      nullable: true,
      format: format
    )

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "description" : "\(description)",
      "format" : "date-time",
      "nullable" : true,
      "title" : "\(title)",
      "type" : "STRING"
    }
    """)
  }

  // MARK: - Enumeration Schema Encoding

  func testEncodeSchema_enumeration_defaultParameters() throws {
    let values = ["RED", "GREEN", "BLUE"]
    let schema = Schema.enumeration(values: values)

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "enum" : [
        "RED",
        "GREEN",
        "BLUE"
      ],
      "format" : "enum",
      "nullable" : false,
      "type" : "STRING"
    }
    """)
  }

  func testEncodeSchema_enumeration_allOptions() throws {
    let values = ["NORTH", "SOUTH", "EAST", "WEST"]
    let description = "Compass directions."
    let title = "Directions"
    let schema = Schema.enumeration(
      values: values,
      description: description,
      title: title,
      nullable: true
    )

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "description" : "\(description)",
      "enum" : [
        "NORTH",
        "SOUTH",
        "EAST",
        "WEST"
      ],
      "format" : "enum",
      "nullable" : true,
      "title" : "\(title)",
      "type" : "STRING"
    }
    """)
  }

  // MARK: - Float Schema Encoding

  func testEncodeSchema_float_defaultParameters() throws {
    let schema = Schema.float()

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "format" : "float",
      "nullable" : false,
      "type" : "NUMBER"
    }
    """)
  }

  func testEncodeSchema_float_allOptions() throws {
    let description = "Temperature in Celsius."
    let title = "Temperature (°C)"
    let minimum: Float = -40.25
    let maximum: Float = 50.5
    let schema = Schema.float(
      description: description,
      title: title,
      nullable: true,
      minimum: minimum,
      maximum: maximum
    )

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "description" : "\(description)",
      "format" : "float",
      "maximum" : \(maximum),
      "minimum" : \(minimum),
      "nullable" : true,
      "title" : "\(title)",
      "type" : "NUMBER"
    }
    """)
  }

  // MARK: - Double Schema Encoding

  func testEncodeSchema_double_defaultParameters() throws {
    let schema = Schema.double()

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "nullable" : false,
      "type" : "NUMBER"
    }
    """)
  }

  func testEncodeSchema_double_allOptions() throws {
    let description = "Account balance."
    let title = "Balance"
    let minimum = 0.01
    let maximum = 1_000_000.99
    let schema = Schema.double(
      description: description,
      title: title,
      nullable: true,
      minimum: minimum,
      maximum: maximum
    )

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "description" : "\(description)",
      "maximum" : \(maximum),
      "minimum" : \(minimum),
      "nullable" : true,
      "title" : "\(title)",
      "type" : "NUMBER"
    }
    """)
  }

  // MARK: - Integer Schema Encoding

  func testEncodeSchema_integer_defaultParameters() throws {
    let schema = Schema.integer()

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "nullable" : false,
      "type" : "INTEGER"
    }
    """)
  }

  func testEncodeSchema_integer_allOptions() throws {
    let description = "User age."
    let title = "Age"
    let minimum = 0
    let maximum = 120
    let format = Schema.IntegerFormat.int32
    let schema = Schema.integer(
      description: description,
      title: title,
      nullable: true,
      format: format,
      minimum: minimum,
      maximum: maximum
    )

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "description" : "\(description)",
      "format" : "int32",
      "maximum" : \(maximum),
      "minimum" : \(minimum),
      "nullable" : true,
      "title" : "\(title)",
      "type" : "INTEGER"
    }
    """)
  }

  // MARK: - Boolean Schema Encoding

  func testEncodeSchema_boolean_defaultParameters() throws {
    let schema = Schema.boolean()
    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))

    XCTAssertEqual(json, """
    {
      "nullable" : false,
      "type" : "BOOLEAN"
    }
    """)
  }

  func testEncodeSchema_boolean_allOptions() throws {
    let description = "Is the user an administrator?"
    let title = "Administrator Check"
    let schema = Schema.boolean(description: description, title: title, nullable: true)

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "description" : "\(description)",
      "nullable" : true,
      "title" : "\(title)",
      "type" : "BOOLEAN"
    }
    """)
  }

  // MARK: - Array Schema Encoding

  func testEncodeSchema_array_defaultParameters() throws {
    let itemsSchema = Schema.string()
    let schema = Schema.array(items: itemsSchema)

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "items" : {
        "nullable" : false,
        "type" : "STRING"
      },
      "nullable" : false,
      "type" : "ARRAY"
    }
    """)
  }

  func testEncodeSchema_array_allOptions() throws {
    let itemsSchema = Schema.integer(format: .int64)
    let description = "List of product IDs."
    let title = "Product IDs"
    let minItems = 1
    let maxItems = 10
    let schema = Schema.array(
      items: itemsSchema,
      description: description,
      title: title,
      nullable: true,
      minItems: minItems,
      maxItems: maxItems
    )

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "description" : "\(description)",
      "items" : {
        "format" : "int64",
        "nullable" : false,
        "type" : "INTEGER"
      },
      "maxItems" : \(maxItems),
      "minItems" : \(minItems),
      "nullable" : true,
      "title" : "\(title)",
      "type" : "ARRAY"
    }
    """)
  }

  // MARK: - Object Schema Encoding

  func testEncodeSchema_object_defaultParameters() throws {
    let properties: [String: Schema] = [
      "name": .string(),
      "id": .integer(),
    ]
    let schema = Schema.object(properties: properties)

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "nullable" : false,
      "properties" : {
        "id" : {
          "nullable" : false,
          "type" : "INTEGER"
        },
        "name" : {
          "nullable" : false,
          "type" : "STRING"
        }
      },
      "required" : [
        "id",
        "name"
      ],
      "type" : "OBJECT"
    }
    """)
  }

  func testEncodeSchema_object_allOptions() throws {
    let properties: [String: Schema] = [
      "firstName": .string(description: "Given name"),
      "lastName": .string(description: "Family name"),
      "age": .integer(minimum: 0),
      "lastLogin": .string(format: .custom("date-time")),
    ]
    let optionalProperties = ["age", "lastLogin"]
    let propertyOrdering = ["firstName", "lastName", "age", "lastLogin"]
    let description = "User profile information."
    let title = "User Profile"
    let nullable = true
    let schema = Schema.object(
      properties: properties,
      optionalProperties: optionalProperties,
      propertyOrdering: propertyOrdering,
      description: description,
      title: title,
      nullable: nullable
    )

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "description" : "\(description)",
      "nullable" : true,
      "properties" : {
        "age" : {
          "minimum" : 0,
          "nullable" : false,
          "type" : "INTEGER"
        },
        "firstName" : {
          "description" : "Given name",
          "nullable" : false,
          "type" : "STRING"
        },
        "lastLogin" : {
          "format" : "date-time",
          "nullable" : false,
          "type" : "STRING"
        },
        "lastName" : {
          "description" : "Family name",
          "nullable" : false,
          "type" : "STRING"
        }
      },
      "propertyOrdering" : [
        "firstName",
        "lastName",
        "age",
        "lastLogin"
      ],
      "required" : [
        "firstName",
        "lastName"
      ],
      "title" : "\(title)",
      "type" : "OBJECT"
    }
    """)
  }

  // MARK: - AnyOf Schema Encoding

  func testEncodeSchema_anyOf() throws {
    let schemas: [Schema] = [
      .string(description: "User ID as string"),
      .integer(description: "User ID as integer"),
      .object(
        properties: ["userID": .string(), "detail": .string()],
        optionalProperties: ["detail"]
      ),
    ]
    let schema = Schema.anyOf(schemas: schemas)

    let jsonData = try encoder.encode(schema)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "anyOf" : [
        {
          "description" : "User ID as string",
          "nullable" : false,
          "type" : "STRING"
        },
        {
          "description" : "User ID as integer",
          "nullable" : false,
          "type" : "INTEGER"
        },
        {
          "nullable" : false,
          "properties" : {
            "detail" : {
              "nullable" : false,
              "type" : "STRING"
            },
            "userID" : {
              "nullable" : false,
              "type" : "STRING"
            }
          },
          "required" : [
            "userID"
          ],
          "type" : "OBJECT"
        }
      ]
    }
    """)
  }
}
