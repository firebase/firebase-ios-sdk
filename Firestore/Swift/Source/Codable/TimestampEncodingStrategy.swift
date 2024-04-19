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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

import FirebaseSharedSwift
import Foundation

public extension FirebaseDataEncoder.DateEncodingStrategy {
  /// Encode the `Date` as a Firestore `Timestamp`.
  static var timestamp: FirebaseDataEncoder.DateEncodingStrategy {
    return .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(Timestamp(date: date))
    }
  }
}
