// Copyright 2024 Google LLC
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
import Foundation
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class GenerationConfigTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    encoder.outputFormatting = .init(
      arrayLiteral: .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
    )
  }

  // MARK: GenerationConfig Encoding

  func testEncodeGenerationConfig_default() throws {
    let generationConfig = GenerationConfig()

    let jsonData = try encoder.encode(generationConfig)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {

    }
    """)
  }

  func testEncodeGenerationConfig_allOptions() throws {
    let temperature: Float = 0.5
    let topP: Float = 0.75
    let topK = 40
    let candidateCount = 2
    let maxOutputTokens = 256
    let presencePenalty: Float = 0.5
    let frequencyPenalty: Float = 0.75
    let stopSequences = ["END", "DONE"]
    let responseMIMEType = "application/json"
    let generationConfig = GenerationConfig(
      temperature: temperature,
      topP: topP,
      topK: topK,
      candidateCount: candidateCount,
      maxOutputTokens: maxOutputTokens,
      presencePenalty: presencePenalty,
      frequencyPenalty: frequencyPenalty,
      stopSequences: stopSequences,
      responseMIMEType: responseMIMEType,
      responseSchema: .array(items: .string()),
      responseModalities: [.text, .image]
    )

    let jsonData = try encoder.encode(generationConfig)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "candidateCount" : \(candidateCount),
      "frequencyPenalty" : \(frequencyPenalty),
      "maxOutputTokens" : \(maxOutputTokens),
      "presencePenalty" : \(presencePenalty),
      "responseMimeType" : "\(responseMIMEType)",
      "responseModalities" : [
        "TEXT",
        "IMAGE"
      ],
      "responseSchema" : {
        "items" : {
          "nullable" : false,
          "type" : "STRING"
        },
        "nullable" : false,
        "type" : "ARRAY"
      },
      "stopSequences" : [
        "END",
        "DONE"
      ],
      "temperature" : \(temperature),
      "topK" : \(topK),
      "topP" : \(topP)
    }
    """)
  }

  func testEncodeGenerationConfig_jsonResponse() throws {
    let mimeType = "application/json"
    let generationConfig = GenerationConfig(
      responseMIMEType: mimeType,
      responseSchema: .object(properties: [
        "firstName": .string(),
        "middleNames": .array(items: .string(), minItems: 0, maxItems: 3),
        "lastName": .string(),
        "age": .integer(),
      ])
    )

    let jsonData = try encoder.encode(generationConfig)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "responseMimeType" : "\(mimeType)",
      "responseSchema" : {
        "nullable" : false,
        "properties" : {
          "age" : {
            "nullable" : false,
            "type" : "INTEGER"
          },
          "firstName" : {
            "nullable" : false,
            "type" : "STRING"
          },
          "lastName" : {
            "nullable" : false,
            "type" : "STRING"
          },
          "middleNames" : {
            "items" : {
              "nullable" : false,
              "type" : "STRING"
            },
            "maxItems" : 3,
            "minItems" : 0,
            "nullable" : false,
            "type" : "ARRAY"
          }
        },
        "required" : [
          "age",
          "firstName",
          "lastName",
          "middleNames"
        ],
        "type" : "OBJECT"
      }
    }
    """)
  }

  struct Person: FirebaseGenerable {
    static var firebaseGenerationSchema: FirebaseGenerationSchema {
      FirebaseGenerationSchema(type: Self.self, properties: [
        FirebaseGenerationSchema.Property(name: "firstName", type: String.self),
        FirebaseGenerationSchema.Property(
          name: "middleNames",
          type: [String].self,
          guides: [.count(0 ... 3)]
        ),
        FirebaseGenerationSchema.Property(name: "lastName", type: String.self),
        FirebaseGenerationSchema.Property(name: "age", type: Int.self),
      ])
    }

    init(_ content: FirebaseAILogic.FirebaseGeneratedContent) throws {
      fatalError("\(#function) not needed for \(Self.self) in test file: \(#file)")
    }

    var firebaseGeneratedContent: FirebaseAILogic.FirebaseGeneratedContent {
      fatalError("\(#function) not needed for \(Self.self) in test file: \(#file)")
    }
  }

  func testEncodeGenerationConfig_responseFirebaseGenerationSchema() throws {
    let mimeType = "application/json"
    let generationConfig = GenerationConfig(
      responseMIMEType: mimeType,
      responseFirebaseGenerationSchema: Person.firebaseGenerationSchema
    )

    let jsonData = try encoder.encode(generationConfig)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "responseJsonSchema" : {
        "additionalProperties" : false,
        "properties" : {
          "age" : {
            "type" : "integer"
          },
          "firstName" : {
            "type" : "string"
          },
          "lastName" : {
            "type" : "string"
          },
          "middleNames" : {
            "items" : {
              "type" : "string"
            },
            "maxItems" : 3,
            "minItems" : 0,
            "type" : "array"
          }
        },
        "propertyOrdering" : [
          "firstName",
          "middleNames",
          "lastName",
          "age"
        ],
        "required" : [
          "firstName",
          "middleNames",
          "lastName",
          "age"
        ],
        "title" : "Person",
        "type" : "object"
      },
      "responseMimeType" : "\(mimeType)"
    }
    """)
  }

  func testEncodeGenerationConfig_thinkingConfig() throws {
    let testCases: [(ThinkingConfig, String)] = [
      (ThinkingConfig(thinkingBudget: 0), "\"thinkingBudget\" : 0"),
      (ThinkingConfig(thinkingBudget: 1024), "\"thinkingBudget\" : 1024"),
      (ThinkingConfig(thinkingBudget: 1024, includeThoughts: true), """
      "includeThoughts" : true,
          "thinkingBudget" : 1024
      """),
      (ThinkingConfig(thinkingLevel: .minimal), "\"thinkingLevel\" : \"MINIMAL\""),
      (ThinkingConfig(thinkingLevel: .low), "\"thinkingLevel\" : \"LOW\""),
      (ThinkingConfig(thinkingLevel: .medium), "\"thinkingLevel\" : \"MEDIUM\""),
      (ThinkingConfig(thinkingLevel: .high), "\"thinkingLevel\" : \"HIGH\""),
      (ThinkingConfig(thinkingLevel: .medium, includeThoughts: true), """
      "includeThoughts" : true,
          "thinkingLevel" : \"MEDIUM\"
      """),
      (ThinkingConfig(thinkingLevel: .medium, includeThoughts: false), """
      "includeThoughts" : false,
          "thinkingLevel" : \"MEDIUM\"
      """),
    ]

    for (thinkingConfig, expectedJSONSnippet) in testCases {
      let generationConfig = GenerationConfig(thinkingConfig: thinkingConfig)
      let jsonData = try encoder.encode(generationConfig)
      let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
      XCTAssertEqual(json, """
      {
        "thinkingConfig" : {
          \(expectedJSONSnippet)
        }
      }
      """)
    }
  }
}
