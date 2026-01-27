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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct FirebaseGenerableType: Sendable {
  let type: any FirebaseGenerable.Type
  private let identifier: ObjectIdentifier

  init(_ type: any FirebaseGenerable.Type) {
    self.type = type
    identifier = ObjectIdentifier(type)
  }

  var typeName: String { String(describing: type) }
  var jsonSchema: JSONSchema { type.jsonSchema }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FirebaseGenerableType: Equatable {
  static func == (lhs: FirebaseGenerableType, rhs: FirebaseGenerableType) -> Bool {
    lhs.type == rhs.type && lhs.identifier == rhs.identifier
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FirebaseGenerableType: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }
}
