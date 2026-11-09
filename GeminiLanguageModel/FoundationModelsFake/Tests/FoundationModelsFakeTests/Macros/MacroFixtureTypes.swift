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
  import FoundationModelsFake

  /// `@Generable` types used by the macro integration tests.
  ///
  /// The types are nested so their names don't collide with other test types; schema titles use
  /// the unqualified type name.
  enum MacroFixtures {
    /// Every primitive `Generable` scalar type.
    @Generable
    struct Primitives: Equatable {
      var string: String
      var int: Int
      var double: Double
      var float: Float
      var bool: Bool
      var decimal: Decimal
    }

    /// A nested `Generable` struct.
    @Generable
    struct Address: Equatable {
      var street: String
      var city: String
    }

    /// Optionals, arrays, nested types and a described type.
    @Generable(description: "A person with optionals, arrays and nested types")
    struct Person: Equatable {
      @Guide(description: "The person's full name")
      var name: String
      var nickname: String?
      var age: Int?
      var tags: [String]
      var scores: [Double]?
      var address: Address
      var previousAddresses: [Address]
      var optionalAddress: Address?
    }

    /// Every `GenerationGuide` kind.
    @Generable
    struct Guides {
      @Guide(.constant("fixed"))
      var constant: String
      @Guide(.anyOf(["a", "b", "c"]))
      var anyOf: String
      @Guide(.pattern(/\d{3}-\d{4}/))
      var patternGuide: String
      @Guide(description: "Regex guide", /^[a-z]+$/)
      var regexGuide: String
      @Guide(.count(3))
      var countExact: [Int]
      @Guide(.count(1...4))
      var countRange: [Int]
      @Guide(.minimumCount(1))
      var minimumCount: [String]
      @Guide(.maximumCount(5))
      var maximumCount: [String]
      @Guide(.minimumCount(1), .maximumCount(3))
      var minimumAndMaximumCount: [String]
      @Guide(.range(0...100))
      var intRange: Int
      @Guide(.minimum(1))
      var intMinimum: Int
      @Guide(.maximum(9))
      var intMaximum: Int
      @Guide(.range(0.0...1.0))
      var doubleRange: Double
      @Guide(.minimum(0.5))
      var floatMinimum: Float
      @Guide(.maximum(2.5))
      var decimalMaximum: Decimal
      @Guide(.element(.range(1...10)))
      var elementGuide: [Int]
      @Guide(.element(.anyOf(["x", "y"])))
      var elementStrings: [String]
      @Guide(description: "Description with guide", .range(1...5))
      var describedAndGuided: Int
      @Guide(.minimum(0), .maximum(10))
      var minimumAndMaximum: Int
      @Guide(description: "An optional constrained value", .range(1...3))
      var optionalGuided: Int?
    }

    /// A type with a custom schema name and description.
    @Generable(name: "CustomName", description: "A type with a custom schema name")
    struct Named {
      var value: Int
    }

    /// Int raw-value enum.
    @Generable
    enum Priority: Int {
      case low = 1
      case high = 10
    }

    /// `representNilExplicitlyInGeneratedContent: true`.
    @Generable(representNilExplicitlyInGeneratedContent: true)
    struct ExplicitNil {
      var present: Int
      var missing: String?
      var missingArray: [Int]?
    }

    /// Recursive type (references itself).
    @Generable
    struct TreeNode {
      var value: Int
      var children: [TreeNode]
    }

    /// Struct with `let` properties and a defaulted `var`.
    @Generable
    struct LetsAndDefaults {
      let identifier: String
      var count: Int = 5
      var computed: Int { count * 2 }
      static var staticValue: Int { 1 }
    }

    /// Simple enum without payloads.
    @Generable
    enum SimpleColor: Equatable {
      case red
      case green
      case blue
    }

    /// String raw-value enum.
    @Generable(description: "A shirt size")
    enum ShirtSize: String, Equatable {
      case small = "S"
      case medium = "M"
      case large
    }

    /// Enum with associated values (mixed with a no-payload case).
    @Generable(description: "An enum with associated values")
    enum Shape: Equatable {
      case empty
      case circle(Double)
      case square(side: Double)
      case rectangle(width: Double, height: Double)
      case labeled(String, count: Int)
      case located(Address)
    }

    /// Struct containing enums.
    @Generable
    struct Wardrobe: Equatable {
      var color: SimpleColor
      var size: ShirtSize
      var shape: Shape
      var colors: [SimpleColor]
    }

    /// Arguments for a test tool.
    @Generable
    struct WeatherArguments: Equatable {
      @Guide(description: "The city to look up")
      var city: String
      @Guide(description: "Units", .anyOf(["celsius", "fahrenheit"]))
      var units: String?
    }
  }

  /// `@Generable` types for edge cases that `MacroFixtures` doesn't cover.
  enum MacroEdgeCases {
    /// A struct whose `id: GenerationID` maps to the generated content's ID.
    @Generable
    struct SearchTerm: Equatable {
      var id: GenerationID
      @Guide(description: "A two- or three- word search term")
      var searchTerm: String
    }

    /// A `Hashable` struct with an `id` property that isn't a `GenerationID`.
    @Generable
    struct Tagged: Hashable {
      var id: String
      var value: Int
    }

    /// An enum with several unlabeled associated values.
    @Generable
    enum Payload: Equatable {
      case pair(Int, Int)
      case single(Int)
    }

    /// An enum with a custom schema name.
    @Generable(name: "Mood")
    enum NamedMood: Equatable {
      case happy
      case sad
    }

    /// A struct with backticked, multiple-binding, observed, and skipped properties.
    @Generable
    struct Forms: Equatable {
      var `default`: Int
      var first, second: Int
      var observed: Int { didSet {} }
      let constant: Int = 3
      static let shared: Int = 1
      var computed: Int { first + second }
    }

    /// A struct with an optional `id: GenerationID?`.
    @Generable
    struct Draft: Equatable {
      var id: GenerationID?
      var text: String
    }

    /// An enum whose associated value labels are keywords.
    @Generable
    enum Keyword: Equatable {
      case range(default: Int, in: String)
      case plain
    }
  }
#endif  // compiler(>=6.4)
