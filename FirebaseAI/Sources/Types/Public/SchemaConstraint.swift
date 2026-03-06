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

/// A definition of a constraint applied to a property.
public struct SchemaConstraint {
  var minimum: Double?
  var maximum: Double?
  var pattern: String?
  var minLength: Int?
  var maxLength: Int?
  var minItems: Int?
  var maxItems: Int?
  var uniqueItems: Bool?
  var description: String?

  // MARK: - Factory Methods

  /// Constrain an integer to a specific range (e.g. 1...10)
  public static func integer(_ range: ClosedRange<Int>,
                             description: String? = nil) -> SchemaConstraint {
    return SchemaConstraint(
      minimum: Double(range.lowerBound),
      maximum: Double(range.upperBound),
      description: description
    )
  }

  public static func integer(min: Int? = nil, max: Int? = nil,
                             description: String? = nil) -> SchemaConstraint {
    return SchemaConstraint(
      minimum: min.map(Double.init),
      maximum: max.map(Double.init),
      description: description
    )
  }

  /// Constrain a number to a specific range (e.g. 0.0...1.0)
  public static func number(_ range: ClosedRange<Double>,
                            description: String? = nil) -> SchemaConstraint {
    return SchemaConstraint(
      minimum: range.lowerBound,
      maximum: range.upperBound,
      description: description
    )
  }

  public static func number(min: Double? = nil, max: Double? = nil,
                            description: String? = nil) -> SchemaConstraint {
    return SchemaConstraint(
      minimum: min,
      maximum: max,
      description: description
    )
  }

  /// Convenience for a regex pattern string
  public static func pattern(_ regex: String, description: String? = nil) -> SchemaConstraint {
    return SchemaConstraint(pattern: regex, description: description)
  }

  public static func string(pattern: String? = nil, minLength: Int? = nil, maxLength: Int? = nil,
                            description: String? = nil) -> SchemaConstraint {
    return SchemaConstraint(
      pattern: pattern,
      minLength: minLength,
      maxLength: maxLength,
      description: description
    )
  }

  public static func array(minItems: Int? = nil, maxItems: Int? = nil, uniqueItems: Bool? = nil,
                           description: String? = nil) -> SchemaConstraint {
    return SchemaConstraint(
      minItems: minItems,
      maxItems: maxItems,
      uniqueItems: uniqueItems,
      description: description
    )
  }
}
