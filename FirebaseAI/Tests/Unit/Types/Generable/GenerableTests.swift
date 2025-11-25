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

@testable import FirebaseAILogic
import Testing

struct GenerableTests {
  @Test
  func initializeGenerableTypeFromModelOutput() throws {
    let addressProperties: [(String, any ConvertibleToModelOutput)] =
      [("street", "123 Main St"), ("city", "Anytown"), ("zipCode", "12345")]
    let addressModelOutput = ModelOutput(
      properties: addressProperties, uniquingKeysWith: { _, second in second }
    )
    let properties: [(String, any ConvertibleToModelOutput)] =
      [("firstName", "John"), ("lastName", "Doe"), ("age", 40), ("address", addressModelOutput)]
    let modelOutput = ModelOutput(
      properties: properties, uniquingKeysWith: { _, second in second }
    )

    let person = try Person(modelOutput)

    #expect(person.firstName == "John")
    #expect(person.lastName == "Doe")
    #expect(person.age == 40)
    #expect(person.address.street == "123 Main St")
    #expect(person.address.city == "Anytown")
    #expect(person.address.zipCode == "12345")
  }

  @Test
  func initializeGenerableWithMissingProperty() throws {
    let properties: [(String, any ConvertibleToModelOutput)] =
      [("firstName", "John"), ("age", 40)]
    let modelOutput = ModelOutput(
      properties: properties, uniquingKeysWith: { _, second in second }
    )

    do {
      _ = try Person(modelOutput)
      Issue.record("Did not throw an error.")
    } catch let ModelOutput.DecodingError.missingProperty(name) {
      #expect(name == "lastName")
    } catch {
      Issue.record("Threw an unexpected error: \(error)")
    }
  }

  @Test
  func initializeGenerableFromNonStructure() throws {
    let modelOutput = ModelOutput("not a structure")

    do {
      _ = try Person(modelOutput)
      Issue.record("Did not throw an error.")
    } catch ModelOutput.DecodingError.notAStructure {
      // Expected error
    } catch {
      Issue.record("Threw an unexpected error: \(error)")
    }
  }

  @Test
  func initializeGenerableWithTypeMismatch() throws {
    let properties: [(String, any ConvertibleToModelOutput)] =
      [("firstName", "John"), ("lastName", "Doe"), ("age", "forty")]
    let modelOutput = ModelOutput(
      properties: properties, uniquingKeysWith: { _, second in second }
    )

    do {
      _ = try Person(modelOutput)
      Issue.record("Did not throw an error.")
    } catch let GenerativeModel.GenerationError.decodingFailure(context) {
      #expect(context.debugDescription.contains("\"forty\" does not contain Int"))
    } catch {
      Issue.record("Threw an unexpected error: \(error)")
    }
  }

  @Test
  func initializeGenerableWithLossyNumericConversion() throws {
    let properties: [(String, any ConvertibleToModelOutput)] =
      [("firstName", "John"), ("lastName", "Doe"), ("age", 40.5)]
    let modelOutput = ModelOutput(
      properties: properties, uniquingKeysWith: { _, second in second }
    )

    do {
      _ = try Person(modelOutput)
      Issue.record("Did not throw an error.")
    } catch let ModelOutput.DecodingError.dataCorrupted(context) {
      #expect(context.debugDescription.contains("ModelOutput cannot be represented as Int."))
    } catch {
      Issue.record("Threw an unexpected error: \(error)")
    }
  }

  @Test
  func initializeGenerableWithExtraProperties() throws {
    let addressProperties: [(String, any ConvertibleToModelOutput)] =
      [("street", "123 Main St"), ("city", "Anytown"), ("zipCode", "12345")]
    let addressModelOutput = ModelOutput(
      properties: addressProperties, uniquingKeysWith: { _, second in second }
    )
    let properties: [(String, any ConvertibleToModelOutput)] =
      [
        ("firstName", "John"),
        ("lastName", "Doe"),
        ("age", 40),
        ("address", addressModelOutput),
        ("country", "USA"),
      ]
    let modelOutput = ModelOutput(
      properties: properties, uniquingKeysWith: { _, second in second }
    )

    let person = try Person(modelOutput)

    #expect(person.firstName == "John")
    #expect(person.lastName == "Doe")
    #expect(person.age == 40)
    #expect(person.address.street == "123 Main St")
    #expect(person.address.city == "Anytown")
    #expect(person.address.zipCode == "12345")
  }

  @Test
  func initializeGenerableWithMissingOptionalProperty() throws {
    let addressProperties: [(String, any ConvertibleToModelOutput)] =
      [("street", "123 Main St"), ("city", "Anytown"), ("zipCode", "12345")]
    let addressModelOutput = ModelOutput(
      properties: addressProperties, uniquingKeysWith: { _, second in second }
    )
    let properties: [(String, any ConvertibleToModelOutput)] =
      [("firstName", "John"), ("lastName", "Doe"), ("age", 40), ("address", addressModelOutput)]
    let modelOutput = ModelOutput(
      properties: properties, uniquingKeysWith: { _, second in second }
    )

    let person = try Person(modelOutput)

    #expect(person.firstName == "John")
    #expect(person.lastName == "Doe")
    #expect(person.age == 40)
    #expect(person.middleName == nil)
    #expect(person.address.street == "123 Main St")
    #expect(person.address.city == "Anytown")
    #expect(person.address.zipCode == "12345")
  }

  @Test
  func convertGenerableTypeToModelOutput() throws {
    let address = Address(street: "456 Oak Ave", city: "Someplace", zipCode: "54321")
    let person = Person(
      firstName: "Jane",
      middleName: "Marie",
      lastName: "Smith",
      age: 32,
      address: address
    )

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
    let addressProperty: Address = try modelOutput.value(forProperty: "address")
    #expect(addressProperty == person.address)
    #expect(try modelOutput.value() == person)
    #expect(orderedKeys == ["firstName", "middleName", "lastName", "age", "address"])
  }

  @Test
  func convertGenerableWithNilOptionalPropertyToModelOutput() throws {
    let address = Address(street: "789 Pine Ln", city: "Nowhere", zipCode: "00000")
    let person = Person(
      firstName: "Jane",
      middleName: nil,
      lastName: "Smith",
      age: 32,
      address: address
    )

    let modelOutput = person.modelOutput

    guard case let .structure(properties, orderedKeys) = modelOutput.kind else {
      Issue.record("Model output is not a structure.")
      return
    }

    #expect(properties["middleName"] == nil)
    #expect(orderedKeys == ["firstName", "lastName", "age", "address"])
  }

  @Test
  func testPersonJSONSchema() throws {
    let schema = Person.jsonSchema
    guard case let .object(_, _, properties) = schema.kind else {
      Issue.record("Schema kind is not an object.")
      return
    }
    #expect(properties.count == 5)

    let firstName = try #require(properties.first { $0.name == "firstName" })
    #expect(ObjectIdentifier(firstName.type) == ObjectIdentifier(String.self))
    #expect(firstName.isOptional == false)

    let middleName = try #require(properties.first { $0.name == "middleName" })
    #expect(ObjectIdentifier(middleName.type) == ObjectIdentifier(String.self))
    #expect(middleName.isOptional == true)

    let lastName = try #require(properties.first { $0.name == "lastName" })
    #expect(ObjectIdentifier(lastName.type) == ObjectIdentifier(String.self))
    #expect(lastName.isOptional == false)

    let age = try #require(properties.first { $0.name == "age" })
    #expect(ObjectIdentifier(age.type) == ObjectIdentifier(Int.self))
    #expect(age.isOptional == false)

    let address = try #require(properties.first { $0.name == "address" })
    #expect(ObjectIdentifier(address.type) == ObjectIdentifier(Address.self))
    #expect(address.isOptional == false)
  }
}

#if compiler(>=6.2)
  // An example of the expected output from the `@FirebaseAILogic.Generable` macro.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  struct Person: Equatable {
    let firstName: String
    let middleName: String?
    let lastName: String
    let age: Int
    let address: Address

    nonisolated static var jsonSchema: FirebaseAILogic.JSONSchema {
      FirebaseAILogic.JSONSchema(
        type: Self.self,
        properties: [
          FirebaseAILogic.JSONSchema.Property(name: "firstName", type: String.self),
          FirebaseAILogic.JSONSchema.Property(name: "middleName", type: String?.self),
          FirebaseAILogic.JSONSchema.Property(name: "lastName", type: String.self),
          FirebaseAILogic.JSONSchema.Property(name: "age", type: Int.self),
          FirebaseAILogic.JSONSchema.Property(name: "address", type: Address.self),
        ]
      )
    }

    nonisolated var modelOutput: FirebaseAILogic.ModelOutput {
      var properties: [(name: String, value: any FirebaseAILogic.ConvertibleToModelOutput)] = []
      properties.append(("firstName", firstName))
      if let middleName {
        properties.append(("middleName", middleName))
      }
      properties.append(("lastName", lastName))
      properties.append(("age", age))
      properties.append(("address", address))
      return ModelOutput(
        properties: properties,
        uniquingKeysWith: { _, second in
          second
        }
      )
    }
  }

  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension Person: nonisolated FirebaseAILogic.Generable {
    nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
      firstName = try content.value(forProperty: "firstName")
      middleName = try content.value(forProperty: "middleName")
      lastName = try content.value(forProperty: "lastName")
      age = try content.value(forProperty: "age")
      address = try content.value(forProperty: "address")
    }
  }
#else
  // An example of the expected output from the `@FirebaseAILogic.Generable` macro.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  struct Person: Equatable {
    let firstName: String
    let middleName: String?
    let lastName: String
    let age: Int
    let address: Address

    static var jsonSchema: FirebaseAILogic.JSONSchema {
      FirebaseAILogic.JSONSchema(
        type: Self.self,
        properties: [
          FirebaseAILogic.JSONSchema.Property(name: "firstName", type: String.self),
          FirebaseAILogic.JSONSchema.Property(name: "middleName", type: String?.self),
          FirebaseAILogic.JSONSchema.Property(name: "lastName", type: String.self),
          FirebaseAILogic.JSONSchema.Property(name: "age", type: Int.self),
          FirebaseAILogic.JSONSchema.Property(name: "address", type: Address.self),
        ]
      )
    }

    var modelOutput: FirebaseAILogic.ModelOutput {
      var properties: [(name: String, value: any FirebaseAILogic.ConvertibleToModelOutput)] = []
      properties.append(("firstName", firstName))
      if let middleName {
        properties.append(("middleName", middleName))
      }
      properties.append(("lastName", lastName))
      properties.append(("age", age))
      properties.append(("address", address))
      return ModelOutput(
        properties: properties,
        uniquingKeysWith: { _, second in
          second
        }
      )
    }
  }

  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension Person: FirebaseAILogic.Generable {
    init(_ content: FirebaseAILogic.ModelOutput) throws {
      firstName = try content.value(forProperty: "firstName")
      middleName = try content.value(forProperty: "middleName")
      lastName = try content.value(forProperty: "lastName")
      age = try content.value(forProperty: "age")
      address = try content.value(forProperty: "address")
    }
  }
#endif

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct Address: Equatable {
  let street: String
  let city: String
  let zipCode: String
}

#if compiler(>=6.2)
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension Address: nonisolated FirebaseAILogic.Generable {
    nonisolated static var jsonSchema: FirebaseAILogic.JSONSchema {
      FirebaseAILogic.JSONSchema(
        type: Self.self,
        properties: [
          FirebaseAILogic.JSONSchema.Property(name: "street", type: String.self),
          FirebaseAILogic.JSONSchema.Property(name: "city", type: String.self),
          FirebaseAILogic.JSONSchema.Property(name: "zipCode", type: String.self),
        ]
      )
    }

    nonisolated var modelOutput: FirebaseAILogic.ModelOutput {
      let properties: [(name: String, value: any FirebaseAILogic.ConvertibleToModelOutput)] = [
        ("street", street),
        ("city", city),
        ("zipCode", zipCode),
      ]
      return ModelOutput(
        properties: properties,
        uniquingKeysWith: { _, second in
          second
        }
      )
    }

    nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
      street = try content.value(forProperty: "street")
      city = try content.value(forProperty: "city")
      zipCode = try content.value(forProperty: "zipCode")
    }
  }
#else
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension Address: FirebaseAILogic.Generable {
    static var jsonSchema: FirebaseAILogic.JSONSchema {
      FirebaseAILogic.JSONSchema(
        type: Self.self,
        properties: [
          FirebaseAILogic.JSONSchema.Property(name: "street", type: String.self),
          FirebaseAILogic.JSONSchema.Property(name: "city", type: String.self),
          FirebaseAILogic.JSONSchema.Property(name: "zipCode", type: String.self),
        ]
      )
    }

    var modelOutput: FirebaseAILogic.ModelOutput {
      let properties: [(name: String, value: any FirebaseAILogic.ConvertibleToModelOutput)] = [
        ("street", street),
        ("city", city),
        ("zipCode", zipCode),
      ]
      return ModelOutput(
        properties: properties,
        uniquingKeysWith: { _, second in
          second
        }
      )
    }

    init(_ content: FirebaseAILogic.ModelOutput) throws {
      street = try content.value(forProperty: "street")
      city = try content.value(forProperty: "city")
      zipCode = try content.value(forProperty: "zipCode")
    }
  }
#endif
