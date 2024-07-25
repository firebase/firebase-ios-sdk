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

public extension VectorValue {
  convenience init(_ data: [Double]) {
    let array = data.map { float in
      NSNumber(value: float)
    }

    self.init(__nsNumbers: array)
  }

  /// Returns a raw number array representation of the vector.
  /// - Returns: An array of Double values representing the vector.
  var data: [Double] {
    return __toNSArray().map { Double(truncating: $0) }
  }
}
