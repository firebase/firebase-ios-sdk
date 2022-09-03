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

import Foundation

/// String constants used for testing.
enum Constants {
  static let key1 = "Key1"
  static let jedi = "Jedi"
  static let sith = "Sith_Lord"
  static let value1 = "Value1"
  static let obiwan = "Obi-Wan"
  static let yoda = "Yoda"
  static let darthSidious = "Darth Sidious"

  static let stringKey = "myString"
  static let stringValue = "string contents"
  static let intKey = "myInt"
  static let intValue: Int = 123
  static let floatKey = "myFloat"
  static let floatValue: Float = 42.75
  static let doubleValue: Double = 42.75
  static let decimalKey = "myDecimal"
  static let decimalValue: Decimal = 375.785
  static let trueKey = "myTrue"
  static let falseKey = "myFalse"
  static let dataKey = "myData"
  static let dataValue: Data = "data".data(using: .utf8)!
  static let arrayKey = "fruits"
  static let arrayValue: [String] = ["mango", "pineapple", "papaya"]
  static let dictKey = "platforms"
  static let dictValue: [String: String] = [
    "iOS": "14.0", "macOS": "14.0", "tvOS": "10.0", "watchOS": "6.0",
  ]
  static let jsonKey = "Recipe"
  static let jsonValue: [String: AnyHashable] = [
    "recipeName": "PB&J",
    "ingredients": ["bread", "peanut butter", "jelly"],
    "cookTime": 7,
  ]
  static let nonJsonKey = "notJSON"
  static let nonJsonValue = "notJSON"
}
