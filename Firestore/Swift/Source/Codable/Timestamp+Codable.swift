/*
 * Copyright 2018 Google
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

import FirebaseFirestore

/**
 * A protocol describing the encodable properties of a DocumentSnapshot.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the Timestamp class
 * was extended directly to conform to Codable, the methods implementing the protocol would be need
 * to be marked required but that can't be done in an extension. Declaring the extension on the
 * protocol sidesteps this issue.
 */
public protocol CodableTimestamp: Codable {
  init(date: Date)
  func dateValue() -> Date
}

extension CodableTimestamp {
  var date: Date { return dateValue() }
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(date: try container.decode(Date.self))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(dateValue())
  }
}

extension Timestamp: CodableTimestamp {}
