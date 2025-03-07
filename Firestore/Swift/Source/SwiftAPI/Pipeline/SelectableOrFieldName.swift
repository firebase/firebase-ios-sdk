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

public struct SelectableOrFieldName: Equatable {
  enum Kind: Equatable {
    case selectable(Selectable)
    case field(String)

    static func == (lhs: Kind, rhs: Kind) -> Bool {
      switch (lhs, rhs) {
      case let (.selectable(a), .selectable(b)):
        return a.alias == b.alias
      case let (.field(a), .field(b)):
        return a == b
      default:
        return false
      }
    }
  }

  let kind: Kind

  public static func selectable(_ value: Selectable) -> SelectableOrFieldName {
    return SelectableOrFieldName(kind: .selectable(value))
  }

  public static func field(_ name: String) -> SelectableOrFieldName {
    return SelectableOrFieldName(kind: .field(name))
  }
}
