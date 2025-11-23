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

import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import FirebaseAILogicMacro

final class FirebaseGenerableMacroTests: XCTestCase {
  private let macros = ["FirebaseGenerable": FirebaseGenerableMacro.self]

  func testExpansion_handlesOptionalAndCustomTypes() {
    let originalSource = """
    @FirebaseGenerable
    struct MyDessert: Decodable {
      let name: String?
      let ingredients: [Ingredient]?
      let isDelicious: Bool
    }
    """

    let expectedSource = """
    struct MyDessert: Decodable {
      let name: String?
      let ingredients: [Ingredient]?
      let isDelicious: Bool
      public static var firebaseGenerationSchema: FirebaseAILogic.Schema {
        .object(properties: [
          "name": (FirebaseAILogic.Schema.string()).asNullable(),
          "ingredients": (FirebaseAILogic.Schema.array(items: Ingredient.firebaseGenerationSchema)).asNullable(),
          "isDelicious": FirebaseAILogic.Schema.boolean()
        ])
      }
    }

    extension MyDessert: FirebaseAILogic.FirebaseGenerable {}
    """

    assertMacroExpansion(originalSource, expandedSource: expectedSource, macros: macros)
  func testExpansion_handlesMultiBindingAndComputedProperties() {
    let originalSource = """
    @FirebaseGenerable
    struct MyType: Decodable {
      let a, b: String
      let c: Int
      var isComputed: Bool { return true }
    }
    """

    let expectedSource = """
    struct MyType: Decodable {
      let a, b: String
      let c: Int
      var isComputed: Bool { return true }
      public static var firebaseGenerationSchema: FirebaseAILogic.Schema {
        .object(properties: [
          "a": FirebaseAILogic.Schema.string(),
          "b": FirebaseAILogic.Schema.string(),
          "c": FirebaseAILogic.Schema.integer()
        ])
      }
    }

    extension MyType: FirebaseAILogic.FirebaseGenerable {}
    """

    assertMacroExpansion(originalSource, expandedSource: expectedSource, macros: macros)
  }
}
