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

import FirebaseCore
import FirebaseRemoteConfig

import XCTest

let ConfigKeyForThisTestOnly = "PropertyWrapperDefaultConfigsTestsKey"

@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
class PropertyWrapperDefaultConfigsTests: XCTestCase {
  struct Recipe: Decodable, Encodable {
    var recipeName: String
    var ingredients: [String]
    var cookTime: Int
  }

  static let defaultRecipe = Recipe(
    recipeName: "muffin", ingredients: ["flour", "sugar"], cookTime: 45
  )

  // MARK: - Test Remote Config default values with property wrapper

  struct DefaultsValuesTester {
    @RemoteConfigProperty(
      key: ConfigKeyForThisTestOnly,
      fallback: Recipe(recipeName: "test", ingredients: [], cookTime: 0)
    )
    var dictValue: Recipe
  }

  override class func setUp() {
    if FirebaseApp.app() == nil {
      let options = FirebaseOptions(googleAppID: "1:123:ios:123abc",
                                    gcmSenderID: "correct_gcm_sender_id")
      options.apiKey = "A23456789012345678901234567890123456789"
      options.projectID = "Fake_Project"
      FirebaseApp.configure(options: options)
    }
  }

  func testDefaultValues() async throws {
    try? RemoteConfig.remoteConfig().setDefaults(
      from: [ConfigKeyForThisTestOnly: PropertyWrapperDefaultConfigsTests.defaultRecipe]
    )

    let tester = await DefaultsValuesTester()
    let dictValue = await tester.dictValue

    XCTAssertEqual(dictValue.recipeName, "muffin")
    XCTAssertEqual(dictValue.cookTime, 45)
    XCTAssertEqual(dictValue.ingredients, ["flour", "sugar"])
  }
}
