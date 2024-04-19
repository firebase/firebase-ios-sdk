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

import FirebaseRemoteConfig

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

  struct PlaceholderValueTester {
    @RemoteConfigProperty(key: "NewKeyNotInSystem", fallback: fallbackString)
    var stringValue: String

    @RemoteConfigProperty(key: "NewIntKeyNotInSystem", fallback: fallbackInt)
    var intValue: Int!

    @RemoteConfigProperty(key: "NewZeroKey", fallback: 0)
    var zeroIntValue: Int!

    @RemoteConfigProperty(key: "newFloatKey", fallback: fallbackFloat)
    var floatValue: Float!

    @RemoteConfigProperty(key: "newDoubleKey", fallback: fallbackDouble)
    var doubleValue: Double!

    @RemoteConfigProperty(key: "newDecimalKey", fallback: fallbackDecimal)
    var decimalValue: Decimal!

    @RemoteConfigProperty(key: "newTrueKey", fallback: false)
    var trueKeyFalseValue: Bool!

    @RemoteConfigProperty(key: "newTrueKey2", fallback: true)
    var trueKeyTrueValue: Bool!

    @RemoteConfigProperty(key: "newFalseKey", fallback: true)
    var falseKeyTrueValue: Bool!

    @RemoteConfigProperty(key: "newFalseKey2", fallback: false)
    var falseKeyFalseValue: Bool!

    @RemoteConfigProperty(key: "newDataKey", fallback: fallbackData)
    var dataValue: Data

    @RemoteConfigProperty(key: "newJSONKey", fallback: fallbackJSON)
    var recipeValue: Recipe!

    @RemoteConfigProperty(key: "newArrayKey", fallback: fallbackArray)
    var arrayValue: [String]!

    @RemoteConfigProperty(key: "newDictKey", fallback: fallbackDict)
    var dictValue: [String: String]!
  }

  func testFetchAndActivateWithPropertyWrapper() async throws {
    let status = try await config.fetchAndActivate()
    XCTAssertEqual(status, .successFetchedFromRemote)

    let tester = await PropertyWrapperTester()

    let stringValue = await tester.stringValue
    XCTAssertEqual(stringValue, Constants.stringValue)

    let intValue = await tester.intValue
    XCTAssertEqual(intValue, Constants.intValue)

    let floatValue = await tester.floatValue
    XCTAssertEqual(floatValue, Constants.floatValue)

    let doubleValue = await tester.doubleValue
    XCTAssertEqual(doubleValue, Constants.doubleValue)

    let decimalValue = await tester.decimalValue
    XCTAssertEqual(decimalValue, Constants.decimalValue)

    let trueValue = await tester.trueValue
    XCTAssertEqual(trueValue, true)

    let falseValue = await tester.falseValue
    XCTAssertEqual(falseValue, false)

    let dataValue = await tester.dataValue
    XCTAssertEqual(dataValue, Constants.dataValue)

    let recipe = try XCTUnwrap(config[Constants.jsonKey].decoded(asType: Recipe.self))
    let recipeValue = await tester.recipeValue
    XCTAssertEqual(recipeValue?.recipeName, recipe.recipeName)
    XCTAssertEqual(recipeValue?.ingredients, recipe.ingredients)
    XCTAssertEqual(recipeValue?.cookTime, recipe.cookTime)

    let arrayValue = await tester.arrayValue
    XCTAssertEqual(arrayValue, Constants.arrayValue)

    let dictValue = await tester.dictValue
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

  func testPlaceHolderValues() async throws {
    // Make sure the values below are consistent with the property wrapper
    // in PlaceholderValueTester
    let tester = await PlaceholderValueTester()

    let stringValue = await tester.stringValue
    XCTAssertEqual(stringValue, PropertyWrapperTests.fallbackString)

    let intValue = await tester.intValue
    XCTAssertEqual(intValue, PropertyWrapperTests.fallbackInt)

    let zeroValue = await tester.zeroIntValue
    XCTAssertEqual(zeroValue, 0)

    let floatValue = await tester.floatValue
    XCTAssertEqual(floatValue, PropertyWrapperTests.fallbackFloat)

    let doubleValue = await tester.doubleValue
    XCTAssertEqual(doubleValue, PropertyWrapperTests.fallbackDouble)

    let decimalValue = await tester.decimalValue
    XCTAssertEqual(decimalValue, PropertyWrapperTests.fallbackDecimal)

    let trueKeyFalseValue = await tester.trueKeyFalseValue
    XCTAssertEqual(trueKeyFalseValue, false)

    let trueKeyTrueValue = await tester.trueKeyTrueValue
    XCTAssertEqual(trueKeyTrueValue, true)

    let falseKeyTrueValue = await tester.falseKeyTrueValue
    XCTAssertEqual(falseKeyTrueValue, true)

    let falseKeyFalseValue = await tester.falseKeyFalseValue
    XCTAssertEqual(falseKeyFalseValue, false)

    let dataValue = await tester.dataValue
    XCTAssertEqual(dataValue, PropertyWrapperTests.fallbackData)

    let arrayValue = await tester.arrayValue
    XCTAssertEqual(arrayValue, PropertyWrapperTests.fallbackArray)

    let dictValue = await tester.dictValue
    XCTAssertEqual(dictValue, PropertyWrapperTests.fallbackDict)

    let recipeValue = await tester.recipeValue
    XCTAssertEqual(recipeValue?.recipeName, "muffin")
    XCTAssertEqual(recipeValue?.ingredients, ["flour", "sugar"])
    XCTAssertEqual(recipeValue?.cookTime, 45)
  }
}
