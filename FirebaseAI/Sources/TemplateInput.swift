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

public struct TemplateInput: Sendable {
  let value: JSONValue

  public init(_ input: some TemplateInputRepresentable) {
    self = .init(value: input.templateInputRepresentation.value)
  }

  init(value: JSONValue) {
    self.value = value
  }
}

extension TemplateInput: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput { self }
}
