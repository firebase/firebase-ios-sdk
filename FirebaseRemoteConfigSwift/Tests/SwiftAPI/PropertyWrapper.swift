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
import FirebaseRemoteConfigSwift

import XCTest

#if compiler(>=5.5.2) && canImport(_Concurrency)
  @available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
  class PropertyWrapperTests: APITestBase {
    // MARK: - Test fetching Remote Config JSON values into struct property
    struct Recipe: Decodable {
      var recipeName: String
      var ingredients: [String]
      var cookTime: Int
    }

    struct PropertyWrapperTester {

      @RemoteConfigProperty(key: Constants.stringKey, placeholder: "")
      var stringValue : String!

      var stringKeyName: String {
        return _stringValue.key
      }

      @RemoteConfigProperty(key: Constants.intKey, placeholder: 0)
      var intValue: Int!

      var intKeyName: String {
        return _intValue.key
      }

      @RemoteConfigProperty(key: Constants.floatKey, placeholder: 0)
      var floatValue: Float!

      var floatKeyName: String {
        return _floatValue.key
      }

      @RemoteConfigProperty(key: Constants.floatKey, placeholder: 0)
      var doubleValue: Double!

      var doubleKeyName: String {
        return _doubleValue.key
      }

      @RemoteConfigProperty(key: Constants.decimalKey, placeholder: 0)
      var decimalValue: Decimal!

      var decimalKeyName: String {
        return _decimalValue.key
      }

      @RemoteConfigProperty(key: Constants.trueKey, placeholder: false)
      var trueValue: Bool!

      var trueKeyName: String {
        return _trueValue.key
      }

      @RemoteConfigProperty(key: Constants.falseKey, placeholder: false)
      var falseValue: Bool!

      var falseKeyName: String {
        return _falseValue.key
      }

      @RemoteConfigProperty(key: Constants.dataKey, placeholder: Data())
      var dataValue: Data!

      var dataKeyName: String {
        return _dataValue.key
      }

      @RemoteConfigProperty(key: Constants.jsonKey, placeholder: nil)
      var recipeValue: Recipe!

      var recipeKeyName: String {
        _recipeValue.key
      }

      @RemoteConfigProperty(key: Constants.arrayKey, placeholder: [])
      var arrayValue: [String]!

      var arrayKeyName: String {
        _arrayValue.key
      }

      @RemoteConfigProperty(key: Constants.dictKey, placeholder: [:])
      var dictValue: [String:String]!

      var dictKeyName: String {
        _dictValue.key
      }
    }

    struct DefaultsValuesTester {
      @RemoteConfigProperty(key: Constants.stringKey, placeholder: "")
      var stringValue : String

      var stringKeyName: String {
        _stringValue.key
      }
    }

    struct PlaceholderValueTester {
      @RemoteConfigProperty(key: "NewKeyNotInSystem", placeholder: "placeholdervalue")
      var stringValue : String

      var stringKeyName: String {
        _stringValue.key
      }
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
      let placeholderValue = "placeholdervalue"

      let tester = await PlaceholderValueTester()
      let stringValue = await tester.stringValue

      XCTAssertEqual(stringValue, placeholderValue)
    }
  }
#endif
