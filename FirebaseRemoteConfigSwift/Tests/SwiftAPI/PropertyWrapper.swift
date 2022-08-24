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
      @RemoteConfigProperty(key: "Color") var configValue : String!

      @RemoteConfigProperty(key: Constants.stringKey)
      var stringValue : String!

      var stringKeyName: String {
        return _stringValue.key
      }

      @RemoteConfigProperty(key: Constants.intKey)
      var intValue: Int!

      var intKeyName: String {
        return _intValue.key
      }

      @RemoteConfigProperty(key: Constants.floatKey)
      var floatValue: Float!

      var floatKeyName: String {
        return _floatValue.key
      }

      @RemoteConfigProperty(key: Constants.floatKey)
      var doubleValue: Double!

      var doubleKeyName: String {
        return _doubleValue.key
      }

      @RemoteConfigProperty(key: Constants.decimalKey)
      var decimalValue: Decimal!

      var decimalKeyName: String {
        return _decimalValue.key
      }

      @RemoteConfigProperty(key: Constants.trueKey)
      var trueValue: Bool!

      var trueKeyName: String {
        return _trueValue.key
      }

      @RemoteConfigProperty(key: Constants.falseKey)
      var falseValue: Bool!

      var falseKeyName: String {
        return _falseValue.key
      }

      @RemoteConfigProperty(key: Constants.dataKey)
      var dataValue: Data!

      var dataKeyName: String {
        return _dataValue.key
      }

      @RemoteConfigProperty(key: Constants.jsonKey)
      var recipeValue: Recipe!

      var recipeKeyName: String {
        _recipeValue.key
      }
    }

    func testFetchAndActivateWithPropertyWrapper() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)

      let tester = await PropertyWrapperTester()
      //Task {
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
    }
  }
#endif
