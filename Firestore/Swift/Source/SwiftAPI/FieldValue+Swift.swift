/*
 * Copyright 2024 Google LLC
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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

public extension FieldValue {
  /// Creates a new `VectorValue` constructed with a copy of the given array of Doubles.
  /// - Parameter array: An array of Doubles.
  /// - Returns: A new `VectorValue` constructed with a copy of the given array of Doubles.
  static func vector(_ array: [Double]) -> VectorValue {
    let nsNumbers = array.map { double in
      NSNumber(value: double)
    }
    return FieldValue.__vector(with: nsNumbers)
  }

  /// Creates a new `VectorValue` constructed with a copy of the given array of Floats.
  /// - Parameter array: An array of Floats.
  /// - Returns: A new `VectorValue` constructed with a copy of the given array of Floats.
  static func vector(_ array: [Float]) -> VectorValue {
    let nsNumbers = array.map { float in
      NSNumber(value: float)
    }
    return FieldValue.__vector(with: nsNumbers)
  }
}
