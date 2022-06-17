//
//  PropertyWrapper.swift
//  
//
//  Created by Fumito Ito on 2022/06/17.
//

import FirebaseRemoteConfig
import FirebaseRemoteConfigSwift

import XCTest

#if compiler(>=5.5.2) && canImport(_Concurrency)
  @available(iOS 14, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
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
