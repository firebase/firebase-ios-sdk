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

public extension GenerateContentAPI {
  /// An internal data model for `DataType`.
  ///
  /// ### Gemini Developer API
  ///
  /// Type: `GoogleAiGenerativelanguageV1betaType`
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  enum DataType: Codable, Sendable, Equatable, Hashable {
    /// String type.
    case string

    /// Number type.
    case number

    /// Integer type.
    case integer

    /// Boolean type.
    case boolean

    /// Array type.
    case array

    /// Object type.
    case object

    /// Null type.
    case null

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GenerateContentAPI.DataType: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .string: "STRING"
    case .number: "NUMBER"
    case .integer: "INTEGER"
    case .boolean: "BOOLEAN"
    case .array: "ARRAY"
    case .object: "OBJECT"
    case .null: "NULL"
    case let .unrecognized(value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "STRING": self = .string
    case "NUMBER": self = .number
    case "INTEGER": self = .integer
    case "BOOLEAN": self = .boolean
    case "ARRAY": self = .array
    case "OBJECT": self = .object
    case "NULL": self = .null
    default: self = .unrecognized(rawValue)
    }
  }
}
