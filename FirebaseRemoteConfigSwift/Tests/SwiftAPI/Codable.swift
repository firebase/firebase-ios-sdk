// Copyright 2021 Google LLC
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

import FirebaseRemoteConfig
import FirebaseRemoteConfigSwift

import XCTest

#if compiler(>=5.5) && canImport(_Concurrency)
  @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
  class CodableTests: APITestBase {
    // MARK: - Test decoding Remote Config JSON values

    // Contrast this test with the subsequent one to see the value of the Codable API.
    func testFetchAndActivateWithoutCodable() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      let dict = try XCTUnwrap(config[Constants.jsonKey].jsonValue as? [String: AnyHashable])
      XCTAssertEqual(dict["recipeName"], "PB&J")
      XCTAssertEqual(dict["ingredients"], ["bread", "peanut butter", "jelly"])
      XCTAssertEqual(dict["cookTime"], 7)
      XCTAssertEqual(
        config[Constants.jsonKey].jsonValue as! [String: AnyHashable],
        Constants.jsonValue
      )
    }

    struct Recipe: Decodable {
      var recipeName: String
      var ingredients: [String]
      var cookTime: Int
    }

    func testFetchAndActivateWithCodable() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      let recipe = try XCTUnwrap(config[Constants.jsonKey].decoded(asType: Recipe.self))
      XCTAssertEqual(recipe.recipeName, "PB&J")
      XCTAssertEqual(recipe.ingredients, ["bread", "peanut butter", "jelly"])
      XCTAssertEqual(recipe.cookTime, 7)
    }

    func testFetchAndActivateWithCodableAlternativeAPI() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      let recipe: Recipe = try XCTUnwrap(config[Constants.jsonKey].decoded())
      XCTAssertEqual(recipe.recipeName, "PB&J")
      XCTAssertEqual(recipe.ingredients, ["bread", "peanut butter", "jelly"])
      XCTAssertEqual(recipe.cookTime, 7)
    }

    func testFetchAndActivateWithCodableBadJson() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      do {
        _ = try config[Constants.nonJsonKey].decoded(asType: Recipe.self)
      } catch let DecodingError.typeMismatch(_, context) {
        XCTAssertEqual(context.debugDescription,
                       "Expected to decode Dictionary<String, Any> but found " +
                         "FirebaseRemoteConfigValueDecoderHelper instead.")
        return
      }
      XCTFail("Failed to catch trying to decode non-JSON key as JSON")
    }

    // MARK: - Test setting Remote Config defaults via an encodable struct

    struct DataTestDefaults: Encodable {
      var bool: Bool
      var int: Int32
      var long: Int64
      var string: String
    }

    func testSetEncodeableDefaults() throws {
      let data = DataTestDefaults(
        bool: true,
        int: 2,
        long: 9_876_543_210,
        string: "four"
      )
      try config.setDefaults(from: data)
      let boolValue = try XCTUnwrap(config.defaultValue(forKey: "bool")).numberValue.boolValue
      XCTAssertTrue(boolValue)
      let intValue = try XCTUnwrap(config.defaultValue(forKey: "int")).numberValue.intValue
      XCTAssertEqual(intValue, 2)
      let longValue = try XCTUnwrap(config.defaultValue(forKey: "long")).numberValue.int64Value
      XCTAssertEqual(longValue, 9_876_543_210)
      let stringValue = try XCTUnwrap(config.defaultValue(forKey: "string")).stringValue
      XCTAssertEqual(stringValue, "four")
    }

    func testSetEncodeableDefaultsInvalid() throws {
      do {
        _ = try config.setDefaults(from: 7)
      } catch let RemoteConfigCodableError.invalidSetDefaultsInput(message) {
        XCTAssertEqual(message,
                       "The setDefaults input: 7, must be a Struct that encodes to a Dictionary")
        return
      }
      XCTFail("Failed to catch trying to encode an invalid input to setDefaults.")
    }

    // MARK: - Test extracting config to an decodable struct.

    struct MyConfig: Decodable {
      var Recipe: Recipe
      var notJSON: String
      var myInt: Int
      var myFloat: Float
      var myDecimal: Decimal
      var myTrue: Bool
      var myData: Data
    }

    func testExtractConfig() async throws {
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      let myConfig: MyConfig = try config.decoded()
      XCTAssertEqual(myConfig.notJSON, Constants.nonJsonValue)
      XCTAssertEqual(myConfig.myInt, Constants.intValue)
      XCTAssertEqual(myConfig.myTrue, true)
      XCTAssertEqual(myConfig.myFloat, Constants.floatValue)
      XCTAssertEqual(myConfig.myDecimal, Constants.decimalValue)
      XCTAssertEqual(myConfig.myData, Constants.dataValue)
      XCTAssertEqual(myConfig.Recipe.recipeName, "PB&J")
      XCTAssertEqual(myConfig.Recipe.ingredients, ["bread", "peanut butter", "jelly"])
      XCTAssertEqual(myConfig.Recipe.cookTime, 7)
    }

    // Additional fields in config are ignored.
    func testExtractConfigExtra() async throws {
      guard APITests.useFakeConfig else { return }
      fakeConsole.config["extra"] = "extra Value"
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      let myConfig: MyConfig = try config.decoded()
      XCTAssertEqual(myConfig.notJSON, Constants.nonJsonValue)
      XCTAssertEqual(myConfig.Recipe.recipeName, "PB&J")
      XCTAssertEqual(myConfig.Recipe.ingredients, ["bread", "peanut butter", "jelly"])
      XCTAssertEqual(myConfig.Recipe.cookTime, 7)
    }

    // Failure if requested field does not exist.
    func testExtractConfigMissing() async throws {
      struct MyConfig: Decodable {
        var missing: String
        var Recipe: String
        var notJSON: String
      }
      let status = try await config.fetchAndActivate()
      XCTAssertEqual(status, .successFetchedFromRemote)
      do {
        let _: MyConfig = try config.decoded()
      } catch let DecodingError.keyNotFound(codingKey, context) {
        XCTAssertEqual(codingKey.stringValue, "missing")
        print(codingKey, context)
        return
      }
      XCTFail("Failed to throw on missing field")
    }
  }
#endif
