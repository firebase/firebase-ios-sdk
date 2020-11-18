// Copyright 2020 Google LLC
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

private protocol OptionalProtocol {
  var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
  public var isNil: Bool { self == nil }
}

/// Property initializer for user defaults. Value is always read from or written to a named user defaults store.
@propertyWrapper struct UserDefaultsBacked<Value> {
  let key: String
  let defaultValue: Value
  let storage: UserDefaults

  var wrappedValue: Value {
    get {
      let value = storage.value(forKey: key) as? Value
      return value ?? defaultValue
    }
    set {
      if let optional = newValue as? OptionalProtocol, optional.isNil {
        storage.removeObject(forKey: key)
      } else {
        storage.setValue(newValue, forKey: key)
      }
    }
  }
}

/// Initialize and set default value for user default backed properties that can be optional (model path).
extension UserDefaultsBacked where Value: ExpressibleByNilLiteral {
  init(key: String, storage: UserDefaults) {
    self.init(key: key, defaultValue: nil, storage: storage)
  }
}

/// Initialize and set default value for user default backed properties that are strings (model download url, model hash).
extension UserDefaultsBacked where Value: ExpressibleByStringLiteral {
  init(key: String, storage: UserDefaults) {
    self.init(key: key, defaultValue: "", storage: storage)
  }
}

/// Initialize and set default value for user default backed properties that are int (model size).
extension UserDefaultsBacked where Value: ExpressibleByIntegerLiteral {
  init(key: String, storage: UserDefaults) {
    self.init(key: key, defaultValue: 0, storage: storage)
  }
}
