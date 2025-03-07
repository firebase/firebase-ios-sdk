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

public struct Ordering {
  let expr: Expr
  let direction: Direction
}

public struct Direction: Sendable, Equatable, Hashable {
  enum Kind: String {
    case ascending
    case descending
  }

  public static var ascending: Direction {
    return self.init(kind: .ascending)
  }

  public static var descending: Direction {
    return self.init(kind: .descending)
  }

  public let rawValue: String

  init(kind: Kind) {
    rawValue = kind.rawValue
  }

  public init(rawValue: String) {
    if Kind(rawValue: rawValue) == nil {
      // impl
    }
    self.rawValue = rawValue
  }
}
