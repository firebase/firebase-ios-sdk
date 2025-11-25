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

import FirebaseAILogic
import Testing

struct GenerableTests {
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  @Test func initializeGenerableTypeFromModelOutput() throws {
    let properties: [(String, any ConvertibleToModelOutput)] =
      [("firstName", "John"), ("lastName", "Doe"), ("age", 40)]
    let modelOutput = ModelOutput(
      properties: properties, uniquingKeysWith: { _, second in second }
    )

    let person = try Person(modelOutput)

    #expect(person.firstName == "John")
    #expect(person.lastName == "Doe")
    #expect(person.age == 40)
  }

  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  @Test func convertGenerableTypeToModelOutput() throws {
    let person = Person(firstName: "Jane", middleName: "Marie", lastName: "Smith", age: 32)

    let modelOutput = person.modelOutput

    guard case let .structure(properties, orderedKeys) = modelOutput.kind else {
      Issue.record("Model output is not a structure.")
      return
    }
    let firstNameProperty = try #require(properties["firstName"])
    guard case let .string(firstName) = firstNameProperty.kind else {
      Issue.record("The 'firstName' property is not a string: \(firstNameProperty.kind)")
      return
    }
    #expect(firstName == person.firstName)
    #expect(try modelOutput.value(forProperty: "firstName") == person.firstName)
    let middleNameProperty = try #require(properties["middleName"])
    guard case let .string(middleName) = middleNameProperty.kind else {
      Issue.record("The 'middleName' property is not a string: \(middleNameProperty.kind)")
      return
    }
    #expect(middleName == person.middleName)
    #expect(try modelOutput.value(forProperty: "middleName") == person.middleName)
    let lastNameProperty = try #require(properties["lastName"])
    guard case let .string(lastName) = lastNameProperty.kind else {
      Issue.record("The 'lastName' property is not a string: \(lastNameProperty.kind)")
      return
    }
    #expect(lastName == person.lastName)
    #expect(try modelOutput.value(forProperty: "lastName") == person.lastName)
    let ageProperty = try #require(properties["age"])
    guard case let .number(age) = ageProperty.kind else {
      Issue.record("The 'age' property is not a number: \(ageProperty.kind)")
      return
    }
    #expect(Int(age) == person.age)
    #expect(try modelOutput.value(forProperty: "age") == person.age)
    // TODO: Implement `ModelOutput.value(_:)` and uncomment
    // #expect(try modelOutput.value() == person)
    #expect(orderedKeys == ["firstName", "middleName", "lastName", "age"])
  }
}

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

#if compiler(>=6.2)
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension Person: nonisolated FirebaseAILogic.Generable {
    nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
      firstName = try content.value(forProperty: "firstName")
      middleName = try content.value(forProperty: "middleName")
      lastName = try content.value(forProperty: "lastName")
      age = try content.value(forProperty: "age")
    }
  }
#else
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension Person: FirebaseAILogic.Generable {
    nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
      firstName = try content.value(forProperty: "firstName")
      middleName = try content.value(forProperty: "middleName")
      lastName = try content.value(forProperty: "lastName")
      age = try content.value(forProperty: "age")
    }
  }
#endif
