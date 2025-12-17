// Copyright 2025 Google LLC
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

// ////////////////////////////////// //
// Auxiliary type (`Field`) Approach  //
// ////////////////////////////////// //
enum Approach_1 {
  struct Field<T: Codable> {
    let value: T?
    let description: String?
  }

  @propertyWrapper struct Guide<T: Codable> {
    var wrappedValue: Field<T> {
      didSet {}
    }

    init(wrappedValue defaultValue: Field<T>, description: String? = nil) {
      wrappedValue = defaultValue
    }

    init(description: String? = nil) {
      wrappedValue = Field(value: nil, description: description)
    }
  }

  struct Example_1 {
    // Notes:
    // - The property wrapper effectively holds the default value of this, so
    //   ``User`` initializers don't require initializing it.
    // - By using a property wrapper, the property has to be `var`.
    @Guide(description: "The age, between 30 and 40.") var age: Field<Int>

    // Note:
    // - This is allowed.
    init() {}
  }
}

// //////////////////////////////////// ////////////////////////////////// //

// ////////////////////////////// //
// Approach 2: No Auxiliary type  //
// ////////////////////////////// //

enum Approach_2 {
  @propertyWrapper public struct Guide<T: Codable> {
    private struct Field {
      var storedValue: T?
      let description: String?
    }

    private var field: Field

    public var wrappedValue: T {
      get {
        guard let storedValue = field.storedValue else {
          fatalError("Property accessed before being set with non-nil value.")
        }
        return storedValue
      }
      set {
        field.storedValue = newValue
      }
    }

    public init(wrappedValue defaultValue: T, description: String? = nil) {
      field = Field(storedValue: defaultValue, description: description)
    }

    public init(description: String? = nil) {
      field = Field(storedValue: nil, description: description)
    }
  }

  struct Example_2 {
    // Note:
    // - 💥 Implicitly defaults to nil! So accessing without setting age
    //   post-init will crash.
    @Guide(description: "The age, between 30 and 40.") var age: Int

    // Note:
    // - This is allowed.
    init() {}
  }
}
