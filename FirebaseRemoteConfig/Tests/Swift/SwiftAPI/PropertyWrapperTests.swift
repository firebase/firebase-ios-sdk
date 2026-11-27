/*
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@testable import FirebaseRemoteConfig

import XCTest

@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
class PropertyWrapperTests: APITestBase {
  // MARK: - Test fetching Remote Config JSON values into struct property

  struct Recipe: Decodable {
    var recipeName: String
    var ingredients: [String]
    var cookTime: Int
  }

  static let fallbackString = "fallback"
  static let fallbackInt = 50
  static let fallbackFloat: Float = 50.2
  static let fallbackDouble: Double = 16_777_216.333921
  static let fallbackDecimal: Decimal = 235
  static let fallbackData = "hello".data(using: .utf8)!
  static let fallbackArray = ["mango", "pineapple", "papaya"]
  static let fallbackDict = [
    "session 0": "breakfast", "session 1": "keynote", "session 2": "state of union",
  ]
  static let fallbackJSON = Recipe(
    recipeName: "muffin", ingredients: ["flour", "sugar"], cookTime: 45
  )

  /// Only the keys of these property wrappers are read directly, since reading a wrapped value
  /// outside of a SwiftUI view triggers a SwiftUI runtime warning. Tests read the values with
  /// `remoteConfigPropertyValue(_:key:fallback:)`.
  struct PropertyWrapperTester {
    @RemoteConfigProperty(key: Constants.stringKey, fallback: "")
    var stringValue: String!

    var stringKeyName: String {
      return _stringValue.key
    }

    @RemoteConfigProperty(key: Constants.intKey, fallback: 0)
    var intValue: Int!

    var intKeyName: String {
      return _intValue.key
    }

    @RemoteConfigProperty(key: Constants.floatKey, fallback: 0)
    var floatValue: Float!

    var floatKeyName: String {
      return _floatValue.key
    }

    @RemoteConfigProperty(key: Constants.floatKey, fallback: 0)
    var doubleValue: Double!

    var doubleKeyName: String {
      return _doubleValue.key
    }

    @RemoteConfigProperty(key: Constants.decimalKey, fallback: 0)
    var decimalValue: Decimal!

    var decimalKeyName: String {
      return _decimalValue.key
    }

    @RemoteConfigProperty(key: Constants.trueKey, fallback: false)
    var trueValue: Bool!

    var trueKeyName: String {
      return _trueValue.key
    }

    @RemoteConfigProperty(key: Constants.falseKey, fallback: false)
    var falseValue: Bool!

    var falseKeyName: String {
      return _falseValue.key
    }

    @RemoteConfigProperty(key: Constants.dataKey, fallback: Data())
    var dataValue: Data!

    var dataKeyName: String {
      return _dataValue.key
    }

    @RemoteConfigProperty(key: Constants.jsonKey, fallback: nil)
    var recipeValue: Recipe!

    var recipeKeyName: String {
      _recipeValue.key
    }

    @RemoteConfigProperty(key: Constants.arrayKey, fallback: [])
    var arrayValue: [String]!

    var arrayKeyName: String {
      _arrayValue.key
    }

    @RemoteConfigProperty(key: Constants.dictKey, fallback: [:])
    var dictValue: [String: String]!

    var dictKeyName: String {
      _dictValue.key
    }
  }

  func testFetchAndActivateWithPropertyWrapper() async throws {
    let status = try await config.fetchAndActivate()
    XCTAssertEqual(status, .successFetchedFromRemote)

    // The types, keys, and fallbacks match the property wrappers in `PropertyWrapperTester`.
    let stringValue = remoteConfigPropertyValue(
      String?.self, key: Constants.stringKey, fallback: ""
    )
    XCTAssertEqual(stringValue, Constants.stringValue)

    let intValue = remoteConfigPropertyValue(Int?.self, key: Constants.intKey, fallback: 0)
    XCTAssertEqual(intValue, Constants.intValue)

    let floatValue = remoteConfigPropertyValue(Float?.self, key: Constants.floatKey, fallback: 0)
    XCTAssertEqual(floatValue, Constants.floatValue)

    let doubleValue = remoteConfigPropertyValue(Double?.self, key: Constants.floatKey, fallback: 0)
    XCTAssertEqual(doubleValue, Constants.doubleValue)

    let decimalValue = remoteConfigPropertyValue(
      Decimal?.self, key: Constants.decimalKey, fallback: 0
    )
    XCTAssertEqual(decimalValue, Constants.decimalValue)

    let trueValue = remoteConfigPropertyValue(Bool?.self, key: Constants.trueKey, fallback: false)
    XCTAssertEqual(trueValue, true)

    let falseValue = remoteConfigPropertyValue(Bool?.self, key: Constants.falseKey, fallback: false)
    XCTAssertEqual(falseValue, false)

    let dataValue = remoteConfigPropertyValue(Data?.self, key: Constants.dataKey, fallback: Data())
    XCTAssertEqual(dataValue, Constants.dataValue)

    let recipe = try XCTUnwrap(config[Constants.jsonKey].decoded(asType: Recipe.self))
    let recipeValue = remoteConfigPropertyValue(Recipe?.self, key: Constants.jsonKey, fallback: nil)
    XCTAssertEqual(recipeValue?.recipeName, recipe.recipeName)
    XCTAssertEqual(recipeValue?.ingredients, recipe.ingredients)
    XCTAssertEqual(recipeValue?.cookTime, recipe.cookTime)

    let arrayValue = remoteConfigPropertyValue(
      [String]?.self, key: Constants.arrayKey, fallback: []
    )
    XCTAssertEqual(arrayValue, Constants.arrayValue)

    let dictValue = remoteConfigPropertyValue(
      [String: String]?.self, key: Constants.dictKey, fallback: [:]
    )
    XCTAssertEqual(dictValue, Constants.dictValue)
  }

  func testPropertyWrapperInstanceValues() async {
    let tester = await PropertyWrapperTester()

    let stringKeyName = await tester.stringKeyName
    XCTAssertEqual(Constants.stringKey, stringKeyName)

    let intKeyName = await tester.intKeyName
    XCTAssertEqual(Constants.intKey, intKeyName)

    let floatKeyName = await tester.floatKeyName
    XCTAssertEqual(Constants.floatKey, floatKeyName)

    let doubleKeyName = await tester.doubleKeyName
    XCTAssertEqual(Constants.floatKey, doubleKeyName)

    let decimalKeyName = await tester.decimalKeyName
    XCTAssertEqual(Constants.decimalKey, decimalKeyName)

    let trueKeyName = await tester.trueKeyName
    XCTAssertEqual(Constants.trueKey, trueKeyName)

    let falseKeyName = await tester.falseKeyName
    XCTAssertEqual(Constants.falseKey, falseKeyName)

    let dataKeyName = await tester.dataKeyName
    XCTAssertEqual(Constants.dataKey, dataKeyName)

    let recipeKeyName = await tester.recipeKeyName
    XCTAssertEqual(Constants.jsonKey, recipeKeyName)

    let arrayKeyName = await tester.arrayKeyName
    XCTAssertEqual(Constants.arrayKey, arrayKeyName)

    let dictKeyName = await tester.dictKeyName
    XCTAssertEqual(Constants.dictKey, dictKeyName)
  }

  func testPlaceHolderValues() {
    // None of these keys are in the config, so each value is its fallback.
    let stringValue = remoteConfigPropertyValue(
      String.self, key: "NewKeyNotInSystem", fallback: PropertyWrapperTests.fallbackString
    )
    XCTAssertEqual(stringValue, PropertyWrapperTests.fallbackString)

    let intValue = remoteConfigPropertyValue(
      Int?.self, key: "NewIntKeyNotInSystem", fallback: PropertyWrapperTests.fallbackInt
    )
    XCTAssertEqual(intValue, PropertyWrapperTests.fallbackInt)

    let zeroValue = remoteConfigPropertyValue(Int?.self, key: "NewZeroKey", fallback: 0)
    XCTAssertEqual(zeroValue, 0)

    let floatValue = remoteConfigPropertyValue(
      Float?.self, key: "newFloatKey", fallback: PropertyWrapperTests.fallbackFloat
    )
    XCTAssertEqual(floatValue, PropertyWrapperTests.fallbackFloat)

    let doubleValue = remoteConfigPropertyValue(
      Double?.self, key: "newDoubleKey", fallback: PropertyWrapperTests.fallbackDouble
    )
    XCTAssertEqual(doubleValue, PropertyWrapperTests.fallbackDouble)

    let decimalValue = remoteConfigPropertyValue(
      Decimal?.self, key: "newDecimalKey", fallback: PropertyWrapperTests.fallbackDecimal
    )
    XCTAssertEqual(decimalValue, PropertyWrapperTests.fallbackDecimal)

    let trueKeyFalseValue = remoteConfigPropertyValue(
      Bool?.self, key: "newTrueKey", fallback: false
    )
    XCTAssertEqual(trueKeyFalseValue, false)

    let trueKeyTrueValue = remoteConfigPropertyValue(
      Bool?.self, key: "newTrueKey2", fallback: true
    )
    XCTAssertEqual(trueKeyTrueValue, true)

    let falseKeyTrueValue = remoteConfigPropertyValue(
      Bool?.self, key: "newFalseKey", fallback: true
    )
    XCTAssertEqual(falseKeyTrueValue, true)

    let falseKeyFalseValue = remoteConfigPropertyValue(
      Bool?.self, key: "newFalseKey2", fallback: false
    )
    XCTAssertEqual(falseKeyFalseValue, false)

    let dataValue = remoteConfigPropertyValue(
      Data.self, key: "newDataKey", fallback: PropertyWrapperTests.fallbackData
    )
    XCTAssertEqual(dataValue, PropertyWrapperTests.fallbackData)

    let arrayValue = remoteConfigPropertyValue(
      [String]?.self, key: "newArrayKey", fallback: PropertyWrapperTests.fallbackArray
    )
    XCTAssertEqual(arrayValue, PropertyWrapperTests.fallbackArray)

    let dictValue = remoteConfigPropertyValue(
      [String: String]?.self, key: "newDictKey", fallback: PropertyWrapperTests.fallbackDict
    )
    XCTAssertEqual(dictValue, PropertyWrapperTests.fallbackDict)

    let recipeValue = remoteConfigPropertyValue(
      Recipe?.self, key: "newJSONKey", fallback: PropertyWrapperTests.fallbackJSON
    )
    XCTAssertEqual(recipeValue?.recipeName, "muffin")
    XCTAssertEqual(recipeValue?.ingredients, ["flour", "sugar"])
    XCTAssertEqual(recipeValue?.cookTime, 45)
  }

  /// When an activated template no longer contains a key, the property should use the key's
  /// in-app default, or its fallback if the key has no default.
  @MainActor
  func testActivationThatRemovesKeyUsesDefaultOrFallback() async throws {
    let keyWithDefault = "PropertyWrapperRemovedKeyWithDefault"
    let keyWithoutDefault = "PropertyWrapperRemovedKeyWithoutDefault"
    config.setDefaults([keyWithDefault: "default" as NSObject])
    fakeConsole.config[keyWithDefault] = "remote1"
    fakeConsole.config[keyWithoutDefault] = "remote2"
    var status = try await config.fetchAndActivate()
    XCTAssertEqual(status, .successFetchedFromRemote)

    // Create the observables the same way `RemoteConfigProperty.init(key:fallback:)` does.
    let withDefault = RemoteConfigValueObservable<String>(
      key: keyWithDefault, fallbackValue: "fallback"
    )
    let withoutDefault = RemoteConfigValueObservable<String>(
      key: keyWithoutDefault, fallbackValue: "fallback"
    )
    XCTAssertEqual(withDefault.configValue, "remote1")
    XCTAssertEqual(withoutDefault.configValue, "remote2")

    // Publish and activate a template without the keys. The observables update on the main
    // thread when the activation notification is posted, before this test resumes.
    fakeConsole.config[keyWithDefault] = nil
    fakeConsole.config[keyWithoutDefault] = nil
    let activated = expectation(forNotification: .onRemoteConfigActivated, object: nil)
    status = try await config.fetchAndActivate()
    XCTAssertEqual(status, .successFetchedFromRemote)
    await fulfillment(of: [activated], timeout: 10)

    XCTAssertEqual(withDefault.configValue, "default")
    XCTAssertEqual(withoutDefault.configValue, "fallback")
  }
}
