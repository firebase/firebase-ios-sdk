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

@_exported import class FirebaseCore.Timestamp

import FirebaseSharedSwift

public extension FirebaseDataDecoder.DateDecodingStrategy {
  /// Decode the `Date` from a Firestore `Timestamp`
  static var timestamp: FirebaseDataDecoder.DateDecodingStrategy {
    return .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(Timestamp.self)
      return value.dateValue()
    }
  }
}
