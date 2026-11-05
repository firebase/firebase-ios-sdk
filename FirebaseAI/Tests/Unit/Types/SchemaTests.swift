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

import Foundation
import XCTest

@testable import FirebaseAILogic

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

  // MARK: - Equatable Tests

  func testEquatable_identicalSchemas() {
    let schema1 = Schema.object(
      properties: [
        "id": .integer(format: .int64),
        "name": .string(description: "User's full name"),
        "tags": .array(items: .string()),
      ],
      optionalProperties: ["tags"],
      description: "A user object",
      nullable: true
    )
    let schema2 = Schema.object(
      properties: [
        "id": .integer(format: .int64),
        "name": .string(description: "User's full name"),
        "tags": .array(items: .string()),
      ],
      optionalProperties: ["tags"],
      description: "A user object",
      nullable: true
    )

    XCTAssertEqual(schema1, schema2)
  }

  func testEquatable_differentDataTypes() {
    XCTAssertNotEqual(Schema.string(), Schema.integer())
    XCTAssertNotEqual(Schema.float(), Schema.double())
    XCTAssertNotEqual(Schema.boolean(), Schema.array(items: .string()))
  }

  func testEquatable_differentMetadata() {
    XCTAssertNotEqual(
      Schema.string(description: "A"),
      Schema.string(description: "B")
    )

    XCTAssertNotEqual(
      Schema.string(nullable: true),
      Schema.string(nullable: false)
    )

    XCTAssertNotEqual(
      Schema.integer(format: .int32),
      Schema.integer(format: .int64)
    )

    XCTAssertNotEqual(
      Schema.integer(minimum: 1, maximum: 10),
      Schema.integer(minimum: 1, maximum: 20)
    )

    XCTAssertNotEqual(
      Schema.enumeration(values: ["A", "B"]),
      Schema.enumeration(values: ["A", "C"])
    )
  }

  func testEquatable_differentArrayItems() {
    let array1 = Schema.array(items: .string(), minItems: 1)
    let array2 = Schema.array(items: .string(), minItems: 2)
    let array3 = Schema.array(items: .integer(), minItems: 1)

    XCTAssertNotEqual(array1, array2, "Differing bounds should not be equal")
    XCTAssertNotEqual(array1, array3, "Differing item schemas should not be equal")
  }

  func testEquatable_differentObjectProperties() {
    let obj1 = Schema.object(properties: ["a": .string()])
    let obj2 = Schema.object(properties: ["b": .string()])
    let obj3 = Schema.object(properties: ["a": .integer()])
    let obj4 = Schema.object(properties: ["a": .string()], optionalProperties: ["a"])

    XCTAssertNotEqual(obj1, obj2, "Differing property keys should not be equal")
    XCTAssertNotEqual(obj1, obj3, "Differing property value schemas should not be equal")
    XCTAssertNotEqual(obj1, obj4, "Differing required properties should not be equal")
  }

  func testEquatable_differentAnyOf() {
    let anyOf1 = Schema.anyOf(schemas: [.string(), .integer()])
    let anyOf2 = Schema.anyOf(schemas: [.string(), .boolean()])
    let anyOf3 = Schema.anyOf(schemas: [.string()])

    XCTAssertNotEqual(anyOf1, anyOf2, "Differing sub-schemas should not be equal")
    XCTAssertNotEqual(anyOf1, anyOf3, "Differing sub-schema counts should not be equal")
  }

  // MARK: - JSON Schema Conversion Tests

  func testToJSONSchema_string() throws {
    let schema = Schema.string()

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "type" : "string"
    }
    """)
  }

  func testToJSONSchema_integer() throws {
    let schema = Schema.integer()

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "type" : "integer"
    }
    """)
  }

  func testToJSONSchema_float() throws {
    let schema = Schema.float()

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "format" : "float",
      "type" : "number"
    }
    """)
  }

  func testToJSONSchema_double() throws {
    let schema = Schema.double()

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "type" : "number"
    }
    """)
  }

  func testToJSONSchema_boolean() throws {
    let schema = Schema.boolean()

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "type" : "boolean"
    }
    """)
  }

  func testToJSONSchema_nullable() throws {
    let schema = Schema.string(nullable: true)

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "type" : [
        "string",
        "null"
      ]
    }
    """)
  }

  func testToJSONSchema_titleAndDescription() throws {
    let schema = Schema.string(
      description: "A person's full name.",
      title: "FullName"
    )

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "description" : "A person's full name.",
      "title" : "FullName",
      "type" : "string"
    }
    """)
  }

  func testToJSONSchema_enumeration() throws {
    let schema = Schema.enumeration(values: ["phishing", "scam", "promotion"])

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "enum" : [
        "phishing",
        "scam",
        "promotion"
      ],
      "type" : "string"
    }
    """)
  }

  func testToJSONSchema_customFormat() throws {
    let schema = Schema.string(format: .custom("date-time"))

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "format" : "date-time",
      "type" : "string"
    }
    """)
  }

  func testToJSONSchema_numericBounds() throws {
    let schema = Schema.integer(minimum: 1, maximum: 100)

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "maximum" : 100,
      "minimum" : 1,
      "type" : "integer"
    }
    """)
  }

  func testToJSONSchema_array() throws {
    let schema = Schema.array(items: .string(), minItems: 1, maxItems: 10)

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "items" : {
        "type" : "string"
      },
      "maxItems" : 10,
      "minItems" : 1,
      "type" : "array"
    }
    """)
  }

  func testToJSONSchema_object() throws {
    let schema = Schema.object(
      properties: [
        "name": .string(),
        "age": .integer(),
      ],
      optionalProperties: ["age"],
      propertyOrdering: ["name", "age"]
    )

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "additionalProperties" : false,
      "properties" : {
        "age" : {
          "type" : "integer"
        },
        "name" : {
          "type" : "string"
        }
      },
      "propertyOrdering" : [
        "name",
        "age"
      ],
      "required" : [
        "name"
      ],
      "type" : "object"
    }
    """)
  }

  func testToJSONSchema_object_emptyRequired() throws {
    let schema = Schema.object(
      properties: ["name": .string()],
      optionalProperties: ["name"]
    )

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "additionalProperties" : false,
      "properties" : {
        "name" : {
          "type" : "string"
        }
      },
      "required" : [

      ],
      "type" : "object"
    }
    """)
  }

  func testToJSONSchema_anyOf() throws {
    let schema = Schema.anyOf(schemas: [.string(), .integer()])

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "anyOf" : [
        {
          "type" : "string"
        },
        {
          "type" : "integer"
        }
      ]
    }
    """)
  }

  func testToJSONSchema_nestedObjectAndArray() throws {
    let schema = Schema.object(
      properties: [
        "recipe_name": .string(description: "The name of the recipe."),
        "prep_time_minutes": .integer(
          description: "Optional prep time.",
          nullable: true
        ),
        "ingredients": .array(items: .object(properties: [
          "name": .string(description: "Name of the ingredient."),
          "quantity": .string(description: "Quantity with units."),
        ])),
      ],
      optionalProperties: ["prep_time_minutes"],
      propertyOrdering: ["recipe_name", "prep_time_minutes", "ingredients"]
    )

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "additionalProperties" : false,
      "properties" : {
        "ingredients" : {
          "items" : {
            "additionalProperties" : false,
            "properties" : {
              "name" : {
                "description" : "Name of the ingredient.",
                "type" : "string"
              },
              "quantity" : {
                "description" : "Quantity with units.",
                "type" : "string"
              }
            },
            "required" : [
              "name",
              "quantity"
            ],
            "type" : "object"
          },
          "type" : "array"
        },
        "prep_time_minutes" : {
          "description" : "Optional prep time.",
          "type" : [
            "integer",
            "null"
          ]
        },
        "recipe_name" : {
          "description" : "The name of the recipe.",
          "type" : "string"
        }
      },
      "propertyOrdering" : [
        "recipe_name",
        "prep_time_minutes",
        "ingredients"
      ],
      "required" : [
        "ingredients",
        "recipe_name"
      ],
      "type" : "object"
    }
    """)
  }

  func testToJSONSchema_nullableEnumeration() throws {
    let schema = Schema.enumeration(values: ["phishing", "scam"], nullable: true)

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "enum" : [
        "phishing",
        "scam",
        null
      ],
      "type" : [
        "string",
        "null"
      ]
    }
    """)
  }

  /// A custom `"enum"` format must not be mistaken for the marker set by `Schema.enumeration`.
  func testToJSONSchema_customFormatNamedEnum() throws {
    let schema = Schema.string(format: .custom("enum"))

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "format" : "enum",
      "type" : "string"
    }
    """)
  }

  func testToJSONSchema_nullableObject() throws {
    let schema = Schema.object(properties: ["name": .string()], nullable: true)

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "additionalProperties" : false,
      "properties" : {
        "name" : {
          "type" : "string"
        }
      },
      "required" : [
        "name"
      ],
      "type" : [
        "object",
        "null"
      ]
    }
    """)
  }

  func testToJSONSchema_nullableArray() throws {
    let schema = Schema.array(items: .string(), nullable: true)

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "items" : {
        "type" : "string"
      },
      "type" : [
        "array",
        "null"
      ]
    }
    """)
  }

  func testToJSONSchema_anyOfWithObjects() throws {
    let schema = Schema.anyOf(schemas: [
      .object(properties: ["id": .integer()]),
      .object(properties: ["name": .string()], optionalProperties: ["name"]),
    ])

    let jsonSchema = schema.toJSONSchema()

    let jsonData = try encoder.encode(jsonSchema)
    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "anyOf" : [
        {
          "additionalProperties" : false,
          "properties" : {
            "id" : {
              "type" : "integer"
            }
          },
          "required" : [
            "id"
          ],
          "type" : "object"
        },
        {
          "additionalProperties" : false,
          "properties" : {
            "name" : {
              "type" : "string"
            }
          },
          "required" : [

          ],
          "type" : "object"
        }
      ]
    }
    """)
  }
}
