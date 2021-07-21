/*
 * Copyright 2020 Google LLC
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
    let model = Model(timestamp: Date(timeIntervalSince1970: 123_456_789.123))
    let dict = ["timestamp": 123_456_789_123]
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
    value = try container.decode(Decimal.self)
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
