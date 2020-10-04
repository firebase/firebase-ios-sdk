/*
 * Copyright 2020 Google
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

import FirebaseDatabase
import FirebaseDatabaseSwift
import Foundation
import XCTest

class ServerTimestampTests: XCTestCase {
  func testDateRoundTrip() throws {
    struct Model: Codable, Equatable {
      @ServerTimestamp var timestamp: Date?
    }
    let model = Model(timestamp: Date(timeIntervalSince1970: 123456789.123))
    let dict = ["timestamp": 123456789123]
    assertThat(model).roundTrips(to: dict)
  }

  func testTimestampEncoding() throws {
    struct Model: Codable, Equatable {
      @ServerTimestamp var timestamp: Date?
    }
    let model = Model()
    let dict = ["timestamp": [".sv": "timestamp"]]
    // We can't round trip since we only decode values as Ints
    // (for Date conversion) and never as the magic value.
    assertThat(model).encodes(to: dict)
  }
}

private struct CurrencyAmount: Codable, Equatable, Hashable, AdditiveArithmetic {
  static var zero: Self = CurrencyAmount(value: 0)

  static func + (lhs: Self, rhs: Self) -> Self {
    return Self(value: lhs.value + rhs.value)
  }

  static func += (lhs: inout Self, rhs: Self) {
    lhs.value += rhs.value
  }

  static func - (lhs: Self, rhs: Self) -> Self {
    return CurrencyAmount(value: lhs.value - rhs.value)
  }

  static func -= (lhs: inout Self, rhs: Self) {
    lhs.value -= rhs.value
  }

  var value: Decimal
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }
  init(value: Decimal) {
    self.value = value
  }
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.value = try container.decode(Decimal.self)
  }
}

extension CurrencyAmount: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self.value = Decimal(value)
  }
}

extension CurrencyAmount: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self.value = Decimal(value)
  }
}

class ServerIncrementTests: XCTestCase {
  func testIntRoundTrip() throws {
    struct Model: Codable, Equatable {
      @ServerIncrement var intValue: Int?
    }
    let model = Model(intValue: 10)
    let dict = ["intValue": 10]
    assertThat(model).roundTrips(to: dict)
  }

  func testIntIncrementEncoding() throws {
    struct Model: Codable, Equatable {
      @ServerIncrement var intValue: Int?
    }
    var model = Model()
    model.$intValue.increment = 5
    let dict = ["intValue": [".sv": ["increment": 5]]]
    assertThat(model).encodes(to: dict)
  }

  func testDoubleRoundTrip() throws {
    struct Model: Codable, Equatable {
      @ServerIncrement var doubleValue: Double?
    }
    let model = Model(doubleValue: 123456789.123)
    let dict = ["doubleValue": 123456789.123]
    assertThat(model).roundTrips(to: dict)
  }

  func testDoubleIncrementEncoding() throws {
    struct Model: Codable, Equatable {
      @ServerIncrement var doubleValue: Double?
    }
    var model = Model()
    model.$doubleValue.increment = 1.234
    let dict = ["doubleValue": [".sv": ["increment": 1.234]]]
    assertThat(model).encodes(to: dict)
  }

  func testCustomValueRoundTrip() throws {
    struct Model: Codable, Equatable {
      @ServerIncrement var currencyAmount: CurrencyAmount?
    }
    let model = Model(currencyAmount: 10)
    let dict = ["currencyAmount": 10]
    assertThat(model).roundTrips(to: dict)
  }

  func testCustomValueIncrementEncoding() throws {
    struct Model: Codable, Equatable {
      @ServerIncrement var currencyAmount: CurrencyAmount?
    }
    var model = Model()
    model.$currencyAmount.increment = 9.99
    let dict = ["currencyAmount": [".sv": ["increment": 9.99]]]
    assertThat(model).encodes(to: dict)
  }
}

// Same tests as above, but using other API
class ServerIncrementNoWrapTests: XCTestCase {
  func testIntRoundTrip() throws {
    struct Model: Codable, Equatable {
      var intValue: ServerIncrement<Int>
    }
    let model = Model(intValue: 10)
    let dict = ["intValue": 10]
    assertThat(model).roundTrips(to: dict)
  }

  func testIntIncrementEncoding() throws {
    struct Model: Codable, Equatable {
      var intValue: ServerIncrement<Int>
    }
    let model = Model(intValue: .increment(5))
    let dict = ["intValue": [".sv": ["increment": 5]]]
    assertThat(model).encodes(to: dict)
  }

  func testDoubleRoundTrip() throws {
    struct Model: Codable, Equatable {
      var doubleValue: ServerIncrement<Double>
    }
    let model = Model(doubleValue: 123456789.123)
    let dict = ["doubleValue": 123456789.123]
    assertThat(model).roundTrips(to: dict)
  }

  func testDoubleIncrementEncoding() throws {
    struct Model: Codable, Equatable {
      var doubleValue: ServerIncrement<Double>
    }
    let model = Model(doubleValue: .increment(1.234))
    let dict = ["doubleValue": [".sv": ["increment": 1.234]]]
    assertThat(model).encodes(to: dict)
  }

  func testCustomValueRoundTrip() throws {
    struct Model: Codable, Equatable {
      var currencyAmount: ServerIncrement<CurrencyAmount>
    }
    let model = Model(currencyAmount: 10)
    let dict = ["currencyAmount": 10]
    assertThat(model).roundTrips(to: dict)
  }

  // Demonstration that this version of the API can also
  // model actual optionality
  func testCustomValueOptionalNilRoundTrip() throws {
    struct Model: Codable, Equatable {
      var currencyAmount: ServerIncrement<CurrencyAmount>?
    }
    let model = Model()
    assertThat(model).roundTrips(to: [:])
  }

  // Demonstration that this version of the API can also
  // model actual optionality
  func testCustomValueOptionalValueRoundTrip() throws {
    struct Model: Codable, Equatable {
      var currencyAmount: ServerIncrement<CurrencyAmount>?
    }
    let model = Model(currencyAmount: 10)
    let dict = ["currencyAmount": 10]
    assertThat(model).roundTrips(to: dict)
  }

  func testCustomValueIncrementEncoding() throws {
    struct Model: Codable, Equatable {
      var currencyAmount: ServerIncrement<CurrencyAmount>
    }
    let model = Model(currencyAmount: .increment(9.99))
    let dict = ["currencyAmount": [".sv": ["increment": 9.99]]]
    assertThat(model).encodes(to: dict)
  }
}
