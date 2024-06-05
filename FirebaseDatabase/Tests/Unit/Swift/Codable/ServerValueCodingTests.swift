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

private func assertThat(_ dictionary: [String: Any],
                        file: StaticString = #file,
                        line: UInt = #line) -> DictionarySubject {
  return DictionarySubject(dictionary, file: file, line: line)
}

func assertThat<X: Equatable & Codable>(_ model: X, file: StaticString = #file,
                                        line: UInt = #line) -> CodableSubject<X> {
  return CodableSubject(model, file: file, line: line)
}

func assertThat<X: Equatable & Encodable>(_ model: X, file: StaticString = #file,
                                          line: UInt = #line) -> EncodableSubject<X> {
  return EncodableSubject(model, file: file, line: line)
}

class EncodableSubject<X: Equatable & Encodable> {
  var subject: X
  var file: StaticString
  var line: UInt

  init(_ subject: X, file: StaticString, line: UInt) {
    self.subject = subject
    self.file = file
    self.line = line
  }

  @discardableResult
  func encodes(to expected: [String: Any],
               using encoder: Database.Encoder = .init()) -> DictionarySubject {
    let encoded = assertEncodes(to: expected, using: encoder)
    return DictionarySubject(encoded, file: file, line: line)
  }

  func failsToEncode() {
    do {
      let encoder = Database.Encoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      _ = try encoder.encode(subject)
    } catch {
      return
    }
    XCTFail("Failed to throw")
  }

  func failsEncodingAtTopLevel() {
    do {
      let encoder = Database.Encoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      _ = try encoder.encode(subject)
      XCTFail("Failed to throw", file: file, line: line)
    } catch EncodingError.invalidValue(_, _) {
      return
    } catch {
      XCTFail("Unrecognized error: \(error)", file: file, line: line)
    }
  }

  private func assertEncodes(to expected: [String: Any],
                             using encoder: Database.Encoder = .init()) -> [String: Any] {
    do {
      let enc = try encoder.encode(subject)
      XCTAssertEqual(enc as? NSDictionary, expected as NSDictionary, file: file, line: line)
      return (enc as! NSDictionary) as! [String: Any]
    } catch {
      XCTFail("Failed to encode \(X.self): error: \(error)")
      return ["": -1]
    }
  }
}

class CodableSubject<X: Equatable & Codable>: EncodableSubject<X> {
  func roundTrips(to expected: [String: Any],
                  using encoder: Database.Encoder = .init(),
                  decoder: Database.Decoder = .init()) {
    let reverseSubject = encodes(to: expected, using: encoder)
    reverseSubject.decodes(to: subject, using: decoder)
  }
}

class DictionarySubject {
  var subject: [String: Any]
  var file: StaticString
  var line: UInt

  init(_ subject: [String: Any], file: StaticString, line: UInt) {
    self.subject = subject
    self.file = file
    self.line = line
  }

  func decodes<X: Equatable & Codable>(to expected: X,
                                       using decoder: Database.Decoder = .init()) -> Void {
    do {
      let decoded = try decoder.decode(X.self, from: subject)
      XCTAssertEqual(decoded, expected)
    } catch {
      XCTFail("Failed to decode \(X.self): \(error)", file: file, line: line)
    }
  }
}
