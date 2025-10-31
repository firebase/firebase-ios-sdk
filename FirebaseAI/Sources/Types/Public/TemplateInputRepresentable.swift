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
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public protocol TemplateInputRepresentable: Encodable, Sendable {
  var templateInputRepresentation: TemplateInput { get }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension String: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput { TemplateInput(value: .string(self)) }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Int: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput {
    TemplateInput(value: .number(Double(self)))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Double: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput { TemplateInput(value: .number(self)) }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Float: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput {
    TemplateInput(value: .number(Double(self)))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Bool: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput { TemplateInput(value: .bool(self)) }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Array: TemplateInputRepresentable where Element: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput {
    TemplateInput(value: .array(map { TemplateInput($0).value }))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Dictionary: TemplateInputRepresentable
  where Key == String, Value: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput {
    TemplateInput(value: .object(mapValues { TemplateInput($0).value }))
  }
}
