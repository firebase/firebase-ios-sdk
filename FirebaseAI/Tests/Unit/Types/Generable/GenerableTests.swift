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

// An example of the expected output from the `@FirebaseAILogic.Generable` macro.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct Person: Equatable {
  let firstName: String
  let middleName: String?
  let lastName: String
  let age: Int

  nonisolated static var jsonSchema: FirebaseAILogic.JSONSchema {
    FirebaseAILogic.JSONSchema(
      type: Self.self,
      properties: [
        FirebaseAILogic.JSONSchema.Property(name: "firstName", type: String.self),
        FirebaseAILogic.JSONSchema.Property(name: "middleName", type: String?.self),
        FirebaseAILogic.JSONSchema.Property(name: "lastName", type: String.self),
        FirebaseAILogic.JSONSchema.Property(name: "age", type: Int.self),
      ]
    )
  }

  nonisolated var modelOutput: FirebaseAILogic.ModelOutput {
    var properties = [(name: String, value: any FirebaseAILogic.ConvertibleToModelOutput)]()
    addProperty(name: "firstName", value: firstName)
    addProperty(name: "middleName", value: middleName)
    addProperty(name: "lastName", value: lastName)
    addProperty(name: "age", value: age)
    return ModelOutput(
      properties: properties,
      uniquingKeysWith: { _, second in
        second
      }
    )
    func addProperty(name: String, value: some FirebaseAILogic.Generable) {
      properties.append((name, value))
    }
    func addProperty(name: String, value: (some FirebaseAILogic.Generable)?) {
      if let value {
        properties.append((name, value))
      }
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Person: nonisolated FirebaseAILogic.Generable {
  nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
    firstName = try content.value(forProperty: "firstName")
    middleName = try content.value(forProperty: "middleName")
    lastName = try content.value(forProperty: "lastName")
    age = try content.value(forProperty: "age")
  }
}
