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

/// A type that can be represented as a ``TemplateInput``.
public protocol TemplateInputRepresentable: Encodable, Sendable {
  var templateInputRepresentation: TemplateInput { get }
}

extension String: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput { TemplateInput(kind: .string(self)) }
}

extension Int: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput { TemplateInput(kind: .int(self)) }
}

extension Double: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput { TemplateInput(kind: .double(self)) }
}

extension Float: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput {
    TemplateInput(kind: .double(Double(self)))
  }
}

extension Bool: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput { TemplateInput(kind: .bool(self)) }
}

extension Array: TemplateInputRepresentable where Element: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput {
    TemplateInput(kind: .array(map { TemplateInput($0).kind }))
  }
}

extension Dictionary: TemplateInputRepresentable
  where Key == String, Value: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput {
    TemplateInput(kind: .dictionary(mapValues { TemplateInput($0).kind }))
  }
}
