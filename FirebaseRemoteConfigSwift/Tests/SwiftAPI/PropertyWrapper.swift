/*
 * Copyright 2021 Google LLC
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

      @RemoteConfigProperty(forKey: Constants.intKey)
      var intValue: Int

      @RemoteConfigProperty(forKey: Constants.floatKey)
      var floatValue: Float

      @RemoteConfigProperty(forKey: Constants.floatKey)
      var doubleValue: Double

      @RemoteConfigProperty(forKey: Constants.decimalKey)
      var decimalValue: Decimal

      @RemoteConfigProperty(forKey: Constants.trueKey)
      var trueValue: Bool

      @RemoteConfigProperty(forKey: Constants.falseKey)
      var falseValue: Bool

      @RemoteConfigProperty(forKey: Constants.dataKey)
      var dataValue: Data

      @RemoteConfigProperty(forKey: Constants.jsonKey)
      var recipeValue: Recipe
    }

    func testFetchAndActivateWithPropertyWrapper() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)

      let tester = PropertyWrapperTester()
      XCTAssertEqual(tester.stringValue, Constants.stringValue)
      XCTAssertEqual(tester.intValue, Constants.intValue)
      XCTAssertEqual(tester.floatValue, Constants.floatValue)
      XCTAssertEqual(tester.doubleValue, Constants.doubleValue)
      XCTAssertEqual(tester.floatValue, Constants.floatValue)
      XCTAssertEqual(tester.trueValue, true)
      XCTAssertEqual(tester.falseValue, false)
      XCTAssertEqual(tester.dataValue, Constants.dataValue)
      let recipe = try XCTUnwrap(config[Constants.jsonKey].decoded(asType: Recipe.self))
      XCTAssertEqual(tester.recipeValue.recipeName, recipe.recipeName)
      XCTAssertEqual(tester.recipeValue.ingredients, recipe.ingredients)
      XCTAssertEqual(tester.recipeValue.cookTime, recipe.cookTime)
    }
  }
#endif
