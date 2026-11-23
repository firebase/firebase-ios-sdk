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

/// The sources of the `@Generable` types whose expansions are snapshot-tested.
enum FixtureSource {
  /// The `Address` fixture type.
  static let address = #"""
    @Generable
    public struct Address: Equatable {
      public var street: String
      public var city: String
    }
    """#

  /// The `ExplicitNil` fixture type.
  static let explicitNil = #"""
    @Generable(representNilExplicitlyInGeneratedContent: true)
    public struct ExplicitNil {
      public var present: Int
      public var missing: String?
      public var missingArray: [Int]?
    }
    """#

  /// The `Guides` fixture type.
  static let guides = #"""
    @Generable
    public struct Guides {
      @Guide(.constant("fixed"))
      public var constant: String
      @Guide(.anyOf(["a", "b", "c"]))
      public var anyOf: String
      @Guide(.pattern(/\d{3}-\d{4}/))
      public var patternGuide: String
      @Guide(description: "Regex guide", /^[a-z]+$/)
      public var regexGuide: String
      @Guide(.count(3))
      public var countExact: [Int]
      @Guide(.count(1...4))
      public var countRange: [Int]
      @Guide(.minimumCount(1))
      public var minimumCount: [String]
      @Guide(.maximumCount(5))
      public var maximumCount: [String]
      @Guide(.minimumCount(1), .maximumCount(3))
      public var minimumAndMaximumCount: [String]
      @Guide(.range(0...100))
      public var intRange: Int
      @Guide(.minimum(1))
      public var intMinimum: Int
      @Guide(.maximum(9))
      public var intMaximum: Int
      @Guide(.range(0.0...1.0))
      public var doubleRange: Double
      @Guide(.minimum(0.5))
      public var floatMinimum: Float
      @Guide(.maximum(2.5))
      public var decimalMaximum: Decimal
      @Guide(.element(.range(1...10)))
      public var elementGuide: [Int]
      @Guide(.element(.anyOf(["x", "y"])))
      public var elementStrings: [String]
      @Guide(description: "Description with guide", .range(1...5))
      public var describedAndGuided: Int
      @Guide(.minimum(0), .maximum(10))
      public var minimumAndMaximum: Int
      @Guide(description: "An optional constrained value", .range(1...3))
      public var optionalGuided: Int?
    }
    """#

  /// The `LetsAndDefaults` fixture type.
  static let letsAndDefaults = #"""
    @Generable
    public struct LetsAndDefaults {
      public let identifier: String
      public var count: Int = 5
      public var computed: Int { count * 2 }
      public static var staticValue: Int { 1 }
    }
    """#

  /// The `Named` fixture type.
  static let named = #"""
    @Generable(name: "CustomName", description: "A type with a custom schema name")
    public struct Named {
      public var value: Int
    }
    """#

  /// The `Person` fixture type.
  static let person = #"""
    @Generable(description: "A person with optionals, arrays and nested types")
    public struct Person: Equatable {
      @Guide(description: "The person's full name")
      public var name: String
      public var nickname: String?
      public var age: Int?
      public var tags: [String]
      public var scores: [Double]?
      public var address: Address
      public var previousAddresses: [Address]
      public var optionalAddress: Address?
    }
    """#

  /// The `Primitives` fixture type.
  static let primitives = #"""
    @Generable
    public struct Primitives: Equatable {
      public var string: String
      public var int: Int
      public var double: Double
      public var float: Float
      public var bool: Bool
      public var decimal: Decimal
    }
    """#

  /// The `Priority` fixture type.
  static let priority = #"""
    @Generable
    public enum Priority: Int {
      case low = 1
      case high = 10
    }
    """#

  /// The `Shape` fixture type.
  static let shape = #"""
    @Generable(description: "An enum with associated values")
    public enum Shape: Equatable {
      case empty
      case circle(Double)
      case square(side: Double)
      case rectangle(width: Double, height: Double)
      case labeled(String, count: Int)
      case located(Address)
    }
    """#

  /// The `ShirtSize` fixture type.
  static let shirtSize = #"""
    @Generable(description: "A shirt size")
    public enum ShirtSize: String, Equatable {
      case small = "S"
      case medium = "M"
      case large
    }
    """#

  /// The `SimpleColor` fixture type.
  static let simpleColor = #"""
    @Generable
    public enum SimpleColor: Equatable {
      case red
      case green
      case blue
    }
    """#

  /// The `TreeNode` fixture type.
  static let treeNode = #"""
    @Generable
    public struct TreeNode {
      public var value: Int
      public var children: [TreeNode]
    }
    """#

  /// The `Wardrobe` fixture type.
  static let wardrobe = #"""
    @Generable
    public struct Wardrobe: Equatable {
      public var color: SimpleColor
      public var size: ShirtSize
      public var shape: Shape
      public var colors: [SimpleColor]
    }
    """#

  /// The `WeatherArguments` fixture type.
  static let weatherArguments = #"""
    @Generable
    public struct WeatherArguments: Equatable {
      @Guide(description: "The city to look up")
      public var city: String
      @Guide(description: "Units", .anyOf(["celsius", "fahrenheit"]))
      public var units: String?
    }
    """#

  /// Every fixture source, keyed by the type name used in the fixture file names.
  static let all: [String: String] = [
    "Address": address,
    "ExplicitNil": explicitNil,
    "Guides": guides,
    "LetsAndDefaults": letsAndDefaults,
    "Named": named,
    "Person": person,
    "Primitives": primitives,
    "Priority": priority,
    "Shape": shape,
    "ShirtSize": shirtSize,
    "SimpleColor": simpleColor,
    "TreeNode": treeNode,
    "Wardrobe": wardrobe,
    "WeatherArguments": weatherArguments,
  ]

  /// The fixture type names, sorted.
  static let names = all.keys.sorted()
}
