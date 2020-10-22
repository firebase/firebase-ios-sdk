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

#if compiler(>=5.1)
  /// A property wrapper that exposes a `Numeric` value that either represents an actual value
  /// or an increment as an `Optional`. In case the projected value is used to set an increment of `x`
  /// then the wrapped value is exposed as nil, but will be encoded as `ServerValue.increment(x)`
  /// In case the wrapper contains an actual value, then this will be exposed as the .some case
  /// of the wrapped optional
  ///
  /// Example:
  /// ```
  /// struct CustomModel {
  ///   @ServerIncrement var count: Int?
  /// }
  /// ```
  ///
  /// Then writing:
  /// ```
  /// var model = CustomModel()
  /// model.$count.increment = 3
  /// ```
  /// will tell server to increment `count` by 3
  ///
  ///
  /// The enum can also be used directly instead of as a property wrapper:
  ///
  /// Example:
  /// ```
  /// struct CustomModel {
  ///   var count: ServerIncrement<Int>
  /// }
  /// ```
  ///
  /// Then writing:
  /// ```
  /// var model = CustomModel(count: .increment(3))
  /// ```
  /// will tell server to increment `count` by 3
  ///
  /// Writing:
  /// ```
  /// var model = CustomModel(count: .value(7))
  /// ```
  /// or using the ExpressibleByIntegerLiteral convenience:
  /// ```
  /// var model = CustomModel(count: 7)
  /// ```
  ///
  /// will tell server to set `count` to 7.

  @propertyWrapper
  public enum ServerIncrement<Value>: Equatable, Hashable
    where Value: AdditiveArithmetic, Value: Codable, Value: Hashable {
    case value(Value)
    case increment(Value)

    public init(wrappedValue value: Value?) {
      if let v = value {
        self = .value(v)
      } else {
        self = .increment(.zero)
      }
    }

    public var projectedValue: ServerIncrement<Value> {
      get {
        return self
      }
      mutating set {
        self = newValue
      }
    }

    public var increment: Value? {
      get {
        switch self {
        case let .increment(v):
          return v
        case .value:
          return nil
        }
      }

      mutating set {
        if let v = newValue {
          self = .increment(v)
        } else {
          self = .increment(.zero)
        }
      }
    }

    public var wrappedValue: Value? {
      get {
        switch self {
        case let .value(v):
          return v
        case .increment:
          return nil
        }
      }
      set {
        if let v = newValue {
          self = .value(v)
        } else {
          self = .increment(.zero)
        }
      }
    }
  }
#else
  public enum ServerIncrement<Value>: Equatable, Hashable
    where Value: Numeric, Value: Codable, Value: Hashable {
    case value(Value)
    case increment(Value)
  }
#endif // compiler(>=5.1)

// MARK: Codable

extension ServerIncrement: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self = .value(try container.decode(Value.self))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case let .value(v):
      try container.encode(v)
    case let .increment(v):
      // NOTE: I am not certain that it is acceptable to
      // encode this structure 'manually', but as we
      // do not have an NSNumber, but a Numeric, it
      // basically needs to be encoded here.
      // It would be better to separately encode v, and
      // in case the encoded version is an NSNumber, then
      // encode the ServerValue.increment()
      // But NSNumber isn't directly Encodable, so that's an issue.
      // Perhaps we should add special handling of ServerIncrement
      // inside the encoder...

      //        if let number = try? JSONEncoder().encode(v) as? NSNumber,
      //           let incr = ServerValue.increment(number) as? [String: [String: NSNumber]] {
      //            try container.encode(incr)
      //        }
      try container.encode([".sv": ["increment": v]])
    }
  }
}

// MARK: ExpressibleByIntegerLiteral

extension ServerIncrement: ExpressibleByIntegerLiteral where Value: ExpressibleByIntegerLiteral {
  public typealias IntegerLiteralType = Value.IntegerLiteralType

  public init(integerLiteral value: IntegerLiteralType) {
    self = .value(Value(integerLiteral: value))
  }
}

// MARK: ExpressibleByFloatLiteral

extension ServerIncrement: ExpressibleByFloatLiteral where Value: ExpressibleByFloatLiteral {
  public typealias FloatLiteralType = Value.FloatLiteralType

  public init(floatLiteral value: FloatLiteralType) {
    self = .value(Value(floatLiteral: value))
  }
}
