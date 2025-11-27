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
import XCTest

final class GenerableTests: XCTestCase {
  func testInitializeGenerableTypeFromModelOutput() throws {
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

    XCTAssertEqual(person.firstName, "John")
    XCTAssertEqual(person.lastName, "Doe")
    XCTAssertEqual(person.age, 40)
    XCTAssertEqual(person.address.street, "123 Main St")
    XCTAssertEqual(person.address.city, "Anytown")
    XCTAssertEqual(person.address.zipCode, "12345")
  }

  func testInitializeGenerableWithMissingPropertyThrows() throws {
    let properties: [(String, any ConvertibleToModelOutput)] =
      [("firstName", "John"), ("age", 40)]
    let modelOutput = ModelOutput(
      properties: properties, uniquingKeysWith: { _, second in second }
    )

    XCTAssertThrowsError(try Person(modelOutput)) { error in
      guard let error = error as? GenerativeModel.GenerationError,
            case let .decodingFailure(context) = error else {
        XCTFail("Threw an unexpected error: \(error)")
        return
      }
      XCTAssertContains(context.debugDescription, "lastName")
    }
  }

  func testInitializeGenerableFromNonStructureThrows() throws {
    let modelOutput = ModelOutput("not a structure")

    XCTAssertThrowsError(try Person(modelOutput)) { error in
      guard let error = error as? GenerativeModel.GenerationError,
            case let .decodingFailure(context) = error else {
        XCTFail("Threw an unexpected error: \(error)")
        return
      }
      XCTAssertContains(context.debugDescription, "does not contain an object")
    }
  }

  func testInitializeGenerableWithTypeMismatchThrows() throws {
    let properties: [(String, any ConvertibleToModelOutput)] =
      [("firstName", "John"), ("lastName", "Doe"), ("age", "forty")]
    let modelOutput = ModelOutput(
      properties: properties, uniquingKeysWith: { _, second in second }
    )

    XCTAssertThrowsError(try Person(modelOutput)) { error in
      guard let error = error as? GenerativeModel.GenerationError,
            case let .decodingFailure(context) = error else {
        XCTFail("Threw an unexpected error: \(error)")
        return
      }
      XCTAssertContains(context.debugDescription, "\"forty\" does not contain Int")
    }
  }

  func testInitializeGenerableWithLossyNumericConversion() throws {
    let properties: [(String, any ConvertibleToModelOutput)] =
      [("firstName", "John"), ("lastName", "Doe"), ("age", 40.5)]
    let modelOutput = ModelOutput(
      properties: properties, uniquingKeysWith: { _, second in second }
    )

    XCTAssertThrowsError(try Person(modelOutput)) { error in
      guard let error = error as? GenerativeModel.GenerationError,
            case let .decodingFailure(context) = error else {
        XCTFail("Threw an unexpected error: \(error)")
        return
      }
      XCTAssertContains(context.debugDescription, "40.5 does not contain Int.")
    }
  }

  func testInitializeGenerableWithExtraProperties() throws {
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

    XCTAssertEqual(person.firstName, "John")
    XCTAssertEqual(person.lastName, "Doe")
    XCTAssertEqual(person.age, 40)
    XCTAssertEqual(person.address.street, "123 Main St")
    XCTAssertEqual(person.address.city, "Anytown")
    XCTAssertEqual(person.address.zipCode, "12345")
  }

  func testInitializeGenerableWithMissingOptionalProperty() throws {
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

    XCTAssertEqual(person.firstName, "John")
    XCTAssertEqual(person.lastName, "Doe")
    XCTAssertEqual(person.age, 40)
    XCTAssertNil(person.middleName)
    XCTAssertEqual(person.address.street, "123 Main St")
    XCTAssertEqual(person.address.city, "Anytown")
    XCTAssertEqual(person.address.zipCode, "12345")
  }

  func testConvertGenerableTypeToModelOutput() throws {
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
      XCTFail("Model output is not a structure.")
      return
    }
    let firstNameProperty = try XCTUnwrap(properties["firstName"])
    guard case let .string(firstName) = firstNameProperty.kind else {
      XCTFail("The 'firstName' property is not a string: \(firstNameProperty.kind)")
      return
    }
    XCTAssertEqual(firstName, person.firstName)
    XCTAssertEqual(try modelOutput.value(forProperty: "firstName"), person.firstName)
    let middleNameProperty = try XCTUnwrap(properties["middleName"])
    guard case let .string(middleName) = middleNameProperty.kind else {
      XCTFail("The 'middleName' property is not a string: \(middleNameProperty.kind)")
      return
    }
    XCTAssertEqual(middleName, person.middleName)
    XCTAssertEqual(try modelOutput.value(forProperty: "middleName"), person.middleName)
    let lastNameProperty = try XCTUnwrap(properties["lastName"])
    guard case let .string(lastName) = lastNameProperty.kind else {
      XCTFail("The 'lastName' property is not a string: \(lastNameProperty.kind)")
      return
    }
    XCTAssertEqual(lastName, person.lastName)
    XCTAssertEqual(try modelOutput.value(forProperty: "lastName"), person.lastName)
    let ageProperty = try XCTUnwrap(properties["age"])
    guard case let .number(age) = ageProperty.kind else {
      XCTFail("The 'age' property is not a number: \(ageProperty.kind)")
      return
    }
    XCTAssertEqual(Int(age), person.age)
    XCTAssertEqual(try modelOutput.value(forProperty: "age"), person.age)
    let addressProperty: Address = try modelOutput.value(forProperty: "address")
    XCTAssertEqual(addressProperty, person.address)
    XCTAssertEqual(try modelOutput.value(), person)
    XCTAssertEqual(orderedKeys, ["firstName", "middleName", "lastName", "age", "address"])
  }

  func testConvertGenerableWithNilOptionalPropertyToModelOutput() throws {
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
      XCTFail("Model output is not a structure.")
      return
    }
    XCTAssertNil(properties["middleName"])
    XCTAssertEqual(orderedKeys, ["firstName", "lastName", "age", "address"])
  }

  func testPersonJSONSchema() throws {
    let schema = Person.jsonSchema

    guard case let .object(_, _, properties) = schema.kind else {
      XCTFail("Schema kind is not an object.")
      return
    }

    XCTAssertEqual(properties.count, 5)
    let firstName = try XCTUnwrap(properties.first { $0.name == "firstName" })
    XCTAssert(firstName.type == String.self)
    XCTAssertFalse(firstName.isOptional)
    let middleName = try XCTUnwrap(properties.first { $0.name == "middleName" })
    XCTAssert(middleName.type == String.self)
    XCTAssertTrue(middleName.isOptional)
    let lastName = try XCTUnwrap(properties.first { $0.name == "lastName" })
    XCTAssert(lastName.type == String.self)
    XCTAssertFalse(lastName.isOptional)
    let age = try XCTUnwrap(properties.first { $0.name == "age" })
    XCTAssert(age.type == Int.self)
    XCTAssertFalse(age.isOptional)
    let address = try XCTUnwrap(properties.first { $0.name == "address" })
    XCTAssert(address.type == Address.self)
    XCTAssertFalse(address.isOptional)
  }
}

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

#if compiler(>=6.2)
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
#endif // compiler(>=6.2)

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct Address: Equatable {
  let street: String
  let city: String
  let zipCode: String

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
}

#if compiler(>=6.2)
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension Address: nonisolated FirebaseAILogic.Generable {
    nonisolated init(_ content: FirebaseAILogic.ModelOutput) throws {
      street = try content.value(forProperty: "street")
      city = try content.value(forProperty: "city")
      zipCode = try content.value(forProperty: "zipCode")
    }
  }
#else
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension Address: FirebaseAILogic.Generable {
    init(_ content: FirebaseAILogic.ModelOutput) throws {
      street = try content.value(forProperty: "street")
      city = try content.value(forProperty: "city")
      zipCode = try content.value(forProperty: "zipCode")
    }
  }
#endif // compiler(>=6.2)
