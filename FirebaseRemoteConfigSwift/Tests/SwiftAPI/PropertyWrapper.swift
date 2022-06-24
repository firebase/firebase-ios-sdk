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
      @RemoteConfigProperty(forKey: Constants.stringKey)
      var stringValue: String

      var stringKeyName: String {
        return _stringValue.key
      }

      @RemoteConfigProperty(forKey: Constants.intKey)
      var intValue: Int

      var intKeyName: String {
        return _intValue.key
      }

      @RemoteConfigProperty(forKey: Constants.floatKey)
      var floatValue: Float

      var floatKeyName: String {
        return _floatValue.key
      }

      @RemoteConfigProperty(forKey: Constants.floatKey)
      var doubleValue: Double

      var doubleKeyName: String {
        return _doubleValue.key
      }

      @RemoteConfigProperty(forKey: Constants.decimalKey)
      var decimalValue: Decimal

      var decimalKeyName: String {
        return _decimalValue.key
      }

      @RemoteConfigProperty(forKey: Constants.trueKey)
      var trueValue: Bool

      var trueKeyName: String {
        return _trueValue.key
      }

      @RemoteConfigProperty(forKey: Constants.falseKey)
      var falseValue: Bool

      var falseKeyName: String {
        return _falseValue.key
      }

      @RemoteConfigProperty(forKey: Constants.dataKey)
      var dataValue: Data

      var dataKeyName: String {
        return _dataValue.key
      }

      @RemoteConfigProperty(forKey: Constants.jsonKey)
      var recipeValue: Recipe

      var recipeKeyName: String {
        _recipeValue.key
      }

      var lastFetchTime: Date? {
        return _stringValue.lastFetchTime
      }

      var lastFetchStatus: RemoteConfigFetchStatus {
        return _stringValue.lastFetchStatus
      }
    }

    func testFetchAndActivateWithPropertyWrapper() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)

      let tester = PropertyWrapperTester()
      XCTAssertEqual(tester.stringValue, Constants.stringValue)
      XCTAssertEqual(tester.intValue, Constants.intValue)
      XCTAssertEqual(tester.floatValue, Constants.floatValue)
      XCTAssertEqual(tester.doubleValue, Constants.doubleValue)
      XCTAssertEqual(tester.decimalValue, Constants.decimalValue)
      XCTAssertEqual(tester.trueValue, true)
      XCTAssertEqual(tester.falseValue, false)
      XCTAssertEqual(tester.dataValue, Constants.dataValue)
      let recipe = try XCTUnwrap(config[Constants.jsonKey].decoded(asType: Recipe.self))
      XCTAssertEqual(tester.recipeValue.recipeName, recipe.recipeName)
      XCTAssertEqual(tester.recipeValue.ingredients, recipe.ingredients)
      XCTAssertEqual(tester.recipeValue.cookTime, recipe.cookTime)
    }

    func testPropertyWrapperInstanceValues() async {
      let tester = PropertyWrapperTester()

      XCTAssertEqual(config.lastFetchTime, tester.lastFetchTime)
      XCTAssertEqual(config.lastFetchStatus, tester.lastFetchStatus)

      XCTAssertEqual(Constants.stringKey, tester.stringKeyName)
      XCTAssertEqual(Constants.intKey, tester.intKeyName)
      XCTAssertEqual(Constants.floatKey, tester.floatKeyName)
      XCTAssertEqual(Constants.floatKey, tester.doubleKeyName)
      XCTAssertEqual(Constants.decimalKey, tester.decimalKeyName)
      XCTAssertEqual(Constants.trueKey, tester.trueKeyName)
      XCTAssertEqual(Constants.falseKey, tester.falseKeyName)
      XCTAssertEqual(Constants.dataKey, tester.dataKeyName)
      XCTAssertEqual(Constants.jsonKey, tester.recipeKeyName)
    }
  }
#endif
