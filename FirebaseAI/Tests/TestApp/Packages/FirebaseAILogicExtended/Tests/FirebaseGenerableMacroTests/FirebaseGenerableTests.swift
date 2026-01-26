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

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when
// cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(FirebaseAILogicMacros)
  import FirebaseAILogicMacros

  let testMacros: [String: Macro.Type] = [
    "FirebaseGenerable": FirebaseGenerableMacro.self,
  ]
#endif

final class FirebaseAILogicMacrosTests: XCTestCase {
  func testMacro() throws {
    #if canImport(FirebaseAILogicMacros)
      assertMacroExpansion(
        """
        @FirebaseGenerable
        struct Person {
          let firstName: String
          let middleName: String?
          let lastName: String
          let age: Int
        }
        """,
        expandedSource: """
        struct Person {
          let firstName: String
          let middleName: String?
          let lastName: String
          let age: Int

          nonisolated static var jsonSchema: FirebaseAILogic.JSONSchema {
            FirebaseAILogic.JSONSchema(
              type: Self.self,
              properties: [
                FirebaseAILogic.JSONSchema.Property(name: "firstName", type: String.self),
                FirebaseAILogic.JSONSchema.Property(name: "middleName", type: String?.self),
                FirebaseAILogic.JSONSchema.Property(name: "lastName", type: String.self),
                FirebaseAILogic.JSONSchema.Property(name: "age", type: Int.self)
              ]
            )
          }

          nonisolated var modelOutput: FirebaseAILogic.ModelOutput {
            var properties = [(name: String, value: any ConvertibleToModelOutput)]()
            addProperty(name: "firstName", value: self.firstName)
            addProperty(name: "middleName", value: self.middleName)
            addProperty(name: "lastName", value: self.lastName)
            addProperty(name: "age", value: self.age)
            return ModelOutput(
              properties: properties,
              uniquingKeysWith: { _, second in
                second
              }
            )
            func addProperty(name: String, value: some FirebaseGenerable) {
              properties.append((name, value))
            }
            func addProperty(name: String, value: (some FirebaseGenerable)?) {
              if let value {
                properties.append((name, value))
              }
            }
          }

          nonisolated struct Partial: Identifiable, FirebaseAILogic.ConvertibleFromModelOutput {
            var id: FirebaseAILogic.ResponseID
            var firstName: String.Partial?
            var middleName: String?.Partial?
            var lastName: String.Partial?
            var age: Int.Partial?
            nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
              self.id = content.id ?? FirebaseAILogic.ResponseID()
              self.firstName = try content.value(forProperty: "firstName")
              self.middleName = try content.value(forProperty: "middleName")
              self.lastName = try content.value(forProperty: "lastName")
              self.age = try content.value(forProperty: "age")
            }
          }
        }

        @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
        extension Person: FirebaseAILogic.FirebaseGenerable {
          nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
            self.firstName = try content.value(forProperty: "firstName")
            self.middleName = try content.value(forProperty: "middleName")
            self.lastName = try content.value(forProperty: "lastName")
            self.age = try content.value(forProperty: "age")
          }
        }
        """,
        macros: testMacros,
        indentationWidth: .spaces(2)
      )
    #else
      throw XCTSkip("Macros are only supported when running tests for the host platform")
    #endif
  }

  func testEnumMacro() throws {
    #if canImport(FirebaseAILogicMacros)
      assertMacroExpansion(
        """
        @FirebaseGenerable
        enum Pet {
          case cat
          case dog
          case fish
        }
        """,
        expandedSource: """
        enum Pet {
          case cat
          case dog
          case fish

          nonisolated static var jsonSchema: FirebaseAILogic.JSONSchema {
            FirebaseAILogic.JSONSchema(type: Self.self, anyOf: ["cat", "dog", "fish"])
          }

          nonisolated var modelOutput: FirebaseAILogic.ModelOutput {
            switch self {
            case .cat:
              "cat".modelOutput
            case .dog:
              "dog".modelOutput
            case .fish:
              "fish".modelOutput
            }
          }
        }

        @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
        extension Pet: FirebaseAILogic.FirebaseGenerable {
          nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
            let rawValue = try content.value(String.self)
            switch rawValue {
            case "cat":
              self = .cat
            case "dog":
              self = .dog
            case "fish":
              self = .fish
            default:
              throw FirebaseAILogic.GenerativeModel.GenerationError.decodingFailure(
                FirebaseAILogic.GenerativeModel.GenerationError.Context(
                  debugDescription: "Unexpected value \\"\\(rawValue)\\" for \\(Self.self)"
                )
              )
            }
          }
        }
        """,
        macros: testMacros,
        indentationWidth: .spaces(2)
      )
    #else
      throw XCTSkip("Macros are only supported when running tests for the host platform")
    #endif
  }

  func testEnumMacroWithRawValue() throws {
    #if canImport(FirebaseAILogicMacros)
      assertMacroExpansion(
        """
        @FirebaseGenerable
        enum Priority: String {
          case high
          case medium = "med"
          case low
        }
        """,
        expandedSource: """
        enum Priority: String {
          case high
          case medium = "med"
          case low

          nonisolated static var jsonSchema: FirebaseAILogic.JSONSchema {
            FirebaseAILogic.JSONSchema(type: Self.self, anyOf: [high.rawValue, medium.rawValue, low.rawValue])
          }

          nonisolated var modelOutput: FirebaseAILogic.ModelOutput {
            rawValue.modelOutput
          }
        }

        @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
        extension Priority: FirebaseAILogic.FirebaseGenerable {
          nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
            let rawValue = try content.value(String.self)
            if let value = Self(rawValue: rawValue) {
              self = value
            } else {
              throw FirebaseAILogic.GenerativeModel.GenerationError.decodingFailure(
                FirebaseAILogic.GenerativeModel.GenerationError.Context(
                  debugDescription: "Unexpected value \\"\\(rawValue)\\" for \\(Self.self)"
                )
              )
            }
          }
        }
        """,
        macros: testMacros,
        indentationWidth: .spaces(2)
      )
    #else
      throw XCTSkip("Macros are only supported when running tests for the host platform")
    #endif
  }
}
